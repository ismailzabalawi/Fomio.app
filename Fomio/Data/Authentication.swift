import Foundation
import AuthenticationServices
import Security
import UIKit

struct KeychainCredentialStore {
    static func read(site: String) throws -> Credential? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Fomio.UserAPI", kSecAttrAccount as String: site, kSecReturnData as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw RepositoryError.invalid("Could not read the saved authorization.") }
        return try JSONDecoder().decode(Credential.self, from: data)
    }
    static func save(_ credential: Credential) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Fomio.UserAPI", kSecAttrAccount as String: credential.site]
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(credential), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if result == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw RepositoryError.invalid("Could not save authorization securely.") }
        } else if result != errSecSuccess { throw RepositoryError.invalid("Could not update authorization securely.") }
    }
    static func delete(site: String) throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Fomio.UserAPI", kSecAttrAccount as String: site] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw RepositoryError.invalid("Could not remove saved authorization.") }
    }
}
@MainActor final class AuthenticationService: NSObject, ASWebAuthenticationPresentationContextProviding {
    let configuration: LiveConfiguration
    private var session: ASWebAuthenticationSession?
    private var anchor: ASPresentationAnchor?
    private var pendingCallback: CheckedContinuation<URL, any Error>?
    init(configuration: LiveConfiguration) { self.configuration = configuration }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor!
    }
    func signIn() async throws -> String {
        guard session == nil else { throw RepositoryError.invalid("Sign-in is already in progress.") }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { throw RepositoryError.invalid("No active window is available for sign-in.") }
        anchor = window
        defer { session = nil; anchor = nil }
        let nonce = UUID().uuidString
        let clientID = try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString)?.clientID ?? UUID().uuidString
        var keyError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey([kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048] as CFDictionary, &keyError),
              let publicKey = SecKeyCopyPublicKey(privateKey), let bytes = SecKeyCopyExternalRepresentation(publicKey, &keyError) as Data? else { throw RepositoryError.invalid("Could not prepare secure authorization.") }
        let authorizationURL = Self.authorizationURL(configuration: configuration, clientID: clientID, nonce: nonce, publicKeyPEM: Self.publicKeyPEM(bytes))
        let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
            pendingCallback = continuation
            session = ASWebAuthenticationSession(url: authorizationURL, callbackURLScheme: configuration.callbackURL.scheme) { url, error in
                Task { @MainActor in
                    if let url { self.finishCallback(.success(url)) }
                    else { self.finishCallback(.failure(error ?? RepositoryError.unauthorized)) }
                }
            }
            session?.presentationContextProvider = self
            if session?.start() != true { session = nil; finishCallback(.failure(RepositoryError.invalid("Could not open authorization."))) }
        }
        session = nil
        guard Self.matchesCallback(callback, expected: configuration.callbackURL),
              let encrypted = Self.encryptedPayload(from: callback),
              let clear = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA1, encrypted as CFData, &keyError) as Data? else { throw RepositoryError.invalid("Authorization callback was invalid.") }
        let payload = try JSONDecoder().decode(AuthPayload.self, from: clear)
        guard payload.nonce == nonce, !payload.key.isEmpty else { throw RepositoryError.invalid("Authorization callback did not match this attempt.") }
        let credential = Credential(key: payload.key, clientID: clientID, site: configuration.baseURL.absoluteString)
        try KeychainCredentialStore.save(credential)
        do { return try await currentUsername() }
        catch { try? KeychainCredentialStore.delete(site: credential.site); throw error }
    }
    /// PKCS#1 DER from `SecKeyCopyExternalRepresentation`, wrapped as PEM for Discourse's `OpenSSL::PKey::RSA.new`.
    nonisolated static func publicKeyPEM(_ pkcs1: Data) -> String {
        "-----BEGIN RSA PUBLIC KEY-----\n\(pkcs1.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]))\n-----END RSA PUBLIC KEY-----"
    }
    nonisolated static func authorizationURL(configuration: LiveConfiguration, clientID: String, nonce: String, publicKeyPEM: String) -> URL {
        let query = ["application_name": "Fomio", "client_id": clientID, "nonce": nonce, "public_key": publicKeyPEM, "scopes": configuration.scopes, "auth_redirect": configuration.callbackURL.absoluteString, "padding": "oaep"].map { URLQueryItem(name: $0.key, value: $0.value) }
        return configuration.url("user-api-key/new", query: query)
    }
    nonisolated static func matchesCallback(_ url: URL, expected: URL) -> Bool {
        url.scheme == expected.scheme && url.host == expected.host && url.path == expected.path
    }
    nonisolated static func encryptedPayload(from callback: URL) -> Data? {
        guard let encoded = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "payload" })?.value else { return nil }
        // Discourse uses Ruby Base64.encode64, which inserts line breaks in the encrypted payload.
        // Strip only those line endings, retaining strict rejection of other invalid characters.
        return Data(base64Encoded: encoded.filter { $0 != "\r" && $0 != "\n" })
    }
    /// iOS may deliver a registered custom URL to the app instead of the web session completion.
    /// Both paths feed the same one-shot continuation; the cryptographic checks remain in signIn().
    func receiveCallback(_ url: URL) -> Bool {
        guard Self.matchesCallback(url, expected: configuration.callbackURL) else { return false }
        guard pendingCallback != nil else { return true }
        finishCallback(.success(url))
        session?.cancel()
        return true
    }
    private func finishCallback(_ result: Result<URL, any Error>) {
        guard let pendingCallback else { return }
        self.pendingCallback = nil
        pendingCallback.resume(with: result)
    }
    func currentUsername() async throws -> String {
        let data = try await APIClient(configuration: configuration).request("session/current.json", member: true)
        struct Session: Decodable { struct User: Decodable { let username: String }; let currentUser: User }
        return try APIClient(configuration: configuration).decode(Session.self, from: data).currentUser.username
    }
    func signOut() throws { session?.cancel(); session = nil; finishCallback(.failure(RepositoryError.unauthorized)); try KeychainCredentialStore.delete(site: configuration.baseURL.absoluteString) }
    private struct AuthPayload: Decodable { var key: String; var nonce: String }
}
