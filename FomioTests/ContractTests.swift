import XCTest
@testable import Fomio

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var data = Data()
    nonisolated(unsafe) static var captured: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.captured = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@MainActor final class ContractTests: XCTestCase {
    private func service(_ json: String, status: Int = 200, member: Bool = false, capabilities: ComposerCapabilities = ComposerCapabilities()) throws -> (DiscourseService, LiveConfiguration) {
        StubURLProtocol.status = status; StubURLProtocol.data = Data(json.utf8); StubURLProtocol.captured = nil
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let site = LiveConfiguration(baseURL: URL(string: "https://test-\(UUID().uuidString).example/forum")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read,write,session_info")
        let credential = member ? Credential(key: "fictional-test-key", clientID: "fictional-client", site: site.baseURL.absoluteString) : nil
        return (DiscourseService(configuration: site, session: URLSession(configuration: config), credentials: { _ in credential }, composerCapabilities: capabilities), site)
    }
    func testPreviewAdaptersUseMemberHeadersAndKeepEmptySimilarResults() async throws {
        let (service, _) = try service("[]", member: true, capabilities: .fixture)
        let results = try await service.similarDiscussions(title: "مرحبا title", raw: "Writing")
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/topics/similar_to.json")
        XCTAssertEqual(StubURLProtocol.captured?.value(forHTTPHeaderField: "User-Api-Key"), "fictional-test-key")
        StubURLProtocol.data = Data("<h3>Title</h3><p>Summary</p><script>bad()</script>".utf8)
        let preview = try await service.oneboxPreview(url: URL(string: "https://example.org")!, context: OneboxContext(category: .init(2), topic: .init(42)))
        XCTAssertEqual(preview?.title, "Title"); XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/onebox.json")
        StubURLProtocol.status = 429
        do { _ = try await service.oneboxPreview(url: URL(string: "https://example.org")!, context: OneboxContext()); XCTFail("Expected rate limit") } catch { XCTAssertEqual(error as? RepositoryError, .rateLimited) }
    }
    func testUnknownPreviewCapabilityMakesNoRequest() async throws {
        let (service, _) = try service("{}", member: true)
        do { _ = try await service.similarDiscussions(title: "Title", raw: "Body"); XCTFail("Must stay gated") } catch { XCTAssertEqual(error as? RepositoryError, .unsupported) }
        XCTAssertNil(StubURLProtocol.captured)
    }
    func testKeychainRoundTripAndRemoval() throws {
        let site = "test-" + UUID().uuidString
        let credential = Credential(key: "fictional-key", clientID: "fictional-client", site: site)
        defer { try? KeychainCredentialStore.delete(site: site) }
        try KeychainCredentialStore.save(credential)
        XCTAssertEqual(try KeychainCredentialStore.read(site: site)?.key, "fictional-key")
        try KeychainCredentialStore.delete(site: site)
        XCTAssertNil(try KeychainCredentialStore.read(site: site))
    }
    func testCategoryDecoderFlattensPermittedChildren() async throws {
        let (service, _) = try service(#"{"category_list":{"can_create_topic":true,"categories":[{"id":1,"name":"Woodworking","permission":1,"subcategory_list":[{"id":2,"name":"Finishing","parent_category_id":1,"permission":2}]}]}}"#)
        let categories = try await service.communities()
        XCTAssertEqual(categories.map(\.id), [.init(1), .init(2)])
        XCTAssertTrue(categories[0].canCreate); XCTAssertFalse(categories[1].canCreate)
        XCTAssertEqual(categories[1].parentID, .init(1))
    }
    func testDeletedPlaceholderInheritsTopicIdentity() throws {
        let client = APIClient(configuration: nil)
        let dto = try client.decode(PostDTO.self, from: Data(#"{"id":104,"post_number":4,"deleted_post_placeholder":true,"cooked":"","direct_reply_count":1}"#.utf8))
        let post = dto.domain(canReply: false, topicID: .init(4190))
        XCTAssertEqual(post.topicID, .init(4190)); XCTAssertTrue(post.deleted); XCTAssertEqual(post.childCount, 1)
    }
    func testSearchUsesPostOrderAndExactTarget() async throws {
        let (service, _) = try service(#"{"posts":[{"topic_id":4190,"post_number":14,"blurb":"Matched reply","username":"devon"}],"topics":[{"id":4190,"title":"Bench PSU","category_id":6}],"grouped_search_result":{"more_full_page_results":false}}"#)
        let results = try await service.search("PSU", page: 1)
        XCTAssertEqual(results.items.first?.targetPostNumber, .init(14)); XCTAssertEqual(results.items.first?.excerpt, "Matched reply")
    }
    func testPostingQueueIsSeparateFromPublication() async throws {
        let (service, _) = try service(#"{"success":true,"action":"enqueued","pending_count":1}"#, member: true)
        let result = try await service.publish(Draft(account: .fixture, intent: .newDiscussion, title: "Title", body: "Body", categoryID: .init(2)))
        guard case .pending = result else { return XCTFail("Queue must not look published") }
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/posts.json")
        XCTAssertEqual(StubURLProtocol.captured?.value(forHTTPHeaderField: "User-Api-Client-Id"), "fictional-client")
        XCTAssertNil(StubURLProtocol.captured?.value(forHTTPHeaderField: "Api-Key"))
    }
    func testMalformedSuccessfulPostingStaysUnconfirmed() async throws {
        let (service, _) = try service("{}", member: true)
        let result = try await service.publish(Draft(account: .fixture, intent: .reply(topic: .init(4190), parent: .init(14)), body: "Body"))
        guard case .unconfirmed = result else { return XCTFail("Malformed write must remain uncertain") }
    }
    func test401PreservesAuthorizationMeaning() async throws {
        let (service, _) = try service("{}", status: 401)
        do { _ = try await service.feed(category: nil, page: 0); XCTFail("Expected unauthorized") }
        catch { XCTAssertEqual(error as? RepositoryError, .unauthorized) }
    }
    func test429IsNotAnEmptyFeed() async throws {
        let (service, _) = try service("{}", status: 429)
        do { _ = try await service.feed(category: nil, page: 0); XCTFail("Expected rate limit") }
        catch { XCTAssertEqual(error as? RepositoryError, .rateLimited) }
    }
    func testNativeContentKeepsQuotesCodeImagesAndUnsupportedNotice() {
        let blocks = HTMLContent.blocks("<p>Hello <strong>world</strong></p><blockquote>Quoted</blockquote><pre><code>if x &lt; 3</code></pre><img src=\"/uploads/photo.jpg\" alt=\"Bench\"><table><tr><td>Unsupported table</td></tr></table>")
        XCTAssertEqual(blocks, [.text("Hello **world**"), .quote("Quoted"), .code("if x < 3"), .image("/uploads/photo.jpg", "Bench"), .table([["Unsupported table"]])])
    }
    func testEmojiImagesStayInlineWithText() {
        // Shape observed in cooked posts on the deployed site, 2026-10-04.
        let blocks = HTMLContent.blocks("<p>use the <img src=\"https://example.invalid/images/emoji/apple/heart.png?v=15\" title=\":heart:\" class=\"emoji\" alt=\":heart:\" loading=\"lazy\" width=\"20\" height=\"20\"> to show support</p><img src=\"/uploads/photo.jpg\" alt=\"Bench\">")
        XCTAssertEqual(blocks, [.text("use the :heart: to show support"), .image("/uploads/photo.jpg", "Bench")])
    }
    /// Decodes a query the way Rack does for Rails params: "+" means space, then percent-decoding.
    private func railsQuery(_ url: URL) -> [String: String] {
        let pairs = (url.query(percentEncoded: true) ?? "").split(separator: "&").map { $0.split(separator: "=", maxSplits: 1).map(String.init) }
        return Dictionary(uniqueKeysWithValues: pairs.map { ($0[0], ($0.count > 1 ? $0[1] : "").replacingOccurrences(of: "+", with: " ").removingPercentEncoding!) })
    }
    func testUserAPIKeyAuthorizationPublicKeySurvivesRailsQueryDecoding() throws {
        // Live 2026-10-04: a literal "+" in public_key became a space server-side, OpenSSL rejected it and
        // /user-api-key/new rendered generic_error; the %2B form passed validation (302 to /login).
        let site = LiveConfiguration(baseURL: URL(string: "https://test.example/forum")!, callbackURL: URL(string: "testfixture://auth_redirect")!, scopes: "read,write,notifications,session_info")
        var keyError: Unmanaged<CFError>?
        var pkcs1 = Data()
        for _ in 0..<20 where !AuthenticationService.publicKeyPEM(pkcs1).contains("+") {
            let privateKey = try XCTUnwrap(SecKeyCreateRandomKey([kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048] as CFDictionary, &keyError))
            pkcs1 = try XCTUnwrap(SecKeyCopyExternalRepresentation(try XCTUnwrap(SecKeyCopyPublicKey(privateKey)), &keyError) as Data?)
        }
        let pem = AuthenticationService.publicKeyPEM(pkcs1)
        XCTAssertTrue(pem.contains("+"), "Regression needs a key whose base64 contains '+'.")
        let url = AuthenticationService.authorizationURL(configuration: site, clientID: "client+id", nonce: "nonce/=", publicKeyPEM: pem)
        XCTAssertEqual(url.path(), "/forum/user-api-key/new")
        let params = railsQuery(url)
        XCTAssertEqual(params["public_key"], pem)
        XCTAssertEqual(params["client_id"], "client+id")
        XCTAssertEqual(params["nonce"], "nonce/=")
        XCTAssertEqual(params["scopes"], "read,write,notifications,session_info")
        XCTAssertEqual(params["auth_redirect"], "testfixture://auth_redirect")
        XCTAssertEqual(params["padding"], "oaep")
        // The server-side value must still be a parsable RSA public key.
        let body = try XCTUnwrap(params["public_key"]).split(separator: "\n").filter { !$0.hasPrefix("-----") }.joined()
        let attributes = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic] as CFDictionary
        XCTAssertNotNil(SecKeyCreateWithData(try XCTUnwrap(Data(base64Encoded: body)) as CFData, attributes, &keyError))
    }
    func testSearchTermPlusIsNotDecodedAsSpace() {
        let site = LiveConfiguration(baseURL: URL(string: "https://test.example")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read")
        XCTAssertEqual(railsQuery(site.url("search.json", query: [URLQueryItem(name: "q", value: "C++ a b")]))["q"], "C++ a b")
    }
    func testAuthorizationFallbackAcceptsOnlyConfiguredCallbackDestination() {
        let expected = URL(string: "fomio://auth_redirect")!
        XCTAssertTrue(AuthenticationService.matchesCallback(URL(string: "fomio://auth_redirect?payload=fictional")!, expected: expected))
        XCTAssertFalse(AuthenticationService.matchesCallback(URL(string: "fomio://other?payload=fictional")!, expected: expected))
        XCTAssertFalse(AuthenticationService.matchesCallback(URL(string: "https://meta.fomio.app/auth_redirect?payload=fictional")!, expected: expected))
    }
    func testDiscourseWrappedCallbackPayloadCanBeDecrypted() throws {
        var keyError: Unmanaged<CFError>?
        let privateKey = try XCTUnwrap(SecKeyCreateRandomKey([kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048] as CFDictionary, &keyError))
        let publicKey = try XCTUnwrap(SecKeyCopyPublicKey(privateKey))
        let clear = Data(#"{"key":"fictional-user-key","nonce":"fictional-nonce","push":false,"api":1}"#.utf8)
        let ciphertext = try XCTUnwrap(SecKeyCreateEncryptedData(publicKey, .rsaEncryptionOAEPSHA1, clear as CFData, &keyError) as Data?)
        let wrapped = ciphertext.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        XCTAssertTrue(wrapped.contains("\n"))
        XCTAssertNil(Data(base64Encoded: wrapped), "Foundation's default rejects Discourse's Base64 line breaks.")
        var components = URLComponents(string: "fomio://auth_redirect")!
        components.queryItems = [URLQueryItem(name: "payload", value: wrapped)]
        let decoded = try XCTUnwrap(AuthenticationService.encryptedPayload(from: try XCTUnwrap(components.url)))
        XCTAssertEqual(decoded, ciphertext)
        XCTAssertEqual(SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA1, decoded as CFData, &keyError) as Data?, clear)
        components.queryItems = [URLQueryItem(name: "payload", value: wrapped + "!")]
        XCTAssertNil(AuthenticationService.encryptedPayload(from: try XCTUnwrap(components.url)))
    }
}
