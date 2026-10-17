import XCTest
import Synchronization
@testable import Fomio

/// Scripted stand-in for the catalog endpoints: per-locale queued responses, recorded ETags and call counts.
final class ScriptedTransport: LocalizationTransport {
    struct State { var catalogs: [String: [Result<TransportResponse, TransportError>]] = [:]; var index: [Result<TransportResponse, TransportError>] = []; var calls: [String: Int] = [:]; var etags: [String: [String?]] = [:]; var indexCalls = 0 }
    let state = Mutex(State())
    let delay: Duration
    init(delay: Duration = .zero) { self.delay = delay }
    func enqueue(_ locale: String, _ result: Result<TransportResponse, TransportError>) { state.withLock { $0.catalogs[locale, default: []].append(result) } }
    func enqueueIndex(_ result: Result<TransportResponse, TransportError>) { state.withLock { $0.index.append(result) } }
    func calls(_ locale: String) -> Int { state.withLock { $0.calls[locale] ?? 0 } }
    func etags(_ locale: String) -> [String?] { state.withLock { $0.etags[locale] ?? [] } }
    func index(etag: String?) async throws -> TransportResponse {
        let next = state.withLock { s -> Result<TransportResponse, TransportError> in s.indexCalls += 1; return s.index.isEmpty ? .failure(.offline) : s.index.removeFirst() }
        return try next.get()
    }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse {
        let next = state.withLock { s -> Result<TransportResponse, TransportError> in
            s.calls[locale, default: 0] += 1; s.etags[locale, default: []].append(etag)
            return s.catalogs[locale]?.isEmpty == false ? s.catalogs[locale]!.removeFirst() : .failure(.offline)
        }
        if delay > .zero { try await Task.sleep(for: delay) }
        return try next.get()
    }
}

final class TestClock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 2_000_000_000) }

