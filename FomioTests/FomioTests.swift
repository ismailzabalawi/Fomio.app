import XCTest
@testable import Fomio

@MainActor final class FomioTests: XCTestCase {
    private func setup() async throws -> (AppState, FixtureService, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = FixtureService()
        let app = AppState(service: service, fixture: service, configuration: nil, store: DraftStore(directory: directory))
        await app.loadCommunities()
        return (app, service, directory)
    }
    func testDraftSurvivesNewStoreAndIsIsolated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftStore(directory: directory)
        let draft = Draft(account: .fixture, intent: .newDiscussion, title: "Walnut finish", body: "Text survives", categoryID: .init(2), missingPhoto: true)
        try store.save(draft)
        let recovered = try DraftStore(directory: directory).list(account: .fixture)
        XCTAssertTrue(recovered.first?.body.hasPrefix(draft.body) == true); XCTAssertEqual(recovered.first?.categoryID, .init(2)); XCTAssertEqual(recovered.first?.activeAttachments.first?.status, .missing)
        XCTAssertTrue(try store.list(account: .guest).isEmpty)
    }
    func testSubmittingRecordRecoversAsUnconfirmed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftStore(directory: directory)
        let draft = Draft(account: .fixture, intent: .reply(topic: .init(4182), parent: .init(2)), body: "Will it reach?", submission: .submitting)
        try store.save(draft)
        XCTAssertEqual(try store.list(account: .fixture).first?.submission, .unconfirmed)
    }
    func testDraftSaveFailureIsTruthfulAndPreventsSubmission() async throws {
        let (app, _, directory) = try await setup()
        try Data("not a directory".utf8).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = ComposerState(draft: Draft(account: .fixture, intent: .newDiscussion, title: "Title", body: "Body", categoryID: .init(2)), app: app, origin: .home)
        await state.submit()
        XCTAssertEqual(state.draft.submission, .editing)
        XCTAssertEqual(state.saveStatus, "Couldn’t save on this device")
    }
    func testUnfinishedPhotoKeepAndResume() async throws {
        let (app, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        service.uploadFails = true
        let state = ComposerState(draft: Draft(account: .fixture, intent: .newDiscussion, title: "Photo", body: "Writing", categoryID: .init(2)), app: app, origin: .communities)
        state.addPhoto(Data([1, 2, 3])); XCTAssertFalse(state.canPost)
        state.keepDraft()
        let recovered = try XCTUnwrap(app.draftStore.list(account: .fixture).first)
        XCTAssertFalse(recovered.missingPhoto); XCTAssertTrue(recovered.body.hasPrefix("Writing")); XCTAssertEqual(recovered.attachments.count, 1)
        XCTAssertEqual(try app.draftStore.photo(draft: recovered, attachment: recovered.attachments[0]), Data([1, 2, 3]))
        let resumed = ComposerState(draft: recovered, app: app, origin: .me)
        XCTAssertFalse(resumed.canPost); resumed.removePhoto(); XCTAssertTrue(resumed.canPost)
    }
    func testMultiplePhotosUploadInDocumentOrderAndRemovalCannotRestore() async throws {
        let (app, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        service.uploadStep = .milliseconds(10)
        let state = ComposerState(draft: Draft(account: .fixture, intent: .newDiscussion, title: "Photos", body: "Middle", categoryID: .init(2)), app: app, origin: .home)
        state.addPhoto(Data([1])); state.addPhoto(Data([2]), at: NSRange(location: 0, length: 0))
        XCTAssertFalse(state.canPost)
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(state.canPost); XCTAssertEqual(state.draft.activeAttachments.count, 2)
        XCTAssertEqual(state.draft.activeAttachments.map(\.id), state.draft.attachments.reversed().map(\.id))
        for attachment in state.draft.activeAttachments { XCTAssertEqual(state.draft.body.components(separatedBy: attachment.reference).count, 2) }
        state.addPhoto(Data([3])); let removed = try XCTUnwrap(state.draft.activeAttachments.last)
        state.removePhoto(removed.id)
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(state.draft.body.contains(removed.localReference)); XCTAssertEqual(state.draft.activeAttachments.count, 2)
    }
    func testUnconfirmedNeverAutomaticallyRetries() async throws {
        let (app, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        service.scenario = .unconfirmed
        let state = ComposerState(draft: Draft(account: .fixture, intent: .newDiscussion, title: "Title", body: "Body", categoryID: .init(2)), app: app, origin: .home)
        await state.submit(); XCTAssertEqual(state.draft.submission, .unconfirmed); XCTAssertFalse(state.canPost)
        await state.checkAgain(); XCTAssertEqual(state.draft.submission, .unconfirmed)
        await state.submit(); XCTAssertTrue(service.submitted.isEmpty)
        state.allowManualRetry(); XCTAssertTrue(state.canPost)
        service.scenario = .published; await state.postAgain(); XCTAssertEqual(service.submitted.count, 1)
    }
    func testPendingRecordRemainsLocked() async throws {
        let (app, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        service.scenario = .pending
        let state = ComposerState(draft: Draft(account: .fixture, intent: .newDiscussion, title: "Title", body: "Body", categoryID: .init(2)), app: app, origin: .home)
        await state.submit(); XCTAssertEqual(state.draft.submission, .pending); XCTAssertFalse(state.canPost)
        XCTAssertEqual(try app.draftStore.list(account: .fixture).first?.submission, .pending)
        XCTAssertNil(app.composer); XCTAssertEqual(app.pendingNotice?.tab, .home); XCTAssertEqual(app.pendingNotice?.isReply, false)
    }
    func testPublishedClearsDraftAndReturnsToOrigin() async throws {
        let (app, _, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        let state = ComposerState(draft: Draft(account: .fixture, intent: .reply(topic: .init(4182), parent: .init(2)), body: "New reply"), app: app, origin: .communities)
        await state.submit(); XCTAssertTrue(try app.draftStore.list(account: .fixture).isEmpty)
        XCTAssertEqual(app.selectedTab, .communities)
        XCTAssertEqual(app.tabs[.communities]?.path.last, .discussion(.init(4182), .init(6)))
        XCTAssertEqual(app.tabs[.communities]?.focus[.discussion(.init(4182), .init(6))], .published)
    }
    func testGuestAuthRestoresComposerWithoutPosting() async throws {
        let (app, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        app.signOut()
        let post = try await service.discussion(.init(4182), page: 0).opening
        app.reply(to: post, quote: true)
        XCTAssertTrue(app.authRequested); XCTAssertNil(app.composer)
        await app.signIn()
        XCTAssertNotNil(app.composer); XCTAssertTrue(service.submitted.isEmpty)
        XCTAssertNil(app.composer?.draft.quote); XCTAssertTrue(app.composer?.draft.body.contains("[quote=") == true)
        XCTAssertTrue(app.composer?.draft.composedBody.hasPrefix("[quote=\"mara_k, post:1, topic:4182\"]") == true)
    }
    func testSignOutRemovesOnlyCurrentAccountDrafts() async throws {
        let (app, _, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        var member = Draft(account: .fixture, intent: .newDiscussion, body: "Member")
        var photo = ComposerAttachment(); photo.localFileName = try app.draftStore.retain(Data([1]), draft: member, attachment: photo.id)
        member.attachments = [photo]; member.body += photo.markup
        try app.draftStore.save(member)
        try app.draftStore.save(Draft(account: .guest, intent: .newDiscussion, body: "Guest"))
        app.signOut()
        XCTAssertTrue(try app.draftStore.list(account: .fixture).isEmpty)
        XCTAssertThrowsError(try app.draftStore.photo(draft: member, attachment: photo))
        XCTAssertEqual(try app.draftStore.list(account: .guest).count, 1)
    }
    func testMissingAndCorruptRetainedPhotosKeepWritingAndBlockPosting() async throws {
        let (app, _, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        for corrupt in [false, true] {
            var draft = Draft(account: .fixture, intent: .reply(topic: .init(4182), parent: nil), body: "Keep my writing")
            var photo = ComposerAttachment()
            if corrupt { photo.localFileName = try app.draftStore.retain(Data([0, 1, 2]), draft: draft, attachment: photo.id) }
            draft.attachments = [photo]; draft.body += "\n" + photo.markup
            let state = ComposerState(draft: draft, app: app, origin: .home, resumed: true)
            XCTAssertEqual(state.draft.attachments.first?.status, .missing)
            XCTAssertTrue(state.draft.body.contains("Keep my writing")); XCTAssertFalse(state.canPost)
        }
    }
    func testThreadExpansionPaginationAndExactContext() async throws {
        let (_, service, directory) = try await setup(); defer { try? FileManager.default.removeItem(at: directory) }
        let state = DiscussionState(route: .discussion(.init(4190), nil), service: service)
        await state.load(); XCTAssertEqual(state.roots.count, 3)
        let root = try XCTUnwrap(state.roots.first)
        await state.toggle(root, depth: 0); XCTAssertEqual(state.children[root]?.count, 1)
        await state.moreRoots(); XCTAssertEqual(state.roots.count, 6)
        await state.toggle(root, depth: 0); XCTAssertFalse(state.expanded.contains(root)); XCTAssertEqual(state.children[root]?.count, 1)
        let exact = DiscussionState(route: .discussion(.init(4190), .init(5)), service: service)
        await exact.load(); XCTAssertEqual(exact.nodes[try XCTUnwrap(exact.highlight)]?.number, .init(5)); XCTAssertEqual(exact.expanded.count, 2); XCTAssertTrue(exact.truncated)
    }
    func testNestedCapabilityIsRequired() async throws {
        let service = FixtureService(); service.nestedEnabled = false
        do { _ = try await service.discussion(.init(4190), page: 0); XCTFail("Expected unsupported") }
        catch { XCTAssertEqual(error as? RepositoryError, .unsupported) }
    }
    func testSearchStartsAtFirstPage() async throws {
        let service = FixtureService()
        let result = try await service.search("walnut", page: 1)
        XCTAssertEqual(result.items.first?.id, .init(4182))
    }
    func testLogicalLinksRespectSiteRootAndPostNumber() {
        let base = URL(string: "https://community.example/forum")!
        XCTAssertEqual(LinkRouter.route(URL(string: "https://community.example/forum/t/old-slug/4190/14")!, baseURL: base), .discussion(.init(4190), .init(14)))
        XCTAssertEqual(LinkRouter.route(URL(string: "https://community.example/forum/n/new-slug/4190/context/14")!, baseURL: base), .discussion(.init(4190), .init(14)))
        XCTAssertNil(LinkRouter.route(URL(string: "https://other.example/forum/t/4190/14")!, baseURL: base))
        XCTAssertNil(LinkRouter.route(URL(string: "https://community.example/t/4190/14")!, baseURL: base))
    }
    func testRelativeAPIURLPreservesRoot() {
        let configuration = LiveConfiguration(baseURL: URL(string: "https://community.example/forum")!, callbackURL: URL(string: "fixture://callback")!, scopes: "read")
        XCTAssertEqual(configuration.url("latest.json", query: [.init(name: "page", value: "2")]).absoluteString, "https://community.example/forum/latest.json?page=2")
    }
    func testNestedDTOOptionalMetadataAndPermissions() throws {
        let json = Data(#"{"roots":[{"id":912,"post_number":14,"topic_id":4190,"username":"devon","cooked":"<p>Reply</p>","direct_reply_count":2,"actions_summary":[{"id":2,"count":4}],"children":[]}],"has_more_roots":false,"page":1}"#.utf8)
        let client = APIClient(configuration: nil)
        let dto = try client.decode(RootsDTO.self, from: json)
        XCTAssertNil(dto.topic); XCTAssertEqual(dto.roots.first?.domain(canReply: false).id, .init(912))
        XCTAssertFalse(try XCTUnwrap(dto.roots.first).domain(canReply: false).canLike)
    }
}
