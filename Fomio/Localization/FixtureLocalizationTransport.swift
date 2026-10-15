import Foundation
import CryptoKit
import Synchronization

/// Development stand-in for the proposed catalog endpoints. It serves the maintained translation files
/// under `Localization/catalogs` (Debug builds only; Release excludes them) with ETag/304 behavior.
/// Fixture responses are not evidence that a deployed endpoint exists.
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

    private func source(_ locale: String) -> Data? {
        // The server's English is the bundled English plus site overrides; the fixture serves it unchanged.
        let url = locale == "en" ? bundle.url(forResource: "fomio-catalog-en", withExtension: "json") : bundle.url(forResource: locale, withExtension: "json", subdirectory: "catalogs")
        guard let url else { return nil }
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
        var locales: [[String: Any]] = (current.removedArabic ? ["en"] : ["en", "ar"]).compactMap { code in
            guard let data = source(code), let payload = try? CatalogValidator.decode(data) else { return nil }
            return ["locale": code, "name": code == "ar" ? "Arabic" : "English", "native_name": code == "ar" ? "العربية" : "English", "direction": payload.direction, "complete": payload.complete, "revision": payload.revision]
        }
        // Entries the app must not offer: French has no plural rules in this app; German is incomplete.
        locales.append(["locale": "fr", "name": "French", "native_name": "Français", "direction": "ltr", "complete": true, "revision": "fixture-fr"])
        locales.append(["locale": "de", "name": "German", "native_name": "Deutsch", "direction": "ltr", "complete": false])
        let data = try JSONSerialization.data(withJSONObject: ["schema": LocalizationCatalog.schema, "default_locale": current.siteDefaultLocale, "locales": locales], options: [.sortedKeys])
        return try await respond(data, etag: etag)
    }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse {
        if options.withLock({ $0.removedArabic }) && locale == "ar" { try await Task.sleep(for: options.withLock { $0.delay }); throw TransportError.unavailable }
        guard var data = source(locale) else { try await Task.sleep(for: options.withLock { $0.delay }); throw TransportError.status(404) }
        let current = options.withLock { $0 }
        if (current.changedOverride && locale == "en") || (current.incompleteArabic && locale == "ar"), var payload = try? CatalogValidator.decode(data) {
            if locale == "en" { payload.messages["tab.home"] = .text("Home feed"); payload.revision += "-override-2" }
            else { payload.messages["tab.home"] = nil; payload.revision += "-partial" }
            data = (try? JSONEncoder().encode(payload)) ?? data
        }
        return try await respond(data, etag: etag)
    }
}
