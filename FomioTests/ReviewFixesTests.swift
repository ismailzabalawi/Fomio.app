import XCTest
import UIKit
@testable import Fomio

/// Regressions for the 2026-10-15 independent review of 6162c57 (retained errors, UIKit direction, media recovery).
@MainActor final class ReviewFixesTests: XCTestCase {
    private var arabic: LocalizationCatalog {
        get throws { try CatalogValidator.validate(LocalizationTests.data("ar"), requested: "ar", reference: Localizer.shared.english) }
    }
    override func tearDown() async throws {
        // Leave the host app's shared catalog and UIKit direction as they were.
        Localizer.shared.activate(Localizer.shared.english)
    }

    // MARK: 1. Retained app-authored errors follow the interface language

    func testRetainedFeedErrorResolvesInTheActiveLanguageWithoutRefetch() async throws {
        let fixture = FixtureService(); fixture.failFirstFeed = true
        let feed = FeedState()
        await feed.load(service: fixture, category: nil)
        XCTAssertEqual(feed.error, .key("error.offline"))
        XCTAssertEqual(feed.error?.text, "You’re offline. Your writing is kept on this device.")
        Localizer.shared.activate(try arabic)
        XCTAssertEqual(feed.error?.text, "أنت غير متصل. كتابتك محفوظة على هذا الجهاز.", "the same retained error renders in Arabic")
        XCTAssertEqual(fixture.feedRequests, 1, "a language change does not refetch")
        Localizer.shared.activate(Localizer.shared.english)
        XCTAssertEqual(feed.error?.text, "You’re offline. Your writing is kept on this device.")
    }

    func testServerAndSystemMessagesStayVerbatimAndArgumentsAreKept() throws {
        let server = DisplayError(RepositoryError.invalid("Title is too short (minimum is 15 characters)"))
        let status = DisplayError(RepositoryError.server(503))
        let system = DisplayError(CocoaError(.fileWriteOutOfSpace))
        Localizer.shared.activate(try arabic)
        XCTAssertEqual(server.text, "Title is too short (minimum is 15 characters)", "Discourse text is never translated by the app")
        XCTAssertEqual(status.text, "تعذر على المجتمع إكمال الطلب (503).")
        XCTAssertEqual(system, .verbatim(CocoaError(.fileWriteOutOfSpace).localizedDescription))
    }

