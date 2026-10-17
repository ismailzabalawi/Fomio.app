import XCTest
@testable import Fomio

/// Report/Ignore state rules from the approved design and recorded contracts. Fixture outcomes only.
@MainActor final class SafetyStateTests: XCTestCase {
    private let reply = ReportTarget.post(PostID(418202), topic: TopicID(4182), number: .init(2), author: "devon")
    private func fixture() -> FixtureService { let value = FixtureService(); value.reportDelay = .milliseconds(20); return value }
    private func app(_ service: FixtureService) -> AppState {
        AppState(service: service, fixture: service, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

    func testSendNeedsReasonAndRequiredDetailsWithoutRequest() async {
        let service = fixture()
        let state = ReportState(target: reply, title: "Walnut", account: .fixture, service: service)
        await state.load(isOffline: false)
        XCTAssertEqual(state.phase, .form); XCTAssertFalse(state.canSend)
        state.select(7)
        await state.send(isOffline: false)
        XCTAssertTrue(state.detailsMissing, "Server accepts empty require_message flags, so the client enforces details")
        XCTAssertTrue(service.reportedPosts.isEmpty)
        state.details = "Selling links in every thread."
        await state.send(isOffline: false)
        XCTAssertEqual(state.phase, .received); XCTAssertEqual(service.reportedTypes[PostID(418202)], 7)
    }

    func testSingleRequestInFlight() async {
        let service = fixture(); service.reportDelay = .milliseconds(200)
        let state = ReportState(target: reply, title: "Walnut", account: .fixture, service: service)
        await state.load(isOffline: false); state.select(8)
        async let first: Bool = state.send(isOffline: false)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(state.phase, .sending); XCTAssertFalse(state.canSend)
        state.select(3)
        XCTAssertEqual(state.reasonID, 8, "Inputs are locked while sending")
        _ = await state.send(isOffline: false)
        _ = await first
        XCTAssertEqual(state.phase, .received)
    }

    func testUnknownReceiptRequiresCheckStatusAndNeverResends() async {
        let service = fixture(); service.reportScenario = .timeout; service.timeoutReceived = false
        let state = ReportState(target: reply, title: "Walnut", account: .fixture, service: service)
        await state.load(isOffline: false); state.select(8)
        await state.send(isOffline: false)
        XCTAssertEqual(state.notice, .unconfirmed); XCTAssertFalse(state.canSend, "Send stays off until the state is checked")
        await state.send(isOffline: false)
        XCTAssertTrue(service.reportedPosts.isEmpty)
        await state.checkStatus()
        XCTAssertEqual(state.notice, .notReceived); XCTAssertTrue(state.canSend)
        XCTAssertEqual(state.reasonID, 8, "Selection kept")

        let received = fixture(); received.reportScenario = .timeout; received.timeoutReceived = true
        let second = ReportState(target: reply, title: "Walnut", account: .fixture, service: received)
        await second.load(isOffline: false); second.select(8); await second.send(isOffline: false)
        await second.checkStatus()
        XCTAssertEqual(second.phase, .received)
    }

    func testRecoverableErrorsKeepInput() async {
        for (scenario, notice) in [(FixtureService.ReportScenario.rateLimited, ReportState.Notice.rateLimited), (.validation, .rejected("Please describe what moderators should look at."))] {
            let service = fixture(); service.reportScenario = scenario
            let state = ReportState(target: reply, title: "Walnut", account: .fixture, service: service)
            await state.load(isOffline: false); state.select(7); state.details = "Kept text"
            await state.send(isOffline: false)
            XCTAssertEqual(state.notice, notice); XCTAssertEqual(state.details, "Kept text"); XCTAssertEqual(state.phase, .form)
        }
        let offline = fixture()
        let state = ReportState(target: reply, title: "Walnut", account: .fixture, service: offline)
        await state.load(isOffline: false); state.select(8)
        await state.send(isOffline: true)
        XCTAssertEqual(state.notice, .offline); XCTAssertTrue(offline.reportedPosts.isEmpty, "Offline never sends")
        let expired = fixture(); expired.reportScenario = .expired
        let session = ReportState(target: reply, title: "Walnut", account: .fixture, service: expired)
        await session.load(isOffline: false); session.select(7); session.details = "Kept across sign-in"
        let needsSignIn = await session.send(isOffline: false)
        XCTAssertTrue(needsSignIn); XCTAssertEqual(session.details, "Kept across sign-in")
        expired.reportScenario = .received
        await session.load(isOffline: false, keepInput: true)
        XCTAssertEqual(session.reasonID, 7); XCTAssertEqual(session.details, "Kept across sign-in")
        XCTAssertTrue(expired.reportedPosts.isEmpty, "Returning from sign-in never submits")
    }

    func testTruthfulUnavailableAlreadyRemovedAndNewMemberStates() async {
        let denied = fixture(); denied.reportScenario = .denied
        let a = ReportState(target: reply, title: "W", account: .fixture, service: denied); await a.load(isOffline: false)
        XCTAssertEqual(a.phase, .unavailable)
        let reported = fixture(); reported.reportedPosts = [PostID(418202)]; reported.reportedTypes = [PostID(418202): 8]
        let b = ReportState(target: reply, title: "W", account: .fixture, service: reported); await b.load(isOffline: false)
        XCTAssertEqual(b.phase, .already)
        let gone = ReportState(target: .post(PostID(1), topic: .init(4182), number: .init(9), author: "x"), title: "W", account: .fixture, service: fixture()); await gone.load(isOffline: false)
        XCTAssertEqual(gone.phase, .removed)
        let newMember = fixture(); newMember.newMember = true
        let c = ReportState(target: reply, title: "W", account: .fixture, service: newMember); await c.load(isOffline: false)
        XCTAssertEqual(c.reasons.map(\.id), [10], "Deployed: TL0 may report only Illegal")
        let topic = ReportState(target: .discussion(.init(4182), opening: PostID(418201), author: "mara_k"), title: "W", account: .fixture, service: fixture()); await topic.load(isOffline: false)
        XCTAssertFalse(topic.reasons.contains { $0.id == 3 }, "Off-Topic is post-only")
    }

    func testGuestReportSignsInThenRechecksWithoutSubmitting() async {
        let service = fixture()
        let app = app(service); app.account = .guest; app.username = nil
        app.startReport(reply, title: "Walnut")
        XCTAssertNil(app.report); XCTAssertTrue(app.authRequested); XCTAssertEqual(app.gate, .report("reply"))
        await app.signIn()
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(app.report?.phase, .form); XCTAssertNil(app.report?.reasonID, "No reason preselected")
        XCTAssertTrue(service.reportedPosts.isEmpty, "Nothing is sent automatically after sign-in")
    }

    func testIgnoreSuccessOnlyAfterConfirmationAndUncertainNeedsRefresh() async {
        let service = fixture(); service.ignoreScenario = .uncertain
        let state = IgnoreState(username: "devon", name: nil, account: .fixture)
        let done = await state.confirm(service: service, isOffline: false)
        XCTAssertFalse(done); XCTAssertEqual(state.phase, .uncertain); XCTAssertFalse(state.canConfirm, "Refresh before any retry")
        service.ignoredUsers = ["devon"]
        let reconciled = await state.reconcile(service: service)
        XCTAssertTrue(reconciled)

        let staff = fixture()
        let s = IgnoreState(username: "alex.h", name: nil, account: .fixture)
        let staffDone = await s.confirm(service: staff, isOffline: false)
        XCTAssertFalse(staffDone); if case .denied = s.phase {} else { XCTFail("Staff can't be ignored") }
        let member = try? await staff.memberSafety("alex.h")
        XCTAssertEqual(member?.staff, true); XCTAssertEqual(member?.canIgnore, false)

        let newMember = fixture(); newMember.newMember = true
        let n = try? await newMember.memberSafety("devon")
        XCTAssertEqual(n?.canIgnore, false, "Deployed groups exclude TL0/TL1")
    }

    func testIgnoreEntryChecksEligibilityBeforeOpeningSheet() async {
        let service = fixture()
        let app = app(service)
        app.startIgnore("alex.h", name: nil)
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(app.ignoreSheet, "Staff get an explanation, never a sheet"); XCTAssertNotNil(app.banner)
        app.banner = nil
        service.newMember = true
        app.startIgnore("devon", name: nil)
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(app.ignoreSheet); XCTAssertEqual(app.banner, "Ignore isn’t available for your account yet. You can still report posts, or contact support.")
        service.newMember = false; app.banner = nil
        app.startIgnore("devon", name: nil)
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(app.ignoreSheet?.username, "devon")
        let state = IgnoreState(username: "devon", name: nil, account: app.account)
        let done = await state.confirm(service: service, isOffline: true)
        XCTAssertFalse(done)
        if case .failed = state.phase {} else { XCTFail("Offline is a failure, not a denial") }
        XCTAssertTrue(state.canConfirm)
    }

    func testAccountIsolationShowOnceAndStopIgnoring() async {
        let service = fixture(); service.ignoredUsers = ["devon"]
        let app = app(service)
        await app.loadSafety()
        XCTAssertTrue(app.isIgnored("devon"))
        app.revealed.insert(PostID(418202))
        XCTAssertTrue(app.isIgnored("devon"), "Show once never changes the preference")
        let stopped = await stopIgnoring("devon", app: app)
        XCTAssertTrue(stopped); XCTAssertFalse(app.isIgnored("devon")); XCTAssertTrue(app.revealed.isEmpty)

        service.ignoredUsers = ["devon"]; await app.loadSafety()
        app.report = ReportState(target: reply, title: "W", account: app.account, service: service)
        app.signOut()
        XCTAssertFalse(app.isIgnored("devon")); XCTAssertNil(app.report); XCTAssertNil(app.safetyAccount)
        app.account = .init(rawValue: "other"); app.username = "other"
        XCTAssertFalse(app.isIgnored("devon"), "Another account never inherits the previous list")
    }

    func testIgnoredListFailureIsScopedAndRetryable() async {
        let service = fixture(); service.ignoredListFails = true
        let app = app(service)
        await app.loadSafety()
        XCTAssertNotNil(app.safetyError); XCTAssertEqual(app.safetyAccount, app.account); XCTAssertTrue(app.safety.ignored.isEmpty)
        service.ignoredListFails = false; service.ignoredUsers = ["rowan.b"]
        await app.loadSafety()
        XCTAssertNil(app.safetyError); XCTAssertTrue(app.isIgnored("rowan.b"))
    }
}
