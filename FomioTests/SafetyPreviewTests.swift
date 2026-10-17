import XCTest
@testable import Fomio

/// Ignored-author previews outside discussions (feeds, search, notifications) and the Arabic safety copy.
@MainActor final class SafetyPreviewTests: XCTestCase {
    private func app(ignored: Set<String>) async -> (AppState, FixtureService) {
        let service = FixtureService(); service.ignoredUsers = ignored
        let app = AppState(service: service, fixture: service, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        await app.loadSafety()
        return (app, service)
    }

    func testPreviewsHideOnlyKnownIgnoredAuthorsAndShowOnceIsPerItem() async {
        let (app, _) = await app(ignored: ["devon"])
        XCTAssertTrue(app.hidesPreview(by: "devon", .topic(.init(4190))))
        XCTAssertFalse(app.hidesPreview(by: "priya", .topic(.init(4201))))
        XCTAssertFalse(app.hidesPreview(by: "", .topic(.init(5003))), "An empty author is never inferred")
        XCTAssertFalse(app.hidesPreview(by: nil, .search(.init(5003), nil)))
        app.revealedPreviews.insert(.topic(.init(4190)))
        XCTAssertFalse(app.hidesPreview(by: "devon", .topic(.init(4190))))
        XCTAssertTrue(app.hidesPreview(by: "devon", .search(.init(4190), .init(14))), "Reveals are per item")
        XCTAssertTrue(app.hidesPreview(by: "devon", .notice(1)))
        XCTAssertTrue(app.isIgnored("devon"), "Show once never changes the preference")
    }

    func testPreviewRevealsResetWithPreferenceChangesAndAccounts() async {
        let (app, service) = await app(ignored: ["devon"])
        app.revealedPreviews = [.notice(1), .topic(.init(4190))]
        service.ignoredUsers = ["devon", "priya"]
        await app.safetyChanged()
        XCTAssertTrue(app.revealedPreviews.isEmpty)
        XCTAssertTrue(app.hidesPreview(by: "priya", .notice(2)))
        app.revealedPreviews = [.notice(1)]
        app.signOut()
        XCTAssertTrue(app.revealedPreviews.isEmpty)
        XCTAssertFalse(app.hidesPreview(by: "devon", .notice(1)), "Guests have no ignore list")
    }

    func testFixtureFeedSearchAndNotificationsCarryTheAuthorsUsedForHiding() async throws {
        let service = FixtureService()
        let feed = try await service.feed(category: nil, page: 0)
        XCTAssertEqual(feed.items.first { $0.id == .init(4190) }?.author, "devon")
        let search = try await service.search("cracked diode", page: 1)
        XCTAssertEqual(search.items.first?.matchAuthor, "devon", "Snippet author is the matched post's author")
        let notices = try await service.notifications(page: 0)
        XCTAssertEqual(notices.items.first { $0.id == 1 }?.actor, "devon")
    }

    /// Every Arabic value keeps the same format arguments as its key, so String(format:) can't misalign or crash.
    func testArabicStringsKeepFormatArgumentsAndCoverSafetyCopy() throws {
        let path = try XCTUnwrap(Bundle(for: AppState.self).path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "ar"))
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        let pattern = try NSRegularExpression(pattern: "%(?:\\d+\\$)?(@|lld|d)")
        func specifiers(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range(at: 1)) }.sorted()
        }
        for (key, value) in table { XCTAssertEqual(specifiers(key), specifiers(value), "Format mismatch for “\(key)”") }
        for key in ["Report reply", "Send report", "Report received", "Ignore user", "Stop ignoring", "Show once", "Safety & Help", "Ignored users",
                    "Why are you reporting this %@?", "Reply by %@ · #%lld · in “%@”", "Preview hidden because you ignore %@", "Notification from someone you ignore", "Match hidden because you ignore %@"] {
            let value = try XCTUnwrap(table[key], "Missing Arabic for “\(key)”")
            XCTAssertNotEqual(value, key)
            XCTAssertNotNil(value.range(of: "\\p{Arabic}", options: .regularExpression), "“\(key)” should be Arabic")
        }
        XCTAssertFalse(table["Discard report"]?.contains("تجاهل") ?? true, "Discard must not reuse the Ignore verb")
        let format = String(format: table["Reply by %@ · #%lld · in “%@”"]!, "devon", 2, "Walnut")
        XCTAssertTrue(format.contains("devon") && format.contains("2") && format.contains("Walnut"))
    }
}
