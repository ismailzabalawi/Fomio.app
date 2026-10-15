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
        let url = name == "en" ? Bundle.main.url(forResource: "fomio-catalog-en", withExtension: "json") : Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "catalogs")
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
    func controller(_ transport: some LocalizationTransport, site: String = "https://forum.example", clock: TestClock = TestClock(), languages: [String] = ["en-US"]) -> (LocalizationController, Localizer) {
        let localizer = Localizer(english: english)
        let store = LocalizationStore(root: root, site: site)
        return (LocalizationController(localizer: localizer, store: store, transport: transport, defaults: defaults, now: { clock.now }, preferredLanguages: { languages }), localizer)
    }
    func seed(_ locale: String, _ data: Data, site: String = "https://forum.example", fetchedAt: Date, etag: String? = "\"e1\"") throws {
        let catalog = try CatalogValidator.validate(data, requested: locale, reference: english)
        try LocalizationStore(root: root, site: site).save(.init(locale: locale, revision: catalog.revision, etag: etag, fetchedAt: fetchedAt, lastUsedAt: fetchedAt, payload: data))
    }
    static func index(_ locales: [(String, Bool)]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schema": 1, "default_locale": "en", "locales": locales.map { ["locale": $0.0, "name": $0.0, "native_name": $0.0, "direction": $0.0 == "ar" ? "rtl" : "ltr", "complete": $0.1] }])
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
        rejects { $0.schema = 2 }
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
        rejects { $0.messages["discussion.replies"] = .plural(["one": "رد", "other": "{count} رد"]) } // missing Arabic forms
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
        XCTAssertNil(PluralRules.categories(for: "fr"), "a language is only enabled together with verified plural rules")
        let localizer = Localizer(english: english)
        localizer.activate(try CatalogValidator.validate(Self.data("ar"), requested: "ar", reference: english))
        XCTAssertEqual(localizer.string("discussion.replies", count: 1), "رد واحد")
        XCTAssertEqual(localizer.string("discussion.replies", count: 2), "ردّان")
        XCTAssertTrue(localizer.string("discussion.replies", count: 4).hasSuffix("ردود"))
        XCTAssertTrue(localizer.string("discussion.replies", count: 14).hasSuffix("ردًا"))
        XCTAssertEqual(Localizer(english: english).string("discussion.replies", count: 1200), "1,200 replies")
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

    func testLocaleMatchingUsesExplicitMapping() {
        XCTAssertEqual(LocaleMatcher.match(preferred: ["ar-SA", "en"], available: ["en", "ar"]), "ar")
        XCTAssertEqual(LocaleMatcher.match(preferred: ["en-GB"], available: ["en", "ar"]), "en")
        XCTAssertEqual(LocaleMatcher.match(preferred: ["pt-BR"], available: ["en", "pt", "pt_BR"]), "pt_BR")
        XCTAssertEqual(LocaleMatcher.match(preferred: ["zh-Hans-CN"], available: ["en", "zh_CN", "zh_TW"]), "zh_CN")
        XCTAssertNil(LocaleMatcher.match(preferred: ["fr-FR", "de"], available: ["en", "ar"]))
        XCTAssertEqual(LocalizationController.autonym("ar"), "العربية", "a language not yet listed by the site is named in its own language")
        XCTAssertEqual(LocalizationController.autonym("en"), "English")
    }

    // MARK: Startup and refresh

    func testColdOfflineLaunchShowsEnglishAndSelectionFailsWithoutChangingPreference() async throws {
        let transport = ScriptedTransport()                      // every call fails offline
        let (controller, localizer) = controller(transport, languages: ["ar-SA"])
        defaults.set("ar", forKey: LocalizationController.preferenceKey)
        let (chosen, chosenLocalizer) = self.controller(transport, languages: ["ar-SA"])
        XCTAssertEqual(localizer.catalog.locale, "en")
        XCTAssertEqual(chosenLocalizer.catalog.locale, "en", "a chosen language that never downloaded shows English")
        await chosen.refresh()
        XCTAssertEqual(chosenLocalizer.catalog.locale, "en")
        let switched = await controller.select(.locale("ar"))
        XCTAssertFalse(switched)
        XCTAssertEqual(controller.status, .failed("ar"))
        XCTAssertEqual(controller.preference, .system)
        XCTAssertEqual(localizer.catalog.locale, "en")
        XCTAssertTrue(localizer.catalog.messages.values.allSatisfy { if case let .text(value) = $0 { return !value.isEmpty }; return true })
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
        XCTAssertEqual(localizer.catalog.revision, "maintained-ar-1")
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
            XCTAssertEqual(localizer.catalog.revision, "maintained-ar-1")
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

    func testSwitchingLanguagesPersistsPreferenceAndChangesCatalogTogether() async throws {
        let transport = ScriptedTransport()
        transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
        let (controller, localizer) = controller(transport)
        do { let ok = await controller.select(.locale("ar")); XCTAssertTrue(ok) }
        XCTAssertEqual(defaults.string(forKey: LocalizationController.preferenceKey), "ar")
        XCTAssertEqual(localizer.catalog.locale, "ar"); XCTAssertEqual(localizer.layoutDirection, .rightToLeft)
        XCTAssertEqual(localizer.formattingLocale.language.languageCode?.identifier, "ar")
        do { let ok = await controller.select(.locale("en")); XCTAssertTrue(ok) }
        XCTAssertEqual(localizer.catalog.locale, "en"); XCTAssertEqual(localizer.layoutDirection, .leftToRight)
        // Switching back uses the retained Arabic catalog without another download.
        do { let ok = await controller.select(.locale("ar")); XCTAssertTrue(ok) }
        XCTAssertEqual(transport.calls("ar"), 1)
        do { let ok = await controller.select(.system); XCTAssertTrue(ok) }
        XCTAssertNil(defaults.string(forKey: LocalizationController.preferenceKey))
        XCTAssertEqual(localizer.catalog.locale, "en")
    }

    func testDeviceLanguageFollowsSiteIndexAndIgnoresIncompleteLanguages() async throws {
        let transport = ScriptedTransport()
        transport.enqueueIndex(.success(.payload(try Self.index([("en", true), ("ar", true), ("fr", false)]), etag: "\"i\"")))
        transport.enqueue("ar", .success(.payload(try Self.data("ar"), etag: "\"a\"")))
        let (controller, localizer) = controller(transport, languages: ["fr-FR", "ar-EG", "en"])
        XCTAssertEqual(controller.target, "en", "unknown before the site index arrives")
        await controller.refresh()
        XCTAssertEqual(controller.languages.map(\.locale), ["en", "ar"])
        XCTAssertEqual(localizer.catalog.locale, "ar")
    }

    func testEvictionKeepsCurrentAndOneRecentLanguage() async throws {
        let clock = TestClock()
        let store = LocalizationStore(root: root, site: "https://forum.example")
        try seed("ar", Self.data("ar"), fetchedAt: clock.now.addingTimeInterval(-300))
        try seed("en", Self.data("en"), fetchedAt: clock.now.addingTimeInterval(-200))
        let transport = ScriptedTransport()
        transport.enqueue("ja", .success(.payload(try Self.japaneseLike(), etag: "\"j\"")))
        let (controller, _) = controller(transport, clock: clock)
        do { let ok = await controller.select(.locale("ja")); XCTAssertTrue(ok) }
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
            XCTAssertEqual(request.url?.path, "/community/app-locales/1/ar.json")
            return request.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"" ? (304, [:], Data()) : (200, ["ETag": "\"v1\""], Data("{}".utf8))
        }
        let fresh = try await transport.catalog(locale: "ar", etag: nil)
        XCTAssertEqual(fresh, .payload(Data("{}".utf8), etag: "\"v1\""))
        let revalidated = try await transport.catalog(locale: "ar", etag: "\"v1\"")
        XCTAssertEqual(revalidated, .notModified)
        CatalogStubProtocol.respond = { _ in (404, [:], Data()) }
        do { _ = try await transport.catalog(locale: "ar", etag: nil); XCTFail() } catch { XCTAssertEqual(error as? TransportError, .unavailable) }
        do { _ = try await transport.catalog(locale: "../x", etag: nil); XCTFail() } catch { XCTAssertEqual(error as? TransportError, .unavailable) }
        XCTAssertNil(DiscourseLocalizationTransport.fromBundle(configuration), "no catalog paths are configured until the backend contract is deployed")
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
