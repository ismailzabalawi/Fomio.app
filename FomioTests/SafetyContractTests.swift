import XCTest
@testable import Fomio

/// Reporting & Safety adapter contracts recorded in docs/discourse-api-reference.md (2026-10-17, deployed revision 28529a6d).
@MainActor final class SafetyContractTests: XCTestCase {
    private var requests: [URLRequest] = []
    private func service(member: Bool = true, routes: @escaping @Sendable (URLRequest) -> (Int, String)) -> DiscourseService {
        StubURLProtocol.captured = nil
        let box = RequestBox()
        StubURLProtocol.handler = { request in
            box.append(request)
            let (status, body) = routes(request)
            return (status, Data(body.utf8))
        }
        self.box = box
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let site = LiveConfiguration(baseURL: URL(string: "https://test-\(UUID().uuidString).example/forum")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read,write,notifications,session_info")
        let credential = member ? Credential(key: "fictional-test-key", clientID: "fictional-client", site: site.baseURL.absoluteString) : nil
        return DiscourseService(configuration: site, session: URLSession(configuration: config), credentials: { _ in credential })
    }
    private var box = RequestBox()
    override func tearDown() { StubURLProtocol.handler = nil; super.tearDown() }
    private func body(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
    /// Deployed `site.json` shape (2026-10-17): notify_user is flag-typed but messages the author.
    nonisolated static let site = #"""
    {"post_action_types":[
      {"id":6,"name_key":"notify_user","name":"Send @%{username} a message","description":"Talk to them","is_flag":true,"enabled":true,"require_message":true,"applies_to":["Post","Chat::Message"]},
      {"id":3,"name_key":"off_topic","name":"Off-Topic","description":"Not <b>relevant</b>","is_flag":true,"enabled":true,"require_message":false,"applies_to":["Post","Chat::Message"]},
      {"id":4,"name_key":"inappropriate","name":"Inappropriate","description":"Violates <a href=\"/guidelines\">our community guidelines</a>","is_flag":true,"enabled":true,"require_message":false,"applies_to":["Post","Topic"]},
      {"id":8,"name_key":"spam","name":"Spam","description":"Advertising","is_flag":true,"enabled":true,"require_message":false,"applies_to":["Post","Topic"]},
      {"id":9,"name_key":"custom_disabled","name":"Disabled","description":"x","is_flag":true,"enabled":false,"require_message":false,"applies_to":["Post"]},
      {"id":7,"name_key":"notify_moderators","name":"Something Else","description":"Staff attention","is_flag":true,"enabled":true,"require_message":true,"applies_to":["Post","Topic"]},
      {"id":2,"name_key":"like","name":"Like","is_flag":false,"enabled":true,"applies_to":["Post"]}],
     "topic_flag_types":[
      {"id":4,"name_key":"inappropriate","name":"Inappropriate","description":"Topic violates guidelines","is_flag":true,"enabled":true,"require_message":false,"applies_to":["Post","Topic"]},
      {"id":7,"name_key":"notify_moderators","name":"Something Else","description":"","short_description":"Requires staff attention","is_flag":true,"enabled":true,"require_message":true,"applies_to":["Post","Topic"]}],
     "tos_url":"/tos","privacy_policy_url":"/privacy"}
    """#
    nonisolated static func post(id: Int = 12, number: Int = 2, actions: String) -> String {
        #"{"id":\#(id),"post_number":\#(number),"topic_id":44,"username":"devon","cooked":"<p>Two thin coats, buff off the excess.</p>","actions_summary":[\#(actions)]}"#
    }

    func testReportReasonsFollowServerCatalogAndFreshPermissions() async throws {
        let service = service { request in
            switch request.url!.lastPathComponent {
            case "site.json": (200, Self.site)
            case "12.json": (200, Self.post(actions: #"{"id":2,"count":1,"can_act":true},{"id":6,"can_act":true},{"id":3,"can_act":true},{"id":8,"can_act":true},{"id":7,"can_act":true},{"id":9,"can_act":true}"#))
            default: (404, "{}")
            }
        }
        let context = try await service.reportContext(.post(.init(12), topic: .init(44), number: .init(2), author: "devon"))
        XCTAssertEqual(context.reasons.map(\.id), [3, 8, 7], "Server order; notify_user, disabled and non-permitted (4) reasons excluded")
        XCTAssertEqual(context.reasons.first?.description, "Not relevant", "Descriptions are sanitized text")
        XCTAssertEqual(context.reasons.last?.requiresMessage, true)
        XCTAssertFalse(context.alreadyReported)
        XCTAssertEqual(context.excerpt, "Two thin coats, buff off the excess.")
        let fetch = box.all.first { $0.url!.path.hasSuffix("/posts/12.json") }
        XCTAssertEqual(fetch?.value(forHTTPHeaderField: "User-Api-Key"), "fictional-test-key", "Fresh target recheck uses the member key")
    }

    func testAnyActedFlagMeansAlreadyReportedAndTopicUsesTopicCatalog() async throws {
        let service = service { request in
            switch request.url!.lastPathComponent {
            case "site.json": (200, Self.site)
            case "5.json": (200, Self.post(id: 5, number: 1, actions: #"{"id":8,"acted":true},{"id":4,"can_act":true},{"id":7,"can_act":true}"#))
            default: (404, "{}")
            }
        }
        let context = try await service.reportContext(.discussion(.init(44), opening: .init(5), author: "mara_k"))
        XCTAssertTrue(context.alreadyReported)
        XCTAssertEqual(context.reasons.map(\.id), [4, 7])
        XCTAssertEqual(context.reasons.last?.description, "Requires staff attention", "Empty topic description falls back to the short description")
    }

    func testReportPayloadsUseExactTargetsAndNoStaffControls() async throws {
        let service = service { _ in (200, Self.post(actions: "")) }
        let reason = ReportReason(id: 7, name: "Something Else", description: "", requiresMessage: true)
        let outcome = try await service.submitReport(.post(.init(12), topic: .init(44), number: .init(2), author: "devon"), reason: reason, message: "Selling links in every thread.")
        XCTAssertEqual(outcome, .received)
        let post = try XCTUnwrap(box.all.last)
        XCTAssertEqual(post.httpMethod, "POST"); XCTAssertEqual(post.url?.path, "/forum/post_actions.json")
        let payload = body(post)
        XCTAssertEqual(payload["id"] as? Int, 12); XCTAssertEqual(payload["post_action_type_id"] as? Int, 7)
        XCTAssertEqual(payload["message"] as? String, "Selling links in every thread.")
        for staffOnly in ["take_action", "is_warning", "queue_for_review", "flag_topic"] { XCTAssertNil(payload[staffOnly], staffOnly) }

        _ = try await service.submitReport(.discussion(.init(44), opening: .init(5), author: "mara_k"), reason: reason, message: nil)
        let topic = body(try XCTUnwrap(box.all.last))
        XCTAssertEqual(topic["id"] as? Int, 44, "Discussion reports send the topic ID")
        XCTAssertEqual(topic["flag_topic"] as? String, "true")
        XCTAssertNil(topic["message"])
    }

    func testReportOutcomeMappingNeverTurnsUnknownIntoRetryableError() async throws {
        let reason = ReportReason(id: 3, name: "Off-Topic", description: "", requiresMessage: false)
        let target = ReportTarget.post(.init(12), topic: .init(44), number: .init(2), author: "devon")
        for (status, body, expected) in [(200, "{\"unexpected\":true}", ReportSubmission.unconfirmed), (500, "{}", .unconfirmed), (502, "", .unconfirmed)] {
            let service = service { _ in (status, body) }
            let result = try await service.submitReport(target, reason: reason, message: nil)
            XCTAssertEqual(result, expected, "\(status)")
        }
        for (status, expected) in [(403, RepositoryError.denied), (404, .unavailable), (429, .rateLimited), (401, .unauthorized)] {
            let service = service { _ in (status, #"{"errors":["text"]}"#) }
            do { _ = try await service.submitReport(target, reason: reason, message: nil); XCTFail("\(status) must throw") }
            catch { XCTAssertEqual(error as? RepositoryError, expected, "\(status)") }
        }
        let service422 = service { _ in (422, #"{"errors":["This post has already been reviewed."]}"#) }
        do { _ = try await service422.submitReport(target, reason: reason, message: nil); XCTFail() } catch { XCTAssertEqual(error as? RepositoryError, .invalid("This post has already been reviewed.")) }
    }

    func testReportStatusReadsActedFlagFromFreshPost() async throws {
        let target = ReportTarget.post(.init(12), topic: .init(44), number: .init(2), author: "devon")
        var service = self.service { request in request.url!.lastPathComponent == "site.json" ? (200, Self.site) : (200, Self.post(actions: #"{"id":3,"acted":true}"#)) }
        let received = try await service.reportStatus(target)
        XCTAssertEqual(received, .received)
        service = self.service { request in request.url!.lastPathComponent == "site.json" ? (200, Self.site) : (200, Self.post(actions: #"{"id":2,"acted":true},{"id":3,"can_act":true}"#)) }
        let missing = try await service.reportStatus(target)
        XCTAssertEqual(missing, .notReceived, "A like is not a report")
    }

    func testIgnoreWritesSelfServicePreferenceWithForeverExpiry() async throws {
        let service = service { _ in (200, #"{"success":"OK"}"#) }
        let forever = IgnoreDuration.forever.expiry()
        XCTAssertGreaterThan(Calendar(identifier: .gregorian).component(.year, from: forever), Calendar(identifier: .gregorian).component(.year, from: Date()) + 998)
        let result = try await service.ignore("devon", until: forever)
        XCTAssertEqual(result, .confirmed)
        let request = try XCTUnwrap(box.all.last)
        XCTAssertEqual(request.httpMethod, "PUT"); XCTAssertEqual(request.url?.path, "/forum/u/devon/notification_level.json")
        let payload = body(request)
        XCTAssertEqual(payload["notification_level"] as? String, "ignore")
        XCTAssertNotNil(ISO8601DateFormatter().date(from: payload["expiring_at"] as? String ?? ""))
        XCTAssertNil(payload["acting_user_id"], "Never act on behalf of another account")

        _ = try await service.stopIgnoring("devon")
        XCTAssertEqual(body(try XCTUnwrap(box.all.last))["notification_level"] as? String, "normal")
    }

    func testIgnoreDenialIs422AndServerFailureIsUncertain() async throws {
        let denied = service { _ in (422, #"{"errors":["Sorry, you can't ignore that user."]}"#) }
        do { _ = try await denied.ignore("moderator.kit", until: Date()); XCTFail() } catch { XCTAssertEqual(error as? RepositoryError, .invalid("Sorry, you can't ignore that user.")) }
        let failing = service { _ in (502, "") }
        let outcome = try await failing.ignore("devon", until: Date())
        XCTAssertEqual(outcome, .unconfirmed)
    }

    func testAccountAndMemberSafetyDecoding() async throws {
        let service = service { request in
            switch request.url!.path {
            case let path where path.hasSuffix("session/current.json"): (200, #"{"current_user":{"username":"jonah.w","can_ignore_users":true,"ignored_users":["devon","rowan.b"]}}"#)
            default: (200, #"{"user":{"username":"kit.a","ignored":false,"can_ignore_user":false,"moderator":true}}"#)
            }
        }
        let account = try await service.accountSafety()
        XCTAssertEqual(account, AccountSafety(canIgnoreUsers: true, ignored: ["devon", "rowan.b"]))
        let member = try await service.memberSafety("kit.a")
        XCTAssertEqual(member, MemberSafety(username: "kit.a", ignored: false, canIgnore: false, staff: true))
        XCTAssertTrue(box.all.contains { $0.url!.path.hasSuffix("/u/kit.a/card.json") })
    }

    func testSafetyResourcesOnlyUseServerValues() async throws {
        let service = service { request in
            request.url!.lastPathComponent == "about.json" ? (200, #"{"about":{"contact_email":"help@test.example","contact_url":"not-a-url@test.example"}}"#) : (200, Self.site)
        }
        let resources = try await service.safetyResources()
        XCTAssertEqual(resources.terms?.scheme, "https"); XCTAssertTrue(resources.terms?.path.hasSuffix("/tos") == true)
        XCTAssertTrue(resources.privacy?.path.hasSuffix("/privacy") == true)
        XCTAssertEqual(resources.contactEmail, "help@test.example")
        let empty = self.service { request in request.url!.lastPathComponent == "about.json" ? (200, #"{"about":{"contact_email":"   "}}"#) : (200, "{}") }
        let none = try await empty.safetyResources()
        XCTAssertNil(none.contactEmail); XCTAssertNil(none.terms)
    }

    func testAttributedQuotesKeepAuthorForIgnoreProjection() {
        let html = #"<aside class="quote no-group" data-username="devon" data-post="2" data-topic="44"><div class="title"><div class="quote-controls"></div><img src="/a.png"> devon:</div><blockquote><p>Buy my kit</p></blockquote></aside><aside class="onebox"><p>Link card</p></aside>"#
        let blocks = HTMLContent.blocks(html)
        XCTAssertEqual(blocks.first, .attributedQuote(author: "devon", text: "Buy my kit"))
        XCTAssertEqual(blocks.last, .quote("Link card"))
    }

    func testNestedPayloadDecodesTopicFlagPermissionAndFlags() throws {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let topic = try decoder.decode(TopicDTO.self, from: Data(#"{"id":44,"title":"T","details":{"can_create_post":true,"can_flag_topic":true}}"#.utf8))
        XCTAssertEqual(topic.details?.canFlagTopic, true)
        let ignored = try decoder.decode(PostDTO.self, from: Data(#"{"id":12,"post_number":2,"ignored_post_placeholder":true,"cooked":"","actions_summary":[]}"#.utf8)).domain(canReply: true)
        XCTAssertTrue(ignored.ignored); XCTAssertTrue(ignored.flags.isEmpty, "Ignored replies carry no actions; Report rechecks the post")
    }
}

final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    func append(_ request: URLRequest) { lock.lock(); items.append(request); lock.unlock() }
    var all: [URLRequest] { lock.lock(); defer { lock.unlock() }; return items }
}