    func testRetainedErrorsInDraftsAndAppStateStaySemantic() async throws {
        // Upload failures are stored in protected draft JSON; they must stay semantic and still read older drafts.
        var attachment = ComposerAttachment(status: .failed(.key("error.offline")))
        let data = try JSONEncoder().encode(attachment)
        attachment = try JSONDecoder().decode(ComposerAttachment.self, from: data)
        XCTAssertEqual(attachment.status, .failed(.key("error.offline")))
        let legacy = Data(#"{"failed":{"_0":"Photo upload failed. Retry or remove it."}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ComposerAttachment.Status.self, from: legacy), .failed(.verbatim("Photo upload failed. Retry or remove it.")))

        let fixture = FixtureService(); fixture.offline = true
        let app = AppState(service: fixture, fixture: fixture, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        await app.loadCommunities()
        XCTAssertEqual(app.communityError, .key("error.offline"))
        let discussion = DiscussionState(route: .discussion(.init(4190), nil), service: fixture)
        await discussion.load()
        XCTAssertEqual(discussion.error, .key("error.offline"))
    }

    // MARK: 2. Explicit UIKit direction, including the initial English fallback

    func testSharedLocalizerSetsExplicitUIKitDirectionForEveryActivation() throws {
        let appearance = UIView.appearance()
        appearance.semanticContentAttribute = .unspecified
        // The initial English fallback equals the stored catalog and still sets the direction.
        Localizer.shared.activate(Localizer.shared.english)
        XCTAssertEqual(appearance.semanticContentAttribute, .forceLeftToRight, "never unspecified, which follows an RTL system language")
        Localizer.shared.activate(try arabic)
        XCTAssertEqual(appearance.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(Localizer.shared.uikitAttribute, .forceRightToLeft)
        Localizer.shared.activate(Localizer.shared.english)
        XCTAssertEqual(appearance.semanticContentAttribute, .forceLeftToRight)
        // Test-local localizers never touch UIKit's global direction.
        Localizer(english: Localizer.shared.english).activate(try arabic)
        XCTAssertEqual(appearance.semanticContentAttribute, .forceLeftToRight)
    }

    // MARK: 3. Topic media recovers on a replacement source or an explicit refresh

    func testMediaLoadStateRetriesOnlyDeliberatelyAndKeepsRecoveredIdentity() {
        let a = TopicMedia.Source.remote(URL(string: "https://cdn.example/a.jpg")!)
        let b = TopicMedia.Source.remote(URL(string: "https://cdn.example/b.jpg")!)
        var state = MediaLoadState()
        XCTAssertEqual(state.identity(a), "https://cdn.example/a.jpg")
        state.fail(a, generation: 0)
        XCTAssertTrue(state.isHidden(a), "failed source falls back to text")
        state.refreshed(to: 0, current: a)
        XCTAssertTrue(state.isHidden(a), "no retry without a new explicit refresh — no loop")
        state.refreshed(to: 1, current: a)
        XCTAssertFalse(state.isHidden(a)); let retried = state.identity(a)
        XCTAssertEqual(retried, "https://cdn.example/a.jpg#attempt-1", "a deliberate retry is a new load attempt")
        // The retry succeeded (no further fail). Later refreshes keep the same attempt: no reload.
        state.refreshed(to: 2, current: a); state.refreshed(to: 3, current: a)
        XCTAssertEqual(state.identity(a), retried)
        // A retry that fails again hides the source until the next refresh, then retries once more.
        state.fail(a, generation: 3); XCTAssertTrue(state.isHidden(a))
        state.refreshed(to: 4, current: a); XCTAssertEqual(state.identity(a), "https://cdn.example/a.jpg#attempt-2")
        // A replacement source loads immediately with its own identity; it is not hidden by A's history.
        state.fail(a, generation: 4)
        XCTAssertFalse(state.isHidden(b)); XCTAssertEqual(state.identity(b), "https://cdn.example/b.jpg")
        state.refreshed(to: 5, current: b)
        XCTAssertEqual(state.identity(b), "https://cdn.example/b.jpg", "a refresh never reloads a source that has not failed")
    }

    func testBackIndicatorOverridesOnlyMismatchedDirections() {
        XCTAssertNil(Localizer.backIndicatorSymbol(interface: .ltr, systemRightToLeft: false), "English on English iOS keeps the system chevron")
        XCTAssertNil(Localizer.backIndicatorSymbol(interface: .rtl, systemRightToLeft: true), "Arabic on Arabic iOS keeps the system chevron")
        XCTAssertEqual(Localizer.backIndicatorSymbol(interface: .ltr, systemRightToLeft: true), "chevron.right", "UIKit mirrors it into a left chevron")
        XCTAssertEqual(Localizer.backIndicatorSymbol(interface: .rtl, systemRightToLeft: false), "chevron.right")
    }


    func testRefreshGenerationAdvancesOnlyOnSuccessfulExplicitRefresh() async {
        let fixture = FixtureService()
        let feed = FeedState()
        await feed.load(service: fixture, category: nil)
        XCTAssertEqual(feed.refreshGeneration, 0, "first load")
        await feed.load(service: fixture, category: nil)
        XCTAssertEqual(feed.refreshGeneration, 0, "load more")
        await feed.load(service: fixture, category: nil, refresh: true)
        XCTAssertEqual(feed.refreshGeneration, 1)
        fixture.offline = true
        await feed.load(service: fixture, category: nil, refresh: true)
        XCTAssertEqual(feed.refreshGeneration, 1, "a failed refresh keeps the current media state")
        XCTAssertFalse(feed.items.isEmpty, "loaded topics are kept when a refresh fails")
    }

    func testFixtureMediaRecoveryRestoresFileAndReplacesURLOnRefresh() async throws {
        let fixture = FixtureService()
        let photo = try XCTUnwrap(Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"))
        fixture.enableMediaRecovery(photo: photo)
        let first = try await fixture.feed(category: nil, page: 0).items
        let restored = try XCTUnwrap(first.first { $0.id == .init(5006) }?.imageURL)
        let original = try XCTUnwrap(first.first { $0.id == .init(5007) }?.imageURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FixtureMediaURLProtocol.file(for: restored).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: FixtureMediaURLProtocol.file(for: original).path))
        let second = try await fixture.feed(category: nil, page: 0).items
        XCTAssertEqual(second.first { $0.id == .init(5006) }?.imageURL, restored, "same source")
        XCTAssertTrue(FileManager.default.fileExists(atPath: FixtureMediaURLProtocol.file(for: restored).path), "now available")
        let replacement = try XCTUnwrap(second.first { $0.id == .init(5007) }?.imageURL)
        XCTAssertNotEqual(replacement, original); XCTAssertTrue(FileManager.default.fileExists(atPath: FixtureMediaURLProtocol.file(for: replacement).path))
    }

}
