import XCTest
@testable import Fomio

/// Topic card adapter and presentation rules. Responses are fictional, shaped like `ListableTopicSerializer`.
@MainActor final class TopicCardTests: XCTestCase {
    private func feed(_ topics: String, users: String = "[]") async throws -> [DiscussionSummary] {
        StubURLProtocol.status = 200; StubURLProtocol.handler = nil
        StubURLProtocol.data = Data(#"{"users":\#(users),"topic_list":{"topics":[\#(topics)]}}"#.utf8)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let site = LiveConfiguration(baseURL: URL(string: "https://forum.test-\(UUID().uuidString).example/sub")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read")
        let service = DiscourseService(configuration: site, session: URLSession(configuration: config), credentials: { _ in nil })
        return try await service.feed(category: nil, page: 0).items
    }

    func testImageURLAcceptsPublicHTTPSAndResolvesRelativeOnly() async throws {
        let items = try await feed("""
        {"id":1,"title":"A","image_url":"https://cdn.example/optimized/1X/a_1024x768.jpeg"},
        {"id":2,"title":"B","image_url":"/uploads/default/original/1X/b.png"},
        {"id":3,"title":"C","image_url":"http://insecure.example/c.png"},
        {"id":4,"title":"D","image_url":null},
        {"id":5,"title":"E","image_url":"https://user:secret@cdn.example/e.png"},
        {"id":6,"title":"F","image_url":"//cdn.example/f.png"},
        {"id":7,"title":"G"}
        """)
        XCTAssertEqual(items.map(\.imageURL?.absoluteString), [
            "https://cdn.example/optimized/1X/a_1024x768.jpeg",
            items[1].imageURL?.absoluteString, nil, nil, nil, "https://cdn.example/f.png", nil
        ])
        // Discourse upload paths already include any subfolder, so a root-relative path resolves against the host.
        XCTAssertTrue(items[1].imageURL?.absoluteString.hasSuffix(".example/uploads/default/original/1X/b.png") == true)
        XCTAssertEqual(items[1].imageURL?.scheme, "https")
        XCTAssertTrue(items.allSatisfy { $0.image == nil }, "Live topics never use bundled fixture photos")
    }

    func testOriginalPosterIsAuthorNotLastPosterAndZeroRepliesKept() async throws {
        let items = try await feed("""
        {"id":9,"title":"Fresh","reply_count":0,"posts_count":1,"last_poster_username":"latest_person","bumped_at":"2026-10-01T10:00:00.000Z","posters":[{"user_id":20,"description":"Most Recent Poster"},{"user_id":10,"description":"Original Poster, Most Recent Poster"}]},
        {"id":10,"title":"No posters","reply_count":2,"last_poster_username":"someone"}
        """, users: #"[{"id":10,"username":"original_author"},{"id":20,"username":"latest_person"}]"#)
        XCTAssertEqual(items[0].author, "original_author")
        XCTAssertEqual(items[0].replyCount, 0)
        XCTAssertEqual(items[1].author, "", "Absent author is omitted rather than substituted with the last poster")
        XCTAssertEqual(items[1].activity, "")
    }

    func testUnicodeTitleIsPreferredOnlyWhenSent() async throws {
        let items = try await feed(#"{"id":5,"title":"Welcome to Fomio! :wave:","unicode_title":"Welcome to Fomio! 👋"},{"id":6,"title":"Plain :not-an-emoji"}"#)
        XCTAssertEqual(items.map(\.title), ["Welcome to Fomio! 👋", "Plain :not-an-emoji"])
    }

    func testMetadataTextLabelsActivityAndZeroReplies() {
        XCTAssertEqual(feedRepliesText(0), "No replies yet")
        XCTAssertEqual(feedRepliesText(1), "1 reply")
        XCTAssertEqual(feedRepliesText(14), "14 replies")
        XCTAssertEqual(ActiveAge.text("3h"), "Active 3h ago")
        XCTAssertEqual(ActiveAge.text("now"), "Active now")
        XCTAssertNil(ActiveAge.text(""))
        XCTAssertEqual(ActiveAge.spoken("1d"), "active 1 day ago")
        XCTAssertEqual(ActiveAge.spoken("40m"), "active 40 minutes ago")
    }

    func testCommunityTextKeepsItsOwnDirection() {
        XCTAssertEqual("ما أفضل طريقة".naturalDirection, .rightToLeft)
        XCTAssertEqual("2026: ما أفضل".naturalDirection, .rightToLeft)
        XCTAssertEqual("Walnut desk".naturalDirection, .leftToRight)
        XCTAssertEqual("".naturalDirection, .leftToRight)
    }

    func testFeedGeometryPlacesPartlyHiddenAnchorThroughNextTopic() {
        let geometry = FeedGeometry()
        geometry.viewport = .init(top: 0, height: 600)
        geometry.frames = [TopicID(1): CGRect(x: 0, y: -50, width: 400, height: 200), TopicID(2): CGRect(x: 0, y: 150, width: 400, height: 150)]
        let anchor = geometry.topAnchor(in: [1, 2].map { DiscussionSummary(id: .init($0), title: "", slug: "", categoryID: .init(1), excerpt: "", author: "", replyCount: 0, activity: "") })
        XCTAssertEqual(anchor?.id, TopicID(1)); XCTAssertEqual(anchor?.offset, -50)
        // New layout after scrolling topic 1 to the top: it is now 300 tall.
        geometry.frames = [TopicID(1): CGRect(x: 0, y: 0, width: 400, height: 300), TopicID(2): CGRect(x: 0, y: 300, width: 400, height: 150)]
        let placement = geometry.placement(for: anchor!, next: TopicID(2))
        XCTAssertEqual(placement?.0, TopicID(2))
        // Same quarter hidden: topic 1 at -75, so topic 2 at 225 = y * (600 - 150).
        XCTAssertEqual(placement?.1.y ?? 0, 225.0 / 450.0, accuracy: 0.0001)
    }
}
