import Foundation

enum TransportResponse: Equatable, Sendable {
    case notModified
    case payload(Data, etag: String?)
}
enum TransportError: Error, Equatable, Sendable {
    /// No catalog contract is configured for this site, or the server does not offer it.
    case unavailable
    case offline
    case status(Int)
    case tooLarge
}

/// Read-only access to the public interface catalog contract. Implementations never attach user keys.
protocol LocalizationTransport: Sendable {
    func index(etag: String?) async throws -> TransportResponse
    func catalog(locale: String, etag: String?) async throws -> TransportResponse
}

#if DEBUG
/// Live-mode UI tests: every catalog request fails as if the device were offline.
struct OfflineLocalizationTransport: LocalizationTransport {
    func index(etag: String?) async throws -> TransportResponse { throw TransportError.offline }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse { throw TransportError.offline }
}
#endif

/// Used when the site has not published a native catalog contract. Only bundled English is shown.
struct UnavailableLocalizationTransport: LocalizationTransport {
    func index(etag: String?) async throws -> TransportResponse { throw TransportError.unavailable }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse { throw TransportError.unavailable }
}

/// HTTP transport for the public catalog endpoints served by the `discourse-fomio-app-locales` plugin. Paths come
/// from the app's Info values (`FomioLocaleIndexPath`, `FomioLocaleCatalogPath` with `{schema}` and `{locale}`).
/// Anonymous: no cookies, credentials or member keys. A 404 (the plugin is not deployed yet) keeps bundled English.
struct DiscourseLocalizationTransport: LocalizationTransport {
    let configuration: LiveConfiguration
    let indexPath: String
    let catalogPath: String
    let session: URLSession

    init(configuration: LiveConfiguration, indexPath: String, catalogPath: String, session: URLSession? = nil) {
        self.configuration = configuration; self.indexPath = indexPath; self.catalogPath = catalogPath
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = session ?? URLSession(configuration: config, delegate: SameOriginDelegate(), delegateQueue: nil)
    }
    static func fromBundle(_ configuration: LiveConfiguration, bundle: Bundle = .main) -> DiscourseLocalizationTransport? {
        guard let index = bundle.object(forInfoDictionaryKey: "FomioLocaleIndexPath") as? String, !index.isEmpty,
              let catalog = bundle.object(forInfoDictionaryKey: "FomioLocaleCatalogPath") as? String, catalog.contains("{locale}") else { return nil }
        return DiscourseLocalizationTransport(configuration: configuration, indexPath: index, catalogPath: catalog)
    }
    func index(etag: String?) async throws -> TransportResponse {
        try await get(indexPath.replacingOccurrences(of: "{schema}", with: String(LocalizationCatalog.schema)), etag: etag)
    }
    func catalog(locale: String, etag: String?) async throws -> TransportResponse {
        guard LocaleMatcher.isValidCode(locale) else { throw TransportError.unavailable }
        let path = catalogPath.replacingOccurrences(of: "{schema}", with: String(LocalizationCatalog.schema)).replacingOccurrences(of: "{locale}", with: locale)
        return try await get(path, etag: etag)
    }
    private func get(_ path: String, etag: String?) async throws -> TransportResponse {
        var request = URLRequest(url: configuration.url(path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw TransportError.offline }
        guard let http = response as? HTTPURLResponse else { throw TransportError.offline }
        switch http.statusCode {
        case 304: return .notModified
        case 200:
            guard data.count <= CatalogValidator.maximumPayloadBytes else { throw TransportError.tooLarge }
            return .payload(data, etag: http.value(forHTTPHeaderField: "ETag"))
        case 404, 410: throw TransportError.unavailable
        default: throw TransportError.status(http.statusCode)
        }
    }
}
