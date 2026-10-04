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
    private func service(_ json: String, status: Int = 200, member: Bool = false) throws -> (DiscourseService, LiveConfiguration) {
        StubURLProtocol.status = status; StubURLProtocol.data = Data(json.utf8); StubURLProtocol.captured = nil
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let site = LiveConfiguration(baseURL: URL(string: "https://test-\(UUID().uuidString).example/forum")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read,write,session_info")
        let credential = member ? Credential(key: "fictional-test-key", clientID: "fictional-client", site: site.baseURL.absoluteString) : nil
        return (DiscourseService(configuration: site, session: URLSession(configuration: config), credentials: { _ in credential }), site)
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
        XCTAssertEqual(blocks, [.text("Hello **world**"), .quote("Quoted"), .code("if x < 3"), .image("/uploads/photo.jpg", "Bench"), .unsupported])
    }
}
