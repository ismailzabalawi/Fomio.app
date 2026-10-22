import XCTest
import SwiftUI
import UIKit
@testable import Fomio

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var data = Data()
    nonisolated(unsafe) static var captured: URLRequest?
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var ignored = false
    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }; data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.captured = request
        let (status, data) = Self.handler?(request) ?? (Self.status, Self.data)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@MainActor final class ContractTests: XCTestCase {
    func testAuthenticationWithoutPresentingWindowFailsBeforeStartingSession() async {
        let configuration = LiveConfiguration(baseURL: URL(string: "https://test.example")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read")
        let auth = AuthenticationService(configuration: configuration)
        do {
            _ = try await auth.signIn(anchor: nil)
            XCTFail("Authorization needs the caller's window")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalid("No active window is available for sign-in."))
        }
    }
    func testPresentingWindowReaderTracksItsOwnWindowAndDetachment() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        // Neither window becomes key: the reader must follow its own hierarchy.
        let first = UIWindow(windowScene: scene), second = UIWindow(windowScene: scene)
        let reader = PresentingWindowReader.WindowView { _ in }
        let attached = expectation(description: "Reports first hosting window")
        reader.onWindowChange = { if $0 === first { attached.fulfill() } }
        first.addSubview(reader)
        let attachedResult = await XCTWaiter.fulfillment(of: [attached], timeout: 2)
        XCTAssertEqual(attachedResult, .completed)
        let moved = expectation(description: "Reports new hosting window")
        reader.onWindowChange = { if $0 === second { moved.fulfill() } }
        second.addSubview(reader)
        let movedResult = await XCTWaiter.fulfillment(of: [moved], timeout: 2)
        XCTAssertEqual(movedResult, .completed)
        let detached = expectation(description: "Clears the detached window")
        reader.onWindowChange = { if $0 == nil { detached.fulfill() } }
        reader.removeFromSuperview()
        let detachedResult = await XCTWaiter.fulfillment(of: [detached], timeout: 2)
        XCTAssertEqual(detachedResult, .completed)
    }
    func testBundledAuthenticationCallbackIsRegisteredForIncomingURLs() throws {
        let configuration = try XCTUnwrap(LiveConfiguration.fromBundle())
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemes.contains(try XCTUnwrap(configuration.callbackURL.scheme)))
    }
    func testAccountDeletionRechecksCurrentIdentityAndPermission() async throws {
        let (service, _) = try service(#"{"current_user":{"username":"member","can_delete_account":true}}"#, member: true)
        StubURLProtocol.handler = { request in
            if request.httpMethod == "DELETE" {
                XCTAssertEqual(request.url?.path, "/forum/u/member.json")
                XCTAssertEqual(request.value(forHTTPHeaderField: "User-Api-Key"), "fictional-test-key")
                return (200, Data(#"{"success":"OK"}"#.utf8))
            }
            XCTAssertEqual(request.url?.path, "/forum/session/current.json")
            return (200, Data(#"{"current_user":{"username":"member","can_delete_account":true}}"#.utf8))
        }
        try await service.deleteAccount(username: "member")
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "DELETE")
    }
    func testAccountDeletionDoesNotSendForMissingPermissionOrDifferentIdentity() async throws {
        let (service, _) = try service(#"{"current_user":{"username":"member"}}"#, member: true)
        do { try await service.deleteAccount(username: "member"); XCTFail("Expected denial") }
        catch { XCTAssertEqual(error as? RepositoryError, .denied) }
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "GET")
        StubURLProtocol.data = Data(#"{"current_user":{"username":"someone_else","can_delete_account":true}}"#.utf8)
        do { try await service.deleteAccount(username: "member"); XCTFail("Expected identity rejection") }
        catch { XCTAssertEqual(error as? RepositoryError, .unauthorized) }
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "GET")
    }
    func testAccountDeletionRequiresExplicitSuccessAndMemberCredential() async throws {
        let (service, _) = try service("{}", member: true)
        StubURLProtocol.handler = { request in
            (200, Data((request.httpMethod == "DELETE" ? "{}" : #"{"current_user":{"username":"member","can_delete_account":true}}"#).utf8))
        }
        do { try await service.deleteAccount(username: "member"); XCTFail("Malformed success must stay uncertain") }
        catch { XCTAssertEqual(error as? RepositoryError, .unconfirmed) }
        let (guest, _) = try self.service("{}")
        do { try await guest.deleteAccount(username: "member"); XCTFail("Guest must not send") }
        catch { XCTAssertEqual(error as? RepositoryError, .unauthorized) }
        XCTAssertNil(StubURLProtocol.captured)
    }
    private var safetyPost: Post { Post(id: .init(314), number: .init(3), topicID: .init(20), author: "other", body: "Content") }
    func testReportUsesDynamicEnabledFlagsAndFreshPermission() async throws {
        let (service, _) = try service("{}", member: true)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Api-Key"), "fictional-test-key")
            if request.url?.path == "/forum/site.json" {
                return (200, Data(#"{"post_action_types":[{"id":84,"name":"Custom concern","name_key":"custom","short_description":"<b>Details</b>","is_flag":true,"enabled":true,"applies_to":["Post"],"require_message":true},{"id":6,"name":"Message author","name_key":"notify_user","is_flag":true,"enabled":true,"applies_to":["Post"]},{"id":85,"name":"Disabled","name_key":"disabled","is_flag":true,"enabled":false,"applies_to":["Post"]}]}"#.utf8))
            }
            if request.httpMethod == "POST" {
                XCTAssertEqual(request.url?.path, "/forum/post_actions.json")
                let body = try? JSONSerialization.jsonObject(with: StubURLProtocol.body(request)) as? [String: Any]
                XCTAssertEqual(body?["id"] as? Int, 314)
                XCTAssertEqual(body?["post_action_type_id"] as? Int, 84)
                XCTAssertEqual(body?["flag_topic"] as? Bool, false)
                XCTAssertEqual(body?["message"] as? String, "Please review this concern")
                return (200, Data(#"{"id":314,"post_number":3,"actions_summary":[{"id":84,"acted":true}]}"#.utf8))
            }
            return (200, Data(#"{"id":314,"post_number":3,"actions_summary":[{"id":84,"can_act":true},{"id":6,"can_act":true},{"id":85,"can_act":true}]}"#.utf8))
        }
        let reasons = try await service.reportReasons(post: safetyPost)
        XCTAssertEqual(reasons.map(\.id), [84]); XCTAssertEqual(reasons.first?.description, "Details")
        do { try await service.report(post: safetyPost, reason: 84, message: " "); XCTFail("Required message") }
        catch { XCTAssertEqual(error as? RepositoryError, .invalid("Describe why you are reporting this post.")) }
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "GET")
        try await service.report(post: safetyPost, reason: 84, message: "Please review this concern")
    }
    func testReportRejectsUnavailableActionAndAmbiguousResponse() async throws {
        let (service, _) = try service("{}", member: true)
        StubURLProtocol.handler = { request in
            if request.url?.path == "/forum/site.json" { return (200, Data(#"{"post_action_types":[{"id":84,"name":"Concern","name_key":"custom","is_flag":true,"enabled":true,"applies_to":["Post"]}]}"#.utf8)) }
            return (200, Data(#"{"id":314,"post_number":3,"actions_summary":[]}"#.utf8))
        }
        do { try await service.report(post: safetyPost, reason: 84, message: ""); XCTFail("Permission missing") }
        catch { XCTAssertEqual(error as? RepositoryError, .denied) }
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "GET")
        StubURLProtocol.handler = { request in
            if request.httpMethod == "POST" { return (200, Data("{}".utf8)) }
            if request.url?.path == "/forum/site.json" { return (200, Data(#"{"post_action_types":[{"id":84,"name":"Concern","name_key":"custom","is_flag":true,"enabled":true,"applies_to":["Post"]}]}"#.utf8)) }
            return (200, Data(#"{"id":314,"post_number":3,"actions_summary":[{"id":84,"can_act":true}]}"#.utf8))
        }
        do { try await service.report(post: safetyPost, reason: 84, message: ""); XCTFail("Explicit receipt required") }
        catch { XCTAssertEqual(error as? RepositoryError, .unconfirmed) }
    }
    func testBlockingUsesIgnoreForeverAndReadbackThenUnblock() async throws {
        let (service, _) = try service("{}", member: true)
        StubURLProtocol.ignored = false
        StubURLProtocol.handler = { request in
            if request.httpMethod == "PUT" {
                XCTAssertEqual(request.url?.path, "/forum/u/other/notification_level.json")
                let body = try? JSONSerialization.jsonObject(with: StubURLProtocol.body(request)) as? [String: Any]
                StubURLProtocol.ignored = body?["notification_level"] as? String == "ignore"
                if StubURLProtocol.ignored {
                    let expiry = (body?["expiring_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                    XCTAssertGreaterThan(expiry?.timeIntervalSinceNow ?? 0, 900 * 365 * 24 * 60 * 60)
                } else { XCTAssertEqual(body?["notification_level"] as? String, "normal") }
                return (200, Data(#"{"success":"OK"}"#.utf8))
            }
            let ignored = StubURLProtocol.ignored ? #"["other"]"# : "[]"
            return (200, Data("{\"current_user\":{\"username\":\"member\",\"can_ignore_users\":true,\"ignored_users\":\(ignored)}}".utf8))
        }
        let blocked = try await service.setIgnored(username: "other", ignored: true)
        XCTAssertEqual(blocked.ignoredUsers, ["other"])
        let unblocked = try await service.setIgnored(username: "other", ignored: false)
        XCTAssertTrue(unblocked.ignoredUsers.isEmpty)
    }
    func testBlockingDenialAndFailedReadbackDoNotClaimSuccess() async throws {
        let (service, _) = try service(#"{"current_user":{"username":"member","can_ignore_users":false,"ignored_users":[]}}"#, member: true)
        do { _ = try await service.setIgnored(username: "other", ignored: true); XCTFail("Permission missing") }
        catch { XCTAssertEqual(error as? RepositoryError, .denied) }
        XCTAssertEqual(StubURLProtocol.captured?.httpMethod, "GET")
        StubURLProtocol.handler = { request in
            if request.httpMethod == "PUT" { return (200, Data(#"{"success":"OK"}"#.utf8)) }
            return (200, Data(#"{"current_user":{"username":"member","can_ignore_users":true,"ignored_users":[]}}"#.utf8))
        }
        do { _ = try await service.setIgnored(username: "other", ignored: true); XCTFail("Readback did not confirm") }
        catch { XCTAssertEqual(error as? RepositoryError, .unconfirmed) }
    }
    func testBlockingIsAccountScopedAndClearedAtSignOut() async throws {
        let fixture = FixtureService()
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        await app.refreshSafety()
        try await app.changeBlocking("mara_k", blocked: true)
        XCTAssertTrue(app.isBlocked("MARA_K"))
        app.username = "different"; XCTAssertFalse(app.isBlocked("mara_k"))
        app.username = FixtureService.member; app.signOut()
        XCTAssertFalse(app.isBlocked("mara_k")); XCTAssertNil(app.safety)
    }
    private func service(_ json: String, status: Int = 200, member: Bool = false, capabilities: ComposerCapabilities = ComposerCapabilities()) throws -> (DiscourseService, LiveConfiguration) {
        StubURLProtocol.status = status; StubURLProtocol.data = Data(json.utf8); StubURLProtocol.captured = nil; StubURLProtocol.handler = nil
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
    func testCategoryIdentityPreservesAssetsAndVisibleRestrictionIsNotDenial() async throws {
        let (service, _) = try service(#"{"category_list":{"can_create_topic":true,"categories":[{"id":8,"name":"Garden","color":"34805B","text_color":"FFFFFF","style_type":"emoji","emoji":"seedling","read_restricted":true,"permission":1,"description_text":"Full description","description_excerpt":"<p>Short &amp; useful</p>","topic_url":"/t/about/90","uploaded_logo":{"id":4,"url":"/uploads/logo.png","width":80,"height":80},"uploaded_logo_dark":{"url":"https://cdn.example/dark.png"}}]}}"#)
        let categories = try await service.communities()
        let category = try XCTUnwrap(categories.first)
        XCTAssertEqual(category.identity.style, "emoji"); XCTAssertEqual(category.identity.emoji, "seedling")
        XCTAssertEqual(category.identity.logo?.width, 80); XCTAssertEqual(category.identity.darkLogo?.url, "https://cdn.example/dark.png")
        XCTAssertEqual(category.descriptionExcerpt, "Short & useful"); XCTAssertEqual(category.aboutURL, "/t/about/90")
        XCTAssertTrue(category.canCreate); XCTAssertFalse(category.restricted, "A returned secured category is visible; read_restricted isn't viewer denial")
    }
    func testPagedDirectoryLoadsAllRootsAndScopedChildrenWithoutDuplicates() async throws {
        let (service, _) = try service("{}")
        defer { StubURLProtocol.handler = nil }
        StubURLProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            let parent = query.first { $0.name == "parent_category_id" }?.value
            let page = query.first { $0.name == "page" }?.value
            let categories: String
            switch (parent, page) {
            case (nil, "1"): categories = #"[{"id":10,"name":"First","permission":1,"subcategory_ids":[11,12],"subcategory_count":2,"subcategory_list":[{"id":11,"name":"Preview","parent_category_id":10,"permission":1}]}]"#
            case (nil, "2"): categories = #"[{"id":20,"name":"Second","permission":2}]"#
            case ("10", "1"): categories = #"[{"id":11,"name":"Preview","parent_category_id":10,"permission":1},{"id":12,"name":"Remaining","parent_category_id":10,"permission":2}]"#
            default: categories = "[]"
            }
            return (200, Data(("{\"category_list\":{\"can_create_topic\":true,\"categories\":" + categories + "}}").utf8))
        }
        let categories = try await service.communities()
        XCTAssertEqual(categories.map(\.id), [.init(10), .init(11), .init(20), .init(12)])
        XCTAssertTrue(categories[0].canCreate); XCTAssertFalse(categories[2].canCreate); XCTAssertFalse(categories[3].canCreate)
        XCTAssertEqual(categories[3].parentID, .init(10))
    }
    func testDirectoryPageFailureDoesNotPublishPartialCatalog() async throws {
        let (service, _) = try service("{}")
        defer { StubURLProtocol.handler = nil }
        StubURLProtocol.handler = { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value
            return page == "1" ? (200, Data(#"{"category_list":{"categories":[{"id":10,"name":"First"}]}}"#.utf8)) : (403, Data("{}".utf8))
        }
        do { _ = try await service.communities(); XCTFail("Do not silently truncate") }
        catch { XCTAssertEqual(error as? RepositoryError, .denied) }
    }
    func testSiteThemeMapsResolvedTokensAndMissingDarkScheme() async throws {
        let (service, _) = try service(#"{"default_light_color_scheme":{"colors":[{"name":"tertiary","hex":"147A74"},{"name":"primary","hex":"182A2A"}]},"default_dark_color_scheme":null}"#)
        let theme = try await service.siteTheme()
        XCTAssertEqual(theme.light["tertiary"], "147A74"); XCTAssertTrue(theme.dark.isEmpty)
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/site.json")
        XCTAssertNil(Color.hexValue("invalid")); XCTAssertEqual(Color.hexValue("#147A74"), 0x147A74)
    }
    func testSavedDecodesNonemptyWrappedListAndFlatEmptyList() async throws {
        let (service, _) = try service(#"{"user_bookmark_list":{"bookmarks":[{"id":91,"title":"Saved reply","topic_id":4190,"linked_post_number":14}],"more_bookmarks_url":"/u/test/bookmarks.json?page=1"}}"#, member: true)
        let page = try await service.saved(username: "test", page: 0)
        XCTAssertEqual(page.items.first?.id, 91); XCTAssertEqual(page.items.first?.topicID, .init(4190)); XCTAssertEqual(page.items.first?.number, .init(14)); XCTAssertEqual(page.nextPage, 1)
        StubURLProtocol.data = Data(#"{"bookmarks":[]}"#.utf8)
        let empty = try await service.saved(username: "test", page: 1)
        XCTAssertTrue(empty.items.isEmpty); XCTAssertNil(empty.nextPage)
    }
    func testFeedPreservesPinnedActivityAndActualChildCategory() async throws {
        let (service, _) = try service(#"{"topic_list":{"topics":[{"id":80,"title":"Read first","category_id":4,"pinned":true,"bumped_at":"2026-10-01T10:00:00.000Z","reply_count":3}]}}"#)
        let page = try await service.feed(category: FixtureService.sampleCommunities[0], page: 0)
        XCTAssertEqual(page.items.first?.categoryID, .init(4)); XCTAssertTrue(page.items.first?.pinned == true)
        XCTAssertFalse(page.items.first?.activity.isEmpty ?? true)
        XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/c/1/l/latest.json")
    }
    func testNestedPagePreservesEffectiveOrderAndStatus() async throws {
        let (service, _) = try service(#"{"topic":{"id":80,"title":"A discussion","category_id":4,"closed":true,"archived":true,"details":{"can_create_post":true}},"op_post":{"id":8001,"post_number":1,"username":"fixture"},"roots":[],"has_more_roots":false,"page":0,"sort":"new","effective_sort":"old"}"#)
        let page = try await service.discussion(.init(80), page: 0)
        XCTAssertEqual(page.effectiveSort, "old"); XCTAssertTrue(page.closed); XCTAssertTrue(page.archived)
        XCTAssertTrue(page.canReply, "Status labels must not replace the viewer's returned permission")
    }
    func testDeletedPlaceholderInheritsTopicIdentity() throws {
        let client = APIClient(configuration: nil)
        let dto = try client.decode(PostDTO.self, from: Data(#"{"id":104,"post_number":4,"deleted_post_placeholder":true,"cooked":"","direct_reply_count":1}"#.utf8))
        let post = dto.domain(canReply: false, topicID: .init(4190))
        XCTAssertEqual(post.topicID, .init(4190)); XCTAssertTrue(post.deleted); XCTAssertEqual(post.childCount, 1)
    }
    func testSearchUsesPostOrderAndExactTarget() async throws {
        let (service, _) = try service(#"{"posts":[{"id":419014,"topic_id":4190,"post_number":14,"blurb":"Matched reply","username":"devon"}],"topics":[{"id":4190,"title":"Bench PSU","category_id":6,"archetype":"regular"}],"grouped_search_result":{"more_full_page_results":false}}"#)
        let request = try DiscussionSearchRequest(query: "PSU", scope: .all, page: 1, settings: .init(minimumTermLength: 3, locale: "en"), catalog: [])
        let results = try await service.search(request)
        XCTAssertEqual(results.items.first?.id, PostID(419014))
        XCTAssertEqual(results.items.first?.discussion.targetPostNumber, .init(14)); XCTAssertEqual(results.items.first?.discussion.excerpt, "Matched reply")
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

/// Explicitly enabled integration checks. Ordinary test runs make no live requests or writes.
@MainActor final class LiveDiscourseTests: XCTestCase {
    func testConsolidatedCategoryHierarchyAndNativeIdentity() async throws {
        let service = DiscourseService(configuration: try configuration(), credentials: { _ in nil })
        let categories = try await service.communities()
        XCTAssertEqual(categories.filter { $0.parentID == nil }.count, 11)
        XCTAssertEqual(categories.filter { $0.parentID != nil }.count, 9)
        XCTAssertEqual(Set(categories.filter { $0.parentID == .init(4) }.map { $0.id.rawValue }), [11, 42])
        XCTAssertEqual(Set(categories.filter { $0.parentID == .init(45) }.map { $0.id.rawValue }), [10, 12, 43, 55, 54, 48, 47])
        XCTAssertFalse(categories.contains { [34, 49, 50, 51, 52, 53].contains($0.id.rawValue) })
        for category in categories {
            XCTAssertEqual(category.identity.style, "icon", category.name)
            XCTAssertNotNil(Color.hexValue(category.identity.color), category.name)
            let icon = try XCTUnwrap(category.identity.icon, category.name)
            let symbol = try XCTUnwrap(CategoryMark.icons[icon], "Missing native mapping for \(category.name): \(icon)")
            XCTAssertNotNil(UIImage(systemName: symbol), "Unavailable native symbol: \(symbol)")
        }
        XCTAssertEqual(categories.first { $0.id == .init(42) }?.name, "Introductions")
    }
    private func configuration(write: Bool = false) throws -> LiveConfiguration {
        let flag = write ? "FOMIO_LIVE_WRITE_TESTS" : "FOMIO_LIVE_READ_TESTS"
        guard ProcessInfo.processInfo.environment[flag] == "1" else { throw XCTSkip("Live checks require explicit \(flag)=1") }
        return try XCTUnwrap(LiveConfiguration.fromBundle(), "Use the app's supplied site configuration")
    }
    func testAnonymousSiteDirectoryFeedsAndExactTopicContracts() async throws {
        let configuration = try configuration()
        let service = DiscourseService(configuration: configuration, credentials: { _ in nil })
        let theme = try await service.siteTheme()
        XCTAssertNotNil(Color.hexValue(theme.light["primary"])); XCTAssertNotNil(Color.hexValue(theme.light["tertiary"]))
        let categories = try await service.communities()
        XCTAssertFalse(categories.isEmpty); XCTAssertEqual(Set(categories.map(\.id)).count, categories.count)
        XCTAssertTrue(categories.allSatisfy { !$0.canCreate }, "Anonymous category reads must not grant member creation")
        for category in categories where category.parentID != nil { XCTAssertTrue(categories.contains { $0.id == category.parentID }, "Child has visible ancestor") }
        let roots = categories.filter { $0.parentID == nil }
        for category in roots {
            let feed = try await service.feed(category: category, page: 0)
            for item in feed.items {
                let actual = try XCTUnwrap(categories.first { $0.id == item.categoryID })
                XCTAssertTrue(actual.id == category.id || actual.parentID == category.id, "Aggregate feed preserves actual root/child category")
            }
        }
        let feed = try await service.feed(category: nil, page: 0)
        XCTAssertFalse(feed.items.isEmpty)
        if let next = feed.nextPage { let more = try await service.feed(category: nil, page: next); XCTAssertFalse(more.items.isEmpty) }
        for summary in feed.items.prefix(3) {
            let page = try await service.discussion(summary.id, page: 0)
            XCTAssertEqual(page.summary.id, summary.id); XCTAssertEqual(page.opening.topicID, summary.id)
            XCTAssertEqual(page.opening.number, .init(1)); XCTAssertFalse(page.canReply)
            let context = try await service.context(topic: summary.id, number: .init(1), focused: false)
            XCTAssertEqual(context.target.post.number, .init(1)); XCTAssertEqual(context.target.post.topicID, summary.id)
            if let root = page.roots.first {
                let exact = try await service.context(topic: summary.id, number: root.post.number, focused: true)
                XCTAssertEqual(exact.target.post.id, root.post.id)
                _ = try await service.children(topic: summary.id, parent: root.post.number, page: 0, depth: 1)
            }
            if let next = page.nextPage {
                let later = try await service.discussion(summary.id, page: next)
                XCTAssertEqual(later.summary.title, page.summary.title); XCTAssertEqual(later.effectiveSort, page.effectiveSort)
            }
        }
        let results = try await service.search(String(try XCTUnwrap(feed.items.first).title.split(separator: " ").prefix(2).joined(separator: " ")), page: 1)
        for hit in results.items.prefix(2) where hit.targetPostNumber != nil {
            let exact = try await service.context(topic: hit.id, number: try XCTUnwrap(hit.targetPostNumber), focused: true)
            XCTAssertEqual(exact.target.post.topicID, hit.id)
        }
        do { _ = try await service.discussion(.init(Int(Int32.max)), page: 0); XCTFail("Missing topic must not render fixture content") }
        catch { XCTAssertEqual(error as? RepositoryError, .unavailable) }
    }
    func testApprovedTemporaryTopicRepliesSaveAndCleanup() async throws {
        let configuration = try configuration(write: true)
        guard try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString) != nil else { throw XCTSkip("No stored per-user credential; real authorization required before approved writes") }
        let username = try await AuthenticationService(configuration: configuration).currentUsername()
        let service = DiscourseService(configuration: configuration)
        struct Session: Decodable { struct User: Decodable { var admin: Bool?; var moderator: Bool? }; var currentUser: User }
        let session = try await service.api.get(Session.self, "session/current.json")
        // Regular authors cannot delete topics once replies exist. Ensure immediate cleanup is possible.
        guard session.currentUser.admin == true || session.currentUser.moderator == true else { throw XCTSkip("This member cannot immediately clean up a replied-to topic; do not create temporary content") }
        if let value = ProcessInfo.processInfo.environment["FOMIO_PREVIOUS_TEST_TOPIC_ID"], let id = Int(value) {
            // Recovery is restricted to the exact ID recorded by a prior approved test run.
            var page = 0
            repeat {
                let saved = try await service.saved(username: username, page: page)
                for bookmark in saved.items where bookmark.topicID == .init(id) {
                    _ = try await service.api.json("bookmarks/\(bookmark.id).json", method: "DELETE", payload: [:])
                }
                guard let next = saved.nextPage else { break }; page = next
            } while page < 100
        }
        let categories = try await service.communities()
        let category = try XCTUnwrap(categories.first { $0.id == .init(54) && $0.name == "Experiments & Ideas" && $0.parentID == .init(45) }, "Only the user-approved test category is allowed")
        guard category.canCreate else { throw XCTSkip("The current member cannot create in the approved test category") }
        var createdTopic: TopicID?
        var createdBookmark: Int?
        var failure: (any Error)?
        do {
            let draft = Draft(account: .init(rawValue: configuration.baseURL.absoluteString + ":" + username), intent: .newDiscussion,
                              title: "Fomio iOS API verification — 2026-10-06",
                              body: "This is a temporary API verification topic for the native Fomio iOS client. It checks category identity, threaded replies, and readback. It will be removed after testing.", categoryID: category.id)
            guard case let .published(topic, number) = try await service.publish(draft) else { throw RepositoryError.invalid("Test publication was not confirmed. Do not retry automatically.") }
            createdTopic = topic
            let link = configuration.topicURL(topic, number: nil)
            let attachment = XCTAttachment(string: "Temporary test topic: " + link.absoluteString); attachment.lifetime = .keepAlways; add(attachment)
            let page = try await service.discussion(topic, page: 0)
            XCTAssertEqual(number, .init(1)); XCTAssertEqual(page.summary.categoryID, category.id)
            XCTAssertEqual(page.opening.author, username); XCTAssertTrue(page.canReply); XCTAssertFalse(page.opening.canLike)
            guard page.opening.author == username else { throw RepositoryError.denied }
            let reply = Draft(account: draft.account, intent: .reply(topic: topic, parent: .init(1)), body: "API verification reply one — checking the exact topic and opening-post target.")
            guard case let .published(replyTopic, replyNumber) = try await service.publish(reply) else { throw RepositoryError.invalid("First test reply was not confirmed. Do not retry.") }
            XCTAssertEqual(replyTopic, topic)
            let first = try await service.context(topic: topic, number: replyNumber, focused: true)
            XCTAssertEqual(first.target.post.author, username); XCTAssertEqual(first.target.post.number, replyNumber)
            let quote = QuoteExcerpt(author: username, number: replyNumber, text: first.target.post.body)
            let nested = Draft(account: draft.account, intent: .reply(topic: topic, parent: replyNumber), body: "API verification reply two — checking a nested reply and attributed quote.", quote: quote)
            guard case let .published(nestedTopic, nestedNumber) = try await service.publish(nested) else { throw RepositoryError.invalid("Nested test reply was not confirmed. Do not retry.") }
            XCTAssertEqual(nestedTopic, topic)
            let second = try await service.context(topic: topic, number: nestedNumber, focused: false)
            XCTAssertEqual(second.target.post.parent, replyNumber); XCTAssertEqual(second.target.post.author, username)
            XCTAssertTrue(second.ancestors.contains { $0.number == replyNumber })
            let children = try await service.children(topic: topic, parent: replyNumber, page: 0, depth: 1)
            XCTAssertTrue(children.nodes.contains { $0.post.number == nestedNumber })
            let saved = try await service.bookmark(page.opening)
            let bookmark = try XCTUnwrap(saved.bookmarkID)
            createdBookmark = bookmark
            let savedItems = try await service.saved(username: username, page: 0)
            XCTAssertTrue(savedItems.items.contains { $0.id == bookmark && $0.topicID == topic })
            let removed = try await service.bookmark(saved); XCTAssertNil(removed.bookmarkID)
            createdBookmark = nil
        } catch { failure = error }
        if let bookmark = createdBookmark { _ = try await service.api.json("bookmarks/\(bookmark).json", method: "DELETE", payload: [:]) }
        if let topic = createdTopic {
            // Delete only the exact topic returned from this test, never a title/search match.
            _ = try await service.api.json("t/\(topic.rawValue).json", method: "DELETE", payload: [:])
            let guest = DiscourseService(configuration: configuration, credentials: { _ in nil })
            do { _ = try await guest.discussion(topic, page: 0); XCTFail("Temporary topic must be unavailable to guests after cleanup") }
            catch { XCTAssertEqual(error as? RepositoryError, .unavailable) }
        }
        if let failure { throw failure }
    }
    func testStoredMemberReadPermissionsSavedAndNotifications() async throws {
        let configuration = try configuration()
        guard try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString) != nil else { throw XCTSkip("No stored per-user credential; real authorization required") }
        let username = try await AuthenticationService(configuration: configuration).currentUsername()
        let service = DiscourseService(configuration: configuration)
        let categories = try await service.communities()
        XCTAssertFalse(categories.isEmpty)
        _ = try await service.siteTheme()
        _ = try await service.profile(username)
        _ = try await service.saved(username: username, page: 0)
        _ = try await service.notifications(page: 0)
        let latest = try await service.feed(category: nil, page: 0)
        let safety = try await service.safetySession()
        XCTAssertEqual(safety.username.lowercased(), username.lowercased())
        XCTAssertTrue(safety.canIgnoreUsers, "Configured member groups allow server Ignore")
        var foundReportOptions = false
        for topic in latest.items.prefix(3) {
            let discussion = try await service.discussion(topic.id, page: 0)
            guard discussion.opening.author.caseInsensitiveCompare(username) != .orderedSame else { continue }
            let reasons = try await service.reportReasons(post: discussion.opening)
            foundReportOptions = foundReportOptions || !reasons.isEmpty
            XCTAssertEqual(Set(reasons.map(\.id)).count, reasons.count)
        }
        XCTAssertTrue(foundReportOptions, "Member has at least one current report option on recent public content")
        _ = try await service.canDeleteAccount(username: username)
        if let values = ProcessInfo.processInfo.environment["FOMIO_CLEANUP_TOPIC_IDS"] {
            let ids = Set(values.split(separator: ",").compactMap { Int($0) }.map { TopicID($0) })
            var page = 0
            while true {
                let saved = try await service.saved(username: username, page: page)
                XCTAssertTrue(saved.items.allSatisfy { !ids.contains($0.topicID) }, "No bookmark for approved test content remains")
                guard let next = saved.nextPage else { break }
                guard next < 100 else { throw RepositoryError.invalid("Cleanup readback exceeded its page limit") }; page = next
            }
            let guest = DiscourseService(configuration: configuration, credentials: { _ in nil })
            for id in ids {
                do { _ = try await guest.discussion(id, page: 0); XCTFail("Approved test topic remains visible") }
                catch { XCTAssertEqual(error as? RepositoryError, .unavailable) }
            }
        }
    }
}

@MainActor final class IndependentWindowTests: XCTestCase {
    private func windows() -> AppWindows {
        let fixture = FixtureService()
        let store = DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        return AppWindows(service: fixture, fixture: fixture, configuration: nil, store: store)
    }
    func testWindowsKeepIndependentNavigationSearchAndComposer() throws {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        first.selectScope(.category(CategoryID(45)))
        first.tabs[.home]?.discussionSearch.query = "walnut"
        first.navigate(.discussion(TopicID(14), nil))
        first.selectedTab = .communities
        first.openComposer(category: nil)
        XCTAssertEqual(second.selectedTab, .home)
        XCTAssertEqual(second.tabs[.home]?.browseScope, .all)
        XCTAssertEqual(second.tabs[.home]?.discussionSearch.query, "")
        XCTAssertEqual(second.tabs[.home]?.path, [])
        XCTAssertNil(second.composer)
        XCTAssertFalse(first.tabs[.home] === second.tabs[.home])
    }
    func testDraftHasOneEditorAndResumesLatestSavedWriting() throws {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        first.openComposer(category: nil)
        let editor = try XCTUnwrap(first.composer)
        editor.draft.body = "First version"; XCTAssertTrue(editor.save())
        let stale = editor.draft
        second.resume(stale)
        XCTAssertNil(second.composer); XCTAssertNotNil(second.banner)
        XCTAssertThrowsError(try second.discardDraft(stale))
        editor.draft.body = "Latest writing"; editor.keepDraft()
        second.resume(stale)
        XCTAssertEqual(second.composer?.draft.body, "Latest writing")
        XCTAssertEqual(first.draftsRevision, second.draftsRevision)
    }
    func testNewActionCannotReplaceAnOpenOrAuthenticationSuspendedDraft() throws {
        let windows = windows(), state = windows.makeWindow()
        state.openComposer(category: nil)
        let editor = try XCTUnwrap(state.composer)
        editor.draft.body = "Writing to retain"
        state.openComposer(category: nil)
        XCTAssertTrue(state.composer === editor)
        XCTAssertEqual(state.composer?.draft.body, "Writing to retain")
        state.reserveForAuthentication(editor); state.composer = nil
        state.openComposer(category: nil)
        XCTAssertNil(state.composer); XCTAssertEqual(state.ownedDraftID, editor.id)
        state.cancelAuthenticationIntent(); state.openComposer(category: nil)
        XCTAssertNotNil(state.composer); XCTAssertNotEqual(state.composer?.id, editor.id)
    }
    func testRetainedInactiveEditorDoesNotUseAReleasedWindow() async throws {
        let windows = windows()
        var window: AppState? = windows.makeWindow()
        window?.openComposer(category: nil)
        let editor = try XCTUnwrap(window?.composer)
        window?.closeWindow(); window = nil
        // A queued button task can outlive its disconnected scene. The editor's
        // unowned AppState must never be touched after deactivation.
        await editor.submit()
        editor.draft.submission = .unconfirmed
        await editor.checkAgain()
        XCTAssertFalse(editor.checking)
    }
    func testClosingWindowSavesWritingAndReleasesDraftOwnership() throws {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        first.openComposer(category: nil)
        let editor = try XCTUnwrap(first.composer)
        editor.draft.body = "Writing before window closes"
        first.closeWindow()
        XCTAssertNil(first.composer)
        second.resume(editor.draft)
        XCTAssertEqual(second.composer?.draft.body, "Writing before window closes")
        XCTAssertFalse(editor.save())
    }
    func testAuthenticationSuspensionRetainsDraftOwnership() throws {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        first.openComposer(category: nil)
        let editor = try XCTUnwrap(first.composer)
        editor.draft.body = "Private draft"; XCTAssertTrue(editor.save())
        first.reserveForAuthentication(editor); first.composer = nil
        second.resume(editor.draft)
        XCTAssertNil(second.composer)
        first.cancelAuthenticationIntent()
        second.resume(editor.draft)
        XCTAssertEqual(second.composer?.id, editor.id)
    }
    func testReauthenticationUpdatesEveryWindowSearchIdentity() async {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        let firstViewer = first.searchViewer, secondViewer = second.searchViewer
        await first.signIn()
        XCTAssertEqual(first.account, .fixture); XCTAssertEqual(second.account, .fixture)
        XCTAssertNotEqual(first.searchViewer, firstViewer)
        XCTAssertNotEqual(second.searchViewer, secondViewer)
    }
    func testExpiredAuthenticationIsSharedWithExistingAndNewWindows() {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        second.openComposer(category: nil)
        first.authenticationExpired()
        XCTAssertNil(second.username); XCTAssertTrue(second.composer?.expired == true)
        XCTAssertNil(windows.makeWindow().username)
    }
    func testSignOutClosesAllEditorsAndPreventsAutosaveResurrection() async throws {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        second.openComposer(category: nil)
        let editor = try XCTUnwrap(second.composer)
        editor.draft.body = "Private writing"; XCTAssertTrue(editor.save()); editor.changed()
        second.navigate(.discussion(TopicID(14), nil)); second.pendingAction = {}
        first.signOut()
        XCTAssertEqual(second.account, .guest); XCTAssertNil(second.username)
        XCTAssertNil(second.composer); XCTAssertNil(second.pendingAction)
        XCTAssertEqual(second.tabs[.home]?.path, [])
        XCTAssertFalse(editor.save())
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertTrue(try windows.store.list(account: .fixture).isEmpty)
        XCTAssertEqual(windows.makeWindow().account, .guest)
    }
    func testSignInSynchronizesIdentityWithoutExecutingOtherWindowIntent() async {
        let windows = windows(), first = windows.makeWindow(), second = windows.makeWindow()
        first.signOut()
        var firstRuns = 0, secondRuns = 0
        first.pendingAction = { firstRuns += 1 }; second.pendingAction = { secondRuns += 1 }
        second.authRequested = true
        await first.signIn()
        XCTAssertEqual(firstRuns, 1); XCTAssertEqual(secondRuns, 0)
        XCTAssertEqual(second.account, .fixture); XCTAssertEqual(second.username, AppState.fixtureMember)
        XCTAssertNil(second.pendingAction); XCTAssertFalse(second.authRequested)
    }
    func testNewWindowCleanupProtectsUnsavedAttachmentInAnotherWindow() throws {
        let windows = windows(), first = windows.makeWindow()
        first.openComposer(category: nil)
        let editor = try XCTUnwrap(first.composer)
        var attachment = ComposerAttachment(status: .retained)
        let bytes = Data([1, 2, 3, 4])
        attachment.localFileName = try windows.store.retain(bytes, draft: editor.draft, attachment: attachment.id)
        editor.draft.attachments.append(attachment)
        let second = windows.makeWindow()
        try second.reconcileDraftFiles()
        XCTAssertEqual(try windows.store.photo(draft: editor.draft, attachment: attachment), bytes)
    }
}