@MainActor final class LocalizationTests: XCTestCase {
    var root: URL!
    var defaults: UserDefaults!
    var english: LocalizationCatalog { Localizer.shared.english }
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("l10n-\(UUID().uuidString)")
        defaults = UserDefaults(suiteName: "l10n-\(UUID().uuidString)")
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: root) }

    // MARK: Fixtures

    static func data(_ name: String) throws -> Data {
        // Catalogs assembled by the backend plugin (Localization/fixtures); English is the bundled reference.
        let url = name == "en" ? Bundle.main.url(forResource: "fomio-catalog-en", withExtension: "json") : Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "fixtures")
        return try Data(contentsOf: XCTUnwrap(url, "missing catalog \(name)"))
    }
    static func payload(_ name: String) throws -> CatalogPayload { try CatalogValidator.decode(data(name)) }
    static func encode(_ payload: CatalogPayload) throws -> Data { try JSONEncoder().encode(payload) }
    /// Arabic with one message changed and a new revision, as a site-text override change would produce.
    static func arabic(revision: String, home: String? = nil) throws -> Data {
        var value = try payload("ar"); value.revision = revision
        if let home { value.messages["tab.home"] = .text(home) }
        return try encode(value)
    }
    /// A one-category (`other` only) language built from English, for eviction tests.
    static func japaneseLike() throws -> Data {
        var value = try payload("en"); value.locale = "ja"; value.revision = "ja-1"; value.pluralCategories = ["other"]
        value.messages = value.messages.mapValues { if case let .plural(forms) = $0 { return .plural(["other": forms["other"]!]) }; return $0 }
        return try encode(value)
    }
    func controller(_ transport: some LocalizationTransport, site: String = "https://forum.example", clock: TestClock = TestClock()) -> (LocalizationController, Localizer) {
        let localizer = Localizer(english: english)
        let store = LocalizationStore(root: root, site: site)
        return (LocalizationController(localizer: localizer, store: store, transport: transport, defaults: defaults, now: { clock.now }), localizer)
    }
    /// Loads a site index into the controller, as Me › Language does before offering languages.
    func offer(_ controller: LocalizationController, _ transport: ScriptedTransport, _ locales: [(String, Bool)] = [("en", true), ("ar", true)], defaultLocale: String = "en") async throws {
        transport.enqueueIndex(.success(.payload(try Self.index(locales, defaultLocale: defaultLocale), etag: "\"i\(transport.state.withLock { $0.indexCalls })\"")))
        await controller.refreshIndex(force: true)
    }
    func seed(_ locale: String, _ data: Data, site: String = "https://forum.example", fetchedAt: Date, etag: String? = "\"e1\"") throws {
        let catalog = try CatalogValidator.validate(data, requested: locale, reference: english)
        try LocalizationStore(root: root, site: site).save(.init(locale: locale, revision: catalog.revision, etag: etag, fetchedAt: fetchedAt, lastUsedAt: fetchedAt, payload: data))
    }
    static func index(_ locales: [(String, Bool)], defaultLocale: String = "en") throws -> Data {
        // Like the server, each entry carries Discourse's plural categories for its locale.
        try JSONSerialization.data(withJSONObject: ["schema": LocalizationCatalog.schema, "default_locale": defaultLocale, "locales": locales.map {
            ["locale": $0.0, "name": $0.0, "native_name": $0.0, "direction": ["ar", "he"].contains($0.0) ? "rtl" : "ltr", "complete": $0.1,
             "plural_categories": (PluralRules.categories(for: $0.0) ?? [.one, .other]).map(\.rawValue)]
        }])
    }

    // MARK: Catalog validation

    func testBundledEnglishAndMaintainedArabicAreCompleteAndCompatible() throws {
        XCTAssertGreaterThan(english.messages.count, 400)
        let arabic = try CatalogValidator.validate(Self.data("ar"), requested: "ar", reference: english)
        XCTAssertEqual(arabic.direction, .rtl)
        XCTAssertEqual(Set(arabic.messages.keys), Set(english.messages.keys))
        // Every Arabic plural message carries all six CLDR forms.
        for case let (key, .plural(forms)) in arabic.messages { XCTAssertEqual(forms.count, 6, key) }
    }

    func testValidatorRejectsIncompatibleCatalogs() throws {
        let base = try Self.payload("ar")
        func rejects(_ change: (inout CatalogPayload) -> Void, requested: String = "ar", file: StaticString = #filePath, line: UInt = #line) {
            var value = base; change(&value)
            XCTAssertThrowsError(try CatalogValidator.validate(value, requested: requested, reference: english), file: file, line: line)
        }
        rejects { $0.messages["tab.home"] = nil }                                   // incomplete
        rejects { $0.complete = false }
        rejects { $0.schema = 1 }
        rejects { $0.direction = "up" }
        rejects { $0.pluralCategories = ["one", "other"] }
        rejects({ _ in }, requested: "fr")                                          // resolved to another language
        rejects { $0.messages["communities.row"] = .text("{name}") }               // missing placeholder
        rejects { $0.messages["tab.home"] = .text("الرئيسية {name}") }              // unknown placeholder
        rejects { $0.messages["auth.signed_in"] = .text("مرحبًا %{name}") }        // Discourse interpolation
        rejects { $0.messages["tab.home"] = .text("<b>الرئيسية</b>") }             // markup
        rejects { $0.messages["tab.home"] = .text("js.hubs.all") }                 // raw key (live override bug)
        rejects { $0.messages["tab.home"] = .text("   ") }                         // blank label
        rejects { $0.messages["auth.signed_in"] = .text("{name") }                 // unbalanced brace
        rejects { $0.messages["tab.home"] = .plural(["other": "x"]) }              // wrong kind
        rejects { $0.messages["discussion.replies"] = .plural(["one": "رد", "two": "ردان"]) }    // no `other`
        rejects {                                                                   // `other` must show the count
            $0.messages["discussion.replies"] = .plural(["zero": "a", "one": "b", "two": "c", "few": "{count} d", "many": "{count} e", "other": "ردود"])
        }
        var oversize = base; oversize.messages["tab.home"] = .text(String(repeating: "ب", count: 5_000))
        XCTAssertThrowsError(try CatalogValidator.validate(oversize, requested: "ar", reference: english))
        XCTAssertThrowsError(try CatalogValidator.decode(Data(repeating: 32, count: CatalogValidator.maximumPayloadBytes + 1)))
        XCTAssertThrowsError(try CatalogValidator.decode(Data("{\"schema\":1".utf8)))
    }

    func testValidatorAcceptsReorderedPlaceholdersAndUnknownExtraKeys() throws {
        var value = try Self.payload("ar")
        value.messages["community.name_with_parent"] = .text("{parent} ← {name}")
        value.messages["future.key"] = .text("مفتاح من إصدار أحدث")
        let catalog = try CatalogValidator.validate(value, requested: "ar", reference: english)
        XCTAssertNil(catalog.messages["future.key"])
    }

    func testArabicPluralRulesAndFormattedCounts() throws {
        let expected: [(Int, PluralCategory)] = [(0, .zero), (1, .one), (2, .two), (3, .few), (10, .few), (11, .many), (99, .many), (100, .other), (101, .other), (102, .other), (103, .few), (111, .many)]
        for (n, category) in expected { XCTAssertEqual(PluralRules.category(n, locale: "ar"), category, "\(n)") }
        XCTAssertEqual(PluralRules.category(1, locale: "en_GB"), .one)
        XCTAssertNil(PluralRules.categories(for: "tlh"), "a locale without rules is never activated")
        let localizer = Localizer(english: english)
        let arabic = try CatalogValidator.validate(Self.data("ar"), requested: "ar", reference: english)
        localizer.activate(arabic)
        // Discourse's own Arabic for the mapped reply count (js.review.replies).
        guard case let .plural(forms) = arabic.messages["discussion.replies"] else { return XCTFail("plural") }
        for (n, category) in [(0, PluralCategory.zero), (1, .one), (2, .two), (4, .few), (14, .many), (100, .other)] {
            let number = n.formatted(.number.locale(arabic.formattingLocale))
            let template = forms[category]!
            XCTAssertEqual(localizer.string("discussion.replies", count: n), Localizer.anchor(template, in: .rtl) + template.replacingOccurrences(of: "{count}", with: number), "\(n)")
        }
        XCTAssertEqual(Localizer(english: english).string("discussion.replies", count: 1200), "1,200 replies")
    }

    /// Discourse's CLDR rules (config/locales/plurals.rb), evaluated by Discourse itself for every client locale,
    /// are the reference: categories and the selected category for each count must match exactly.
    func testPluralRulesMatchDiscourseForEveryLocale() throws {
        let url = LocalizationCoverageTests.repository.appendingPathComponent("Localization/discourse-plural-truth.json")
        let table = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let locales = try XCTUnwrap(table["locales"] as? [String: [String: Any]])
        XCTAssertEqual(locales.count, 49)
        var checked = 0
        for (locale, entry) in locales {
            let keys = try XCTUnwrap(entry["keys"] as? [String], locale)
            XCTAssertEqual(PluralRules.categories(for: locale)?.map(\.rawValue), keys, locale)
            for (count, category) in try XCTUnwrap(entry["categories"] as? [String: String]) {
                XCTAssertEqual(PluralRules.category(Int(count)!, locale: locale).rawValue, category, "\(locale) \(count)"); checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 10_000)
    }

    /// Counts 0, 1, 2, 3, 11 and 100 in five languages: translated plurals follow the language's rules (a form
    /// the translation omits shows `other`, as in Discourse); English fallback plurals follow English rules.
    func testCountMatrixForTranslatedAndFallbackPlurals() throws {
        let counts = [0, 1, 2, 3, 11, 100]
        let expected: [String: [PluralCategory]] = [
            "ar": [.zero, .one, .two, .few, .many, .other], "he": [.other, .one, .two, .other, .other, .many],
            "ru": [.many, .one, .few, .few, .many, .many], "pt_BR": [.one, .one, .other, .other, .other, .other],
            "ja": [.other, .other, .other, .other, .other, .other],
        ]
        for (locale, categories) in expected {
            let catalog = try CatalogValidator.validate(Self.data(locale), requested: locale, reference: english)
            let localizer = Localizer(english: english); localizer.activate(catalog)
            XCTAssertEqual(counts.map { PluralRules.category($0, locale: locale) }, categories, locale)
            guard case let .plural(forms) = catalog.messages["discussion.replies"] else { return XCTFail(locale) }
            for (n, category) in zip(counts, categories) {
                let template = forms[category] ?? forms[.other]!
                let expected = Localizer.anchor(template, in: catalog.direction) + template.replacingOccurrences(of: "{count}", with: n.formatted(.number.locale(catalog.formattingLocale)))
                XCTAssertEqual(localizer.string("discussion.replies", count: n), expected, "\(locale) \(n)")
            }
            // post.like_count has no translation in these catalogs except Arabic's overlay: English, English rules.
            if catalog.fallbackKeys.contains("post.like_count") {
                for n in counts {
                    let plain = localizer.string("post.like_count", count: n).replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
                    XCTAssertEqual(plain, "Like \(n.formatted(.number.locale(Locale(identifier: "en"))))", "\(locale) \(n)")
                }
                XCTAssertEqual(localizer.string("topic.active.spoken.days", count: 21).contains("days ago"), true, "\(locale): English 'other' for 21, not a Slavic 'one'")
            }
        }
    }

    func testFallbackMessagesKeepEnglishDirectionInsideRightToLeftCatalogs() throws {
        let hebrew = try CatalogValidator.validate(Self.data("he"), requested: "he", reference: english)
        XCTAssertEqual(hebrew.direction, .rtl)
        XCTAssertTrue(hebrew.fallbackKeys.contains("tab.communities"))
        XCTAssertFalse(hebrew.fallbackKeys.contains("tab.home"), "mapped: Discourse's Hebrew")
        let localizer = Localizer(english: english); localizer.activate(hebrew)
        XCTAssertEqual(localizer.string("tab.communities"), "\u{2066}Communities\u{2069}", "an English run isolated left to right")
        XCTAssertEqual(localizer.string("tab.home"), "בית")
        // A Hebrew argument inside an English fallback is isolated in turn; no right-to-left mark is added.
        let message = localizer.string("access.denied.community_message", [("community", "קהילה")])
        XCTAssertTrue(message.hasPrefix("\u{2066}\u{2068}קהילה\u{2069}"), message)
        let segments = localizer.segments("tab.communities")
        XCTAssertEqual(segments.first?.text, "\u{2066}"); XCTAssertEqual(segments.last?.text, "\u{2069}")
        // Left-to-right catalogs never wrap fallback text.
        let russian = Localizer(english: english); russian.activate(try CatalogValidator.validate(Self.data("ru"), requested: "ru", reference: english))
        XCTAssertEqual(russian.string("tab.communities"), "Communities")
    }

    /// A fragment inserted into a sentence takes the sentence's language: Hebrew has Discourse's compact ages but
    /// no overlay for "active {age} ago", so the composed sentence is entirely English; shown alone, the age is Hebrew.
    func testComposedFragmentsFollowTheirSentenceLanguage() throws {
        let hebrew = Localizer(english: english)
        hebrew.activate(try CatalogValidator.validate(Self.data("he"), requested: "he", reference: english))
        XCTAssertTrue(hebrew.isFallback("topic.active.ago")); XCTAssertFalse(hebrew.isFallback("time.compact.minutes"))
        let standalone = hebrew.string("time.compact.minutes", count: 2)
        XCTAssertTrue(standalone.contains("דקות"), standalone)
        let fragment = hebrew.string("time.compact.minutes", count: 2, within: "topic.active.ago")
        XCTAssertEqual(fragment, "2m", "English fragment, not isolated on its own")
        let sentence = hebrew.string("topic.active.ago", [("age", fragment)])
        XCTAssertEqual(sentence, "\u{2066}Active 2m ago\u{2069}")
        // Arabic translates both: the composed sentence stays Arabic.
        let arabic = Localizer(english: english)
        arabic.activate(try CatalogValidator.validate(Self.data("ar"), requested: "ar", reference: english))
        let arabicAge = arabic.string("time.compact.minutes", count: 2, within: "topic.active.ago")
        XCTAssertEqual(arabicAge, arabic.string("time.compact.minutes", count: 2))
        XCTAssertFalse(arabic.string("topic.active.ago", [("age", arabicAge)]).contains("Active"))
    }

    func testValidatorChecksAssembledCatalogsAndFallbackAgainstEnglishRules() throws {
        for locale in ["ar", "he", "ru", "pt_BR", "ja"] {
            let payload = try Self.payload(locale)
            let catalog = try CatalogValidator.validate(payload, requested: locale, reference: english)
            XCTAssertEqual(catalog.fallbackKeys, Set(payload.fallback), locale)
            XCTAssertEqual(payload.coverage?.englishFallback, payload.fallback.count, locale)
        }
        func rejects(_ locale: String, _ change: (inout CatalogPayload) -> Void, file: StaticString = #filePath, line: UInt = #line) {
            var payload = try! Self.payload(locale); change(&payload)
            XCTAssertThrowsError(try CatalogValidator.validate(payload, requested: locale, reference: english), file: file, line: line)
        }
        // A fallback plural uses English categories: Hebrew's `two` is not allowed in an English message.
        rejects("he") { $0.messages["post.like_count"] = .plural(["one": "Like {count}", "two": "Like {count}", "other": "Like {count}"]) }
        // A translated plural may only use the language's categories and must have `other` with the count.
        rejects("ru") { $0.messages["discussion.replies"] = .plural(["one": "{count} ответ", "two": "{count}", "other": "{count} ответа"]) }
        rejects("ru") { $0.messages["discussion.replies"] = .plural(["one": "{count} ответ"]) }
        rejects("ru") { $0.messages["discussion.replies"] = .plural(["other": "ответы"]) }
        rejects("he") { $0.schema = 1 }
        rejects("he") { $0.pluralCategories = ["one", "other"] }
        // A key marked as fallback whose value is not valid English-shaped text (Arabic forms) is rejected.
        rejects("ar") { $0.fallback = ["discussion.replies"] }
        // Unknown fallback keys are ignored; a translated plural without every category is accepted.
        var tolerant = try Self.payload("he"); tolerant.fallback.append("future.key")
        XCTAssertNoThrow(try CatalogValidator.validate(tolerant, requested: "he", reference: english))
        // Regional locales keep their own rules: Brazilian Portuguese uses `one` for 0, European Portuguese `other`.
        XCTAssertEqual(PluralRules.category(0, locale: "pt_BR"), .one); XCTAssertEqual(PluralRules.category(0, locale: "pt"), .other)
        XCTAssertNoThrow(try CatalogValidator.validate(Self.data("pt_BR"), requested: "pt_BR", reference: english))
    }

    func testIndexOffersOnlyLanguagesTheAppCanRenderAndMarksPartialOnes() throws {
        let index = try JSONDecoder().decode(CatalogIndex.self, from: Self.data("index"))
        XCTAssertEqual(index.locales.map(\.locale), ["en", "ar", "he", "ru", "pt_BR", "ja"])
        XCTAssertTrue(index.locales.allSatisfy(LocalizationController.isSupported))
        let entry = { (code: String) in index.locales.first { $0.locale == code }! }
        XCTAssertFalse(entry("en").isPartial); XCTAssertFalse(entry("ar").isPartial)
        XCTAssertTrue(entry("he").isPartial); XCTAssertTrue(entry("ru").isPartial)
        var mismatch = entry("ru"); mismatch.pluralCategories = ["one", "other"]
        XCTAssertFalse(LocalizationController.isSupported(mismatch), "server categories differ from the app's rules")
        var unknown = entry("ru"); unknown.locale = "tlh"
        XCTAssertFalse(LocalizationController.isSupported(unknown), "no app plural rules")
        var missing = entry("ru"); missing.pluralCategories = nil
        XCTAssertFalse(LocalizationController.isSupported(missing))
        var incomplete = entry("ru"); incomplete.complete = false
        XCTAssertFalse(LocalizationController.isSupported(incomplete))
    }

    func testOverlayCoversOnlyFomioKeysAndFallbackOnlyKeysWithoutValidTranslations() throws {
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: LocalizationCoverageTests.repository.appendingPathComponent("Localization/manifest.json"))) as? [String: Any])
        let keys = try XCTUnwrap(manifest["keys"] as? [String: [String: Any]])
        let fomio = Set(keys.filter { $0.value["source"] as? String == "fomio" }.keys)
        let overlay = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: LocalizationCoverageTests.repository.appendingPathComponent("Localization/catalogs/ar.json"))) as? [String: Any])
        let overlayKeys = Set(try XCTUnwrap(overlay["messages"] as? [String: Any]).keys)
        XCTAssertEqual(overlayKeys, fomio, "the Arabic overlay holds exactly the Fomio-specific keys")
        for locale in ["he", "ru", "pt_BR", "ja"] {
            let payload = try Self.payload(locale)
            XCTAssertTrue(fomio.isSubset(of: Set(payload.fallback)), "\(locale): no overlay, so every Fomio key is English")
            XCTAssertEqual(payload.coverage?.overlay, 0, locale)
            for key in payload.fallback { XCTAssertEqual(payload.messages[key], try Self.payload("en").messages[key], "\(locale) \(key) is English") }
        }
        XCTAssertEqual(try Self.payload("ar").fallback, [])
    }

    func testArgumentsKeepTheirOwnDirection() throws {
        let localizer = Localizer(english: english)
        // English interface, Arabic name: isolated so punctuation stays in place.
        XCTAssertEqual(localizer.string("auth.signed_in", [("name", "سارة")]), "Signed in as \u{2068}سارة\u{2069}.")
        XCTAssertEqual(localizer.string("auth.signed_in", [("name", "devon")]), "Signed in as devon.")
        localizer.activate(try CatalogValidator.validate(Self.data("ar"), requested: "ar", reference: english))
        XCTAssertEqual(localizer.string("auth.signed_in", [("name", "devon")]), "سجّلت الدخول باسم \u{2068}devon\u{2069}.")
        // An RTL message that starts with arguments is anchored right-to-left.
        XCTAssertEqual(localizer.string("topic.category_path", [("parent", "Electronics"), ("community", "Repairs")]), "\u{200F}\u{2068}Electronics\u{2069} › \u{2068}Repairs\u{2069}")
        XCTAssertEqual(localizer.formattingLocale.language.languageCode?.identifier, "ar")
    }

    func testAutonymNamesALanguageTheSiteNoLongerLists() {
        XCTAssertEqual(LocalizationController.autonym("ar"), "العربية")
        XCTAssertEqual(LocalizationController.autonym("en"), "English")
    }

    // MARK: Startup and refresh

    func testColdOfflineLaunchShowsEnglishAndSelectionFailsWithoutChangingChoice() async throws {
        let transport = ScriptedTransport()                      // every call fails offline
        let (controller, localizer) = controller(transport)
        XCTAssertEqual(localizer.catalog.locale, "en")
        XCTAssertEqual(controller.languages.map(\.locale), ["en"], "nothing to offer before the site index has ever loaded")
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let (chosen, chosenLocalizer) = self.controller(transport)
        XCTAssertEqual(chosenLocalizer.catalog.locale, "en", "a choice whose catalog is not cached shows English")
        await chosen.refresh()
        XCTAssertEqual(chosenLocalizer.catalog.locale, "en")
        let switched = await controller.select("ar")
        XCTAssertFalse(switched, "not offered while the index is unknown")
        XCTAssertEqual(controller.status, .failed("ar"))
        XCTAssertEqual(controller.selected, "en")
        XCTAssertTrue(localizer.catalog.messages.values.allSatisfy { if case let .text(value) = $0 { return !value.isEmpty }; return true })
    }

    func testFreshInstallStaysEnglishAfterCatalogDiscoveryRegardlessOfDeviceSiteOrMemberLocale() async throws {
        // The device/per-app language is not an input; the site's default locale ("ar") in the index is ignored.
        let transport = ScriptedTransport()
        transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
        let (controller, localizer) = controller(transport)
        try await offer(controller, transport, defaultLocale: "ar")
        await controller.refresh(force: true)
        XCTAssertEqual(controller.languages.map(\.locale), ["en", "ar"], "Arabic is offered")
        XCTAssertEqual(controller.selected, "en")
        XCTAssertEqual(localizer.catalog.locale, "en", "discovery never switches the language")
        XCTAssertEqual(transport.calls("ar"), 0, "an unselected language is never downloaded in the background")
        XCTAssertNil(defaults.string(forKey: LocalizationController.preferenceKey))
    }

    func testCachedArabicActivatesImmediatelyOfflineWithoutNetwork() throws {
        let clock = TestClock()
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-3 * 86_400))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let transport = ScriptedTransport()
        let (_, localizer) = controller(transport, clock: clock)
        XCTAssertEqual(localizer.catalog.locale, "ar", "active during init, before any refresh")
        XCTAssertEqual(localizer.layoutDirection, .rightToLeft)
        XCTAssertEqual(transport.calls("ar"), 0)
    }

    func testFreshCacheSkipsNetworkStaleCacheRevalidatesWithETagAnd304KeepsCatalog() async throws {
        let clock = TestClock()
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-3600))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let transport = ScriptedTransport()
        let (controller, localizer) = controller(transport, clock: clock)
        await controller.refresh()
        XCTAssertEqual(transport.calls("ar"), 0, "fresher than 24 hours")

        clock.now = clock.now.addingTimeInterval(LocalizationController.refreshInterval)
        transport.enqueue("ar", .success(.notModified))
        await controller.refresh()
        XCTAssertEqual(transport.etags("ar"), ["\"e1\""])
        XCTAssertEqual(localizer.catalog.revision, try Self.payload("ar").revision)
        XCTAssertEqual(controller.store.record("ar")?.fetchedAt, clock.now, "304 renews freshness")
        await controller.refresh()
        XCTAssertEqual(transport.calls("ar"), 1)
    }

    func testChangedOverrideRevisionAppearsOnNextSuccessfulRefresh() async throws {
        let clock = TestClock()
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-2 * 86_400))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let transport = ScriptedTransport()
        transport.enqueue("ar", .failure(.offline))
        transport.enqueue("ar", .success(.payload(try Self.arabic(revision: "override-2", home: "الرئيسة"), etag: "\"e2\"")))
        let (controller, localizer) = controller(transport, clock: clock)
        await controller.refresh()
        XCTAssertEqual(localizer.string("tab.home"), "الصفحة الرئيسية", "offline refresh keeps the cached revision")
        await controller.refresh()
        XCTAssertEqual(localizer.string("tab.home"), "الرئيسة")
        XCTAssertEqual(controller.store.record("ar")?.revision, "override-2")
        XCTAssertEqual(controller.store.record("ar")?.etag, "\"e2\"")
    }

    func testMalformedOrPartialResponsesKeepLastGoodCatalog() async throws {
        let clock = TestClock()
        let good = try Self.data("ar")
        try seed("ar", good, fetchedAt: clock.now.addingTimeInterval(-2 * 86_400))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        var partial = try Self.payload("ar"); partial.messages["tab.me"] = nil; partial.revision = "partial"
        let transport = ScriptedTransport()
        transport.enqueue("ar", .success(.payload(try Self.encode(partial), etag: "\"p\"")))
        transport.enqueue("ar", .success(.payload(Data("<html>proxy error</html>".utf8), etag: nil)))
        transport.enqueue("ar", .failure(.status(500)))
        let (controller, localizer) = controller(transport, clock: clock)
        for _ in 0..<3 {
            await controller.refresh(force: true)
            XCTAssertEqual(localizer.catalog.revision, try Self.payload("ar").revision)
            XCTAssertEqual(localizer.string("tab.me"), "أنا")
            XCTAssertEqual(controller.store.record("ar")?.payload, good)
        }
    }

    func testCorruptedCacheIsDeletedAndEnglishShown() throws {
        let store = LocalizationStore(root: root, site: "https://forum.example")
        try store.save(.init(locale: "ar", revision: "x", etag: nil, fetchedAt: Date(), lastUsedAt: Date(), payload: Data("not json".utf8)))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let (_, localizer) = controller(ScriptedTransport())
        XCTAssertEqual(localizer.catalog.locale, "en")
        XCTAssertNil(store.record("ar"))
        // A truncated record file (interrupted write outside the atomic path) is ignored, not shown.
        let file = store.directory.appendingPathComponent("catalog-ar.json")
        try Data("{\"locale\":\"ar\",\"rev".utf8).write(to: file)
        XCTAssertNil(store.record("ar"))
    }

    // MARK: Switching, eviction and isolation

    func testExplicitSelectionPersistsOnlyValidatedChoicesAcrossRelaunchAndOffline() async throws {
        let transport = ScriptedTransport()
        transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
        let (controller, localizer) = controller(transport)
        try await offer(controller, transport)
        do { let ok = await controller.select("ar"); XCTAssertTrue(ok) }
        XCTAssertEqual(defaults.string(forKey: LocalizationController.preferenceKey), "ar")
        XCTAssertEqual(localizer.catalog.locale, "ar"); XCTAssertEqual(localizer.layoutDirection, .rightToLeft)
        XCTAssertEqual(localizer.formattingLocale.language.languageCode?.identifier, "ar")
        // Relaunch offline: the choice and its last good cache are used immediately.
        let (relaunched, relaunchedLocalizer) = self.controller(ScriptedTransport())
        XCTAssertEqual(relaunched.selected, "ar"); XCTAssertEqual(relaunchedLocalizer.catalog.locale, "ar")
        // Back to English, then Arabic again offline from the retained cache (no second download).
        do { let ok = await controller.select("en"); XCTAssertTrue(ok) }
        XCTAssertNil(defaults.string(forKey: LocalizationController.preferenceKey))
        XCTAssertEqual(localizer.catalog.locale, "en"); XCTAssertEqual(localizer.layoutDirection, .leftToRight)
        do { let ok = await controller.select("ar"); XCTAssertTrue(ok) }
        XCTAssertEqual(transport.calls("ar"), 1)
    }

    func testFailedIncompleteAndUnsupportedSelectionsChangeNothing() async throws {
        let transport = ScriptedTransport()
        let (controller, localizer) = controller(transport)
        try await offer(controller, transport, [("en", true), ("ar", true), ("tlh", true), ("de", false)])
        XCTAssertEqual(controller.languages.map(\.locale), ["en", "ar"], "Klingon lacks app plural rules; German is incomplete")
        for code in ["tlh", "de", "xx"] {
            let ok = await controller.select(code)
            XCTAssertFalse(ok, code); XCTAssertEqual(transport.calls(code), 0, "not offered, never requested: \(code)")
        }
        var partial = try Self.payload("ar"); partial.messages["tab.me"] = nil
        transport.enqueue("ar", .success(.payload(try Self.encode(partial), etag: "\"p\"")))
        do { let ok = await controller.select("ar"); XCTAssertFalse(ok) }
        transport.enqueue("ar", .failure(.offline))
        do { let ok = await controller.select("ar"); XCTAssertFalse(ok) }
        XCTAssertEqual(controller.status, .failed("ar"))
        XCTAssertEqual(controller.selected, "en"); XCTAssertEqual(localizer.catalog.locale, "en")
        XCTAssertNil(defaults.string(forKey: LocalizationController.preferenceKey), "only validated choices persist")
        XCTAssertNil(controller.store.record("ar"), "an invalid catalog is never stored")
    }

    func testRemovedLanguageKeepsLastGoodCacheWithoutAutoSwitching() async throws {
        let clock = TestClock()
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-2 * 86_400))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let transport = ScriptedTransport()
        let (controller, localizer) = controller(transport, clock: clock)
        XCTAssertFalse(controller.selectionRemoved, "unknown until a fresh index arrives")
        try await offer(controller, transport, [("en", true)])
        await controller.refresh()
        XCTAssertTrue(controller.selectionRemoved)
        XCTAssertEqual(controller.selected, "ar"); XCTAssertEqual(localizer.catalog.locale, "ar", "no automatic switch")
        XCTAssertEqual(transport.calls("ar"), 0, "a removed language is not requested")
        XCTAssertNotNil(controller.store.record("ar"), "the last good cache is kept")
        XCTAssertEqual(controller.languages.map(\.locale), ["en"])
        XCTAssertEqual(controller.removedNoticeKey, "language.removed", "says the last downloaded copy is shown")
        // The member can still choose English; the site offering Arabic again clears the notice.
        try await offer(controller, transport)
        XCTAssertFalse(controller.selectionRemoved)
        XCTAssertNil(controller.removedNoticeKey)
    }

    func testOpeningLanguageRevalidatesAFreshCachedIndexAndFindsARemovedLanguage() async throws {
        let clock = TestClock()
        let store = LocalizationStore(root: root, site: "https://forum.example")
        try store.saveIndex(.init(etag: "\"i0\"", fetchedAt: clock.now.addingTimeInterval(-60), payload: try Self.index([("en", true), ("ar", true)])))
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-60))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let transport = ScriptedTransport()
        let (controller, localizer) = controller(transport, clock: clock)
        await controller.refresh()
        XCTAssertEqual(transport.state.withLock { $0.indexCalls }, 0, "launch trusts an index younger than 24 hours")
        XCTAssertFalse(controller.selectionRemoved)
        // Me › Language: the site has since removed Arabic.
        transport.enqueueIndex(.success(.payload(try Self.index([("en", true)]), etag: "\"i1\"")))
        await controller.revalidateLanguages()
        XCTAssertEqual(transport.state.withLock { $0.indexCalls }, 1, "opening Language revalidates despite the fresh cache")
        XCTAssertTrue(controller.selectionRemoved)
        XCTAssertEqual(controller.removedNoticeKey, "language.removed")
        XCTAssertEqual(controller.languages.map(\.locale), ["en"])
        XCTAssertEqual(localizer.catalog.locale, "ar", "no automatic switch"); XCTAssertEqual(controller.selected, "ar")
        XCTAssertNotNil(store.record("ar"), "the last good cache is kept")
        // Unchanged list: a 304 still counts as fresh and keeps the removal visible.
        transport.enqueueIndex(.success(.notModified))
        await controller.revalidateLanguages()
        XCTAssertTrue(controller.selectionRemoved)
    }

    func testRemovedLanguageWithMissingCorruptOrIncompatibleCacheShowsEnglishAndKeepsTheChoice() async throws {
        var incompatible = try CatalogValidator.decode(Self.data("ar"))
        incompatible.messages["tab.home"] = nil
        let caches: [(String, Data?)] = [("missing", nil), ("corrupt", Data("{not json".utf8)), ("incompatible", try JSONEncoder().encode(incompatible))]
        for (name, payload) in caches {
            try? FileManager.default.removeItem(at: root)
            if let payload {
                try LocalizationStore(root: root, site: "https://forum.example").save(.init(locale: "ar", revision: "r", etag: "\"e\"", fetchedAt: Date(), lastUsedAt: Date(), payload: payload))
            }
            defaults.set("ar", forKey: LocalizationController.preferenceKey)
            let transport = ScriptedTransport()
            let (controller, localizer) = controller(transport)
            XCTAssertEqual(localizer.catalog.locale, "en", "\(name): English fallback at launch")
            XCTAssertNil(controller.store.record("ar"), "\(name): an invalid cache is never kept or shown")
            try await offer(controller, transport, [("en", true)])
            await controller.refresh()
            XCTAssertTrue(controller.selectionRemoved, name)
            XCTAssertEqual(controller.removedNoticeKey, "language.removed_english", "\(name): says English is shown, not a downloaded copy")
            XCTAssertEqual(localizer.catalog.locale, "en", name)
            XCTAssertEqual(controller.selected, "ar", "\(name): the saved choice is kept")
            XCTAssertEqual(defaults.string(forKey: LocalizationController.preferenceKey), "ar", name)
            XCTAssertEqual(transport.calls("ar"), 0, "\(name): a removed language is not requested")
            XCTAssertNotEqual(L("language.removed_english", ["language": "العربية"]), L("language.removed", ["language": "العربية"]))
            // Offered again: the kept choice downloads on the next refresh.
            transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
            try await offer(controller, transport)
            await controller.refresh()
            XCTAssertNil(controller.removedNoticeKey, name)
            XCTAssertEqual(localizer.catalog.locale, "ar", "\(name): returns when offered again")
        }
    }

    func testEvictionKeepsCurrentAndOneRecentLanguage() async throws {
        let clock = TestClock()
        let store = LocalizationStore(root: root, site: "https://forum.example")
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-300))
        try seed("en", Self.data("en"), fetchedAt: clock.now.addingTimeInterval(-200))
        let transport = ScriptedTransport()
        transport.enqueue("ja", .success(.payload(try Self.japaneseLike(), etag: "\"j\"")))
        let (controller, _) = controller(transport, clock: clock)
        try await offer(controller, transport, [("en", true), ("ja", true)])
        do { let ok = await controller.select("ja"); XCTAssertTrue(ok) }
        XCTAssertEqual(store.storedLocales(), ["en", "ja"], "the least recently used language is removed")
    }

    func testCachesAreIsolatedBySiteRelativeRootAndSchema() throws {
        XCTAssertEqual(LocalizationStore.siteKey(URL(string: "https://Forum.Example/community/?x=1")!), "https://forum.example/community")
        XCTAssertNotEqual(LocalizationStore.siteKey(URL(string: "https://forum.example/a")!), LocalizationStore.siteKey(URL(string: "https://forum.example/b")!))
        try seed("ar", Self.data("ar"), site: "https://forum.example/a", fetchedAt: Date())
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let (_, other) = controller(ScriptedTransport(), site: "https://forum.example/b")
        XCTAssertEqual(other.catalog.locale, "en")
        let (_, same) = controller(ScriptedTransport(), site: "https://forum.example/a")
        XCTAssertEqual(same.catalog.locale, "ar")
        // A different schema directory for the site is removed on startup.
        let store = LocalizationStore(root: root, site: "https://forum.example/a")
        let old = store.directory.deletingLastPathComponent().appendingPathComponent("schema-0")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        _ = controller(ScriptedTransport(), site: "https://forum.example/a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    }

    func testConcurrentRefreshesShareOneRequest() async throws {
        let transport = ScriptedTransport(delay: .milliseconds(200))
        transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let (controller, localizer) = controller(transport)
        async let first: Void = controller.refresh()
        async let second: Void = controller.refresh()
        async let third = controller.download("ar")
        _ = await (first, second, third)
        XCTAssertEqual(transport.calls("ar"), 1)
        XCTAssertEqual(localizer.catalog.locale, "ar")
    }

    // MARK: Transport contract

    func testDiscourseTransportSendsConditionalPublicRequestsUnderRelativeRoot() async throws {
        let configuration = LiveConfiguration(baseURL: URL(string: "https://forum.example/community")!, callbackURL: URL(string: "fomio://auth")!, scopes: "read")
        let session = URLSession(configuration: { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [CatalogStubProtocol.self]; return c }())
        let transport = DiscourseLocalizationTransport(configuration: configuration, indexPath: "app-locales/{schema}/index.json", catalogPath: "app-locales/{schema}/{locale}.json", session: session)
        CatalogStubProtocol.respond = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "User-Api-Key"), "catalogs are public; no member key")
            XCTAssertEqual(request.url?.path, "/community/app-locales/2/ar.json")
            return request.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"" ? (304, [:], Data()) : (200, ["ETag": "\"v1\""], Data("{}".utf8))
        }
        let fresh = try await transport.catalog(locale: "ar", etag: nil)
        XCTAssertEqual(fresh, .payload(Data("{}".utf8), etag: "\"v1\""))
        let revalidated = try await transport.catalog(locale: "ar", etag: "\"v1\"")
        XCTAssertEqual(revalidated, .notModified)
        CatalogStubProtocol.respond = { _ in (404, [:], Data()) }
        do { _ = try await transport.catalog(locale: "ar", etag: nil); XCTFail() } catch { XCTAssertEqual(error as? TransportError, .unavailable) }
        do { _ = try await transport.catalog(locale: "../x", etag: nil); XCTFail() } catch { XCTAssertEqual(error as? TransportError, .unavailable) }
        let configured = try XCTUnwrap(DiscourseLocalizationTransport.fromBundle(configuration), "live builds use the site's catalog endpoint")
        XCTAssertEqual(configured.indexPath, "fomio/app-locales/{schema}/index.json")
        XCTAssertEqual(configured.catalogPath, "fomio/app-locales/{schema}/{locale}.json")
    }
}

