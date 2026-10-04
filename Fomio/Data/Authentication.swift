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
        let base64 = bytes.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let pem = "-----BEGIN RSA PUBLIC KEY-----\n\(base64)\n-----END RSA PUBLIC KEY-----"
        let query = ["application_name": "Fomio", "client_id": clientID, "nonce": nonce, "public_key": pem, "scopes": configuration.scopes, "auth_redirect": configuration.callbackURL.absoluteString, "padding": "oaep"].map { URLQueryItem(name: $0.key, value: $0.value) }
        let authorizationURL = configuration.url("user-api-key/new", query: query)
        let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
            session = ASWebAuthenticationSession(url: authorizationURL, callbackURLScheme: configuration.callbackURL.scheme) { url, error in
                if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? RepositoryError.unauthorized) }
            }
            session?.presentationContextProvider = self
            if session?.start() != true { session = nil; continuation.resume(throwing: RepositoryError.invalid("Could not open authorization.")) }
        }
        session = nil
        guard callback.scheme == configuration.callbackURL.scheme, callback.host == configuration.callbackURL.host, callback.path == configuration.callbackURL.path,
              let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let encrypted = components.queryItems?.first(where: { $0.name == "payload" })?.value.flatMap({ Data(base64Encoded: $0) }),
              let clear = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA1, encrypted as CFData, &keyError) as Data? else { throw RepositoryError.invalid("Authorization callback was invalid.") }
        let payload = try JSONDecoder().decode(AuthPayload.self, from: clear)
        guard payload.nonce == nonce, !payload.key.isEmpty else { throw RepositoryError.invalid("Authorization callback did not match this attempt.") }
        let credential = Credential(key: payload.key, clientID: clientID, site: configuration.baseURL.absoluteString)
        try KeychainCredentialStore.save(credential)
        do { return try await currentUsername() }
        catch { try? KeychainCredentialStore.delete(site: credential.site); throw error }
    }
    func currentUsername() async throws -> String {
        let data = try await APIClient(configuration: configuration).request("session/current.json", member: true)
        struct Session: Decodable { struct User: Decodable { let username: String }; let currentUser: User }
        return try APIClient(configuration: configuration).decode(Session.self, from: data).currentUser.username
    }
    func signOut() throws { session?.cancel(); session = nil; try KeychainCredentialStore.delete(site: configuration.baseURL.absoluteString) }
    private struct AuthPayload: Decodable { var key: String; var nonce: String }
}
