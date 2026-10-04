import Foundation

struct LiveConfiguration: Sendable {
    let baseURL: URL
    let callbackURL: URL
    let scopes: String
    static func fromBundle() -> LiveConfiguration? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FomioBaseURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              let callback = Bundle.main.object(forInfoDictionaryKey: "FomioAuthCallback") as? String,
              let callbackURL = URL(string: callback), callbackURL.scheme != nil,
              let scopes = Bundle.main.object(forInfoDictionaryKey: "FomioUserAPIScopes") as? String, !scopes.isEmpty else { return nil }
        return LiveConfiguration(baseURL: url, callbackURL: callbackURL, scopes: scopes)
    }
    func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var url = baseURL
        for segment in path.split(separator: "/") { url.appendPathComponent(String(segment)) }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }
    func topicURL(_ id: TopicID, number: PostNumber?) -> URL { url("t/\(id.rawValue)" + (number.map { "/\($0.rawValue)" } ?? "")) }
}
struct Credential: Codable, Sendable { let key: String; let clientID: String; let site: String }
class SameOriginDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let target = request.url,
              original.host == target.host, original.scheme == target.scheme, original.port == target.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}
final class UploadProgressDelegate: SameOriginDelegate, @unchecked Sendable {
    let progress: @MainActor @Sendable (Double) -> Void
    init(progress: @escaping @MainActor @Sendable (Double) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        Task { @MainActor in progress(fraction) }
    }
}
@MainActor final class APIClient {
    let configuration: LiveConfiguration?
    let session: URLSession
    let credentials: (String) throws -> Credential?
    init(configuration: LiveConfiguration?, session: URLSession? = nil, credentials: @escaping (String) throws -> Credential? = KeychainCredentialStore.read) {
        self.configuration = configuration; self.credentials = credentials
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        self.session = session ?? URLSession(configuration: config, delegate: SameOriginDelegate(), delegateQueue: nil)
    }
    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil, contentType: String? = nil, member: Bool = false, uploadProgress: (@MainActor @Sendable (Double) -> Void)? = nil) async throws -> Data {
        guard let configuration else { throw RepositoryError.configuration }
        var request = URLRequest(url: configuration.url(path, query: query))
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let credential = try credentials(configuration.baseURL.absoluteString)
        if member && credential == nil { throw RepositoryError.unauthorized }
        if let credential {
            request.setValue(credential.key, forHTTPHeaderField: "User-Api-Key")
            request.setValue(credential.clientID, forHTTPHeaderField: "User-Api-Client-Id")
        }
        let data: Data
        let response: URLResponse
        do {
            if let body, let uploadProgress {
                request.httpBody = nil
                (data, response) = try await session.upload(for: request, from: body, delegate: UploadProgressDelegate(progress: uploadProgress))
            } else { (data, response) = try await session.data(for: request) }
        }
        catch is CancellationError { throw CancellationError() }
        catch { if method != "GET" && method != "HEAD" { throw RepositoryError.unconfirmed }; throw RepositoryError.offline }
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.unconfirmed }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw RepositoryError.unauthorized
        case 403: throw RepositoryError.denied
        case 404: throw RepositoryError.unavailable
        case 400, 409, 422:
            let error = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw RepositoryError.invalid(error?.errors?.joined(separator: "\n") ?? error?.message ?? "The community could not accept the request.")
        case 429: throw RepositoryError.rateLimited
        default: if method == "POST" { throw RepositoryError.unconfirmed }; throw RepositoryError.server(http.statusCode)
        }
    }
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
    func get<T: Decodable>(_ type: T.Type, _ path: String, query: [URLQueryItem] = [], member: Bool = false) async throws -> T {
        try decode(type, from: await request(path, query: query, member: member))
    }
    func json(_ path: String, method: String = "POST", payload: [String: Any]) async throws -> Data {
        try await request(path, method: method, body: JSONSerialization.data(withJSONObject: payload), contentType: "application/json", member: true)
    }
    private struct ErrorEnvelope: Decodable { var errors: [String]?; var message: String? }
}
struct LinkRouter {
    static func route(_ url: URL, baseURL: URL) -> Route? {
        guard url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return nil }
        let base = baseURL.path.split(separator: "/").map(String.init)
        let all = url.path.split(separator: "/").map(String.init)
        guard all.starts(with: base) else { return nil }
        let parts = Array(all.dropFirst(base.count))
        guard let kind = parts.first else { return nil }
        if kind == "t" || kind == "n" {
            let idIndex = parts.count > 1 && Int(parts[1]) != nil ? 1 : 2
            guard parts.indices.contains(idIndex), let id = Int(parts[idIndex]), id > 0 else { return nil }
            var number: PostNumber?
            if parts.indices.contains(idIndex + 1), let value = Int(parts[idIndex + 1]), value > 0 { number = .init(value) }
            else if parts.count > idIndex + 2, parts[idIndex + 1] == "context", let value = Int(parts[idIndex + 2]), value > 0 { number = .init(value) }
            return .discussion(.init(id), number)
        }
        if kind == "c", let value = parts.last.flatMap(Int.init), value > 0 { return .community(.init(value)) }
        if kind == "u", parts.count == 2 { return .profile(parts[1]) }
        return nil
    }
}
