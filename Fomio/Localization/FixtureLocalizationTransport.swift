import Foundation
import CryptoKit
import Synchronization

/// Development stand-in for the catalog endpoints (Debug builds only; Release excludes the fixtures). It serves
/// catalogs assembled by the real backend plugin (`script/export_catalogs.rb`) under `Localization/fixtures`:
/// English, Arabic (Discourse + Fomio overlay), and Hebrew, Russian, Brazilian Portuguese and Japanese (Discourse
/// translations with English fallback, no overlay), with ETag/304 behavior. Fixture responses are not evidence
/// that a deployed endpoint behaves the same way.
final class FixtureLocalizationTransport: LocalizationTransport {
    struct Options: Sendable {
        var offline = false
        var delay: Duration = .milliseconds(150)
        /// Simulates a changed site-text override on the server: English "Home" gains a new revision.
        var changedOverride = false
        /// Simulates a server bug: Arabic omits one required key.
        var incompleteArabic = false
        /// The site's default locale in the index; the app must ignore it.
        var siteDefaultLocale = "en"
        /// Simulates the site no longer offering Arabic: the index omits it and its catalog 404s.
        var removedArabic = false
    }
    let bundle: Bundle
    let options: Mutex<Options>
    init(bundle: Bundle = .main, options: Options = Options()) { self.bundle = bundle; self.options = Mutex(options) }

    private func source(_ name: String) -> Data? {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "fixtures") else { return nil }
        return try? Data(contentsOf: url)
    }
    private func respond(_ data: Data, etag: String?) async throws -> TransportResponse {
        let current = options.withLock { $0 }
        try await Task.sleep(for: current.delay)
        guard !current.offline else { throw TransportError.offline }
        let tag = "\"" + SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined() + "\""
        return etag == tag ? .notModified : .payload(data, etag: tag)
    }
    func index(etag: String?) async throws -> TransportResponse {
        let current = options.withLock { $0 }
        guard let data = source("index"), var index = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var locales = index["locales"] as? [[String: Any]] else { throw TransportError.status(500) }
        if current.removedArabic { locales.removeAll { $0["locale"] as? String == "ar" } }
        // Entries the app must not offer: Klingon has no plural rules in this app; German is incomplete.
        locales.append(["locale": "tlh", "name": "Klingon", "native_name": "tlhIngan Hol", "direction": "ltr", "complete": true, "plural_categories": ["one", "other"], "revision": "fixture-tlh"])
        locales.append(["locale": "de", "name": "German", "native_name": "Deutsch", "direction": "ltr", "complete": false, "plural_categories": ["one", "other"]])
        index["locales"] = locales
        index["default_locale"] = current.siteDefaultLocale
        return try await respond(try JSONSerialization.data(withJSONObject: index, options: [.sortedKeys]), etag: etag)
    }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse {
        if options.withLock({ $0.removedArabic }) && locale == "ar" { try await Task.sleep(for: options.withLock { $0.delay }); throw TransportError.unavailable }
        guard LocaleMatcher.isValidCode(locale), var data = source(locale) else { try await Task.sleep(for: options.withLock { $0.delay }); throw TransportError.status(404) }
        let current = options.withLock { $0 }
        if (current.changedOverride && locale == "en") || (current.incompleteArabic && locale == "ar"), var payload = try? CatalogValidator.decode(data) {
            if locale == "en" { payload.messages["tab.home"] = .text("Home feed"); payload.revision += "-override-2" }
            else { payload.messages["tab.home"] = nil; payload.revision += "-partial" }
            data = (try? JSONEncoder().encode(payload)) ?? data
        }
        return try await respond(data, etag: etag)
    }
}