final class CatalogStubProtocol: URLProtocol {
    nonisolated(unsafe) static var respond: (URLRequest) -> (Int, [String: String], Data) = { _ in (500, [:], Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, headers, body) = Self.respond(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Source-level checks: every key the app uses exists, no catalog key is orphaned, the backend manifest
/// covers exactly the catalog, and interface calls do not contain untranslated literals.
final class LocalizationCoverageTests: XCTestCase {
    static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static func sources() throws -> [(String, String)] {
        let folder = repository.appendingPathComponent("Fomio")
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }
    func testEveryUsedKeyExistsAndNoCatalogKeyIsOrphaned() throws {
        let english = Set(Localizer.shared.english.messages.keys)
        var literals = Set<String>(), called = Set<String>()
        for (_, text) in try Self.sources() {
            for match in text.matches(of: /"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"/) { literals.insert(String(match.1)) }
            for match in text.matches(of: /\bLText?\("([^"\\]+)"/) { called.insert(String(match.1)) }
            for match in text.matches(of: /\.message\("([^"\\]+)"\)/) { called.insert(String(match.1)) }
        }
        XCTAssertEqual(called.subtracting(english).sorted(), [], "keys used in code but missing from the English catalog")
        let dynamic = Set(AppTab.allCases.map { "tab.\($0.rawValue)" })
        XCTAssertEqual(english.subtracting(literals).subtracting(dynamic).sorted(), [], "catalog keys no code uses")
    }
    func testManifestCoversCatalogAndMappingsAreWellFormed() throws {
        let data = try Data(contentsOf: Self.repository.appendingPathComponent("Localization/manifest.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = try XCTUnwrap(manifest["keys"] as? [String: [String: Any]])
        XCTAssertEqual(Set(keys.keys), Set(Localizer.shared.english.messages.keys))
        for (key, entry) in keys {
            switch entry["source"] as? String {
            case "discourse": XCTAssertTrue((entry["discourse_key"] as? String)?.hasPrefix("js.") == true, key)
            case "fomio": XCTAssertNil(entry["discourse_key"], key)
            default: XCTFail("unknown source for \(key)")
            }
        }
        // Topic/category nouns are Fomio-owned until a reviewed terminology variant exists.
        let mapped = keys.filter { $0.value["source"] as? String == "discourse" }.compactMap { $0.value["discourse_key"] as? String }
        XCTAssertFalse(mapped.contains { $0.hasPrefix("js.topic.create") || $0.hasPrefix("js.category") || $0 == "js.topic.title" })
    }
    /// Localized fragments inserted into another message must name it (`within:`), so the sentence stays in one language.
    func testComposedFragmentsNameTheirContainer() throws {
        let pattern = /\[[^\]]*"[a-z]+": [^\]]*(\.compact\b(?!\(within)|style\.title\b(?!\(within)|L\("[a-z._]+"\)(?!, within))/
        var findings: [String] = []
        for (name, text) in try Self.sources() {
            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where line.contains("L(\"") && line.contains(pattern) {
                findings.append("\(name):\(number + 1)")
            }
        }
        XCTAssertEqual(findings, [])
    }
    func testInterfaceCallsHaveNoHardCodedCopy() throws {
        // Fixture content and development presets are fictional server content, not interface copy.
        let exempt: Set = ["FixtureService.swift", "DevelopmentPresets.swift"]
        let pattern = /(?:\b(?:Text|Button|Label|Section|Toggle|TextField|Link|Picker|Stepper|DatePicker|DisclosureGroup|ProgressView|ContentUnavailableView)\("[A-Za-z][^"]*"|\.(?:accessibilityLabel|accessibilityHint|accessibilityValue|navigationTitle|alert|confirmationDialog)\("|(?:title|message|prompt|actionTitle|placeholder|label): "[A-Z]|toast\("|(?:banner|error|rejection) = "|String\(localized|LocalizedStringKey|NSLocalizedString)/
        var findings: [String] = []
        for (name, text) in try Self.sources() where !exempt.contains(name) {
            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where line.contains(pattern) && !line.contains("DevText(") {
                findings.append("\(name):\(number + 1)")
            }
        }
        XCTAssertEqual(findings, [])
    }
}
