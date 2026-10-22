import XCTest
@testable import Fomio

/// Notifications with several windows: one shared inbox, badge and device setup; taps routed to the window used most
/// recently; sign-out and rejected keys applied to every window at once.
@MainActor final class MultiWindowNotificationTests: XCTestCase {
    private func windows(_ configure: (FixtureService) -> Void = { _ in }) -> (AppWindows, FixtureService) {
        let fixture = FixtureService(); configure(fixture)
        let store = DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        return (AppWindows(service: fixture, fixture: fixture, configuration: nil, store: store), fixture)
    }
    /// Two windows that finished launching, the second one created last.
    private func twoWindows(_ configure: (FixtureService) -> Void = { _ in }) async -> (AppWindows, AppState, AppState, FixtureService) {
        let (windows, fixture) = windows(configure)
        let first = windows.makeWindow(), second = windows.makeWindow()
        await first.loadCommunities(); await second.loadCommunities()
        first.notificationsReady(); second.notificationsReady()
        return (windows, first, second, fixture)
    }
    private func intent(_ id: Int = 5011, topic: Int = 4190, post: Int = 14) -> NotificationIntent {
        NotificationIntent(site: NotificationFixture.site, username: "jonah.w", notificationID: .init(id), topicID: .init(topic), postNumber: .init(post), kind: .replied)
    }
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool, timeout: Double = 3) async {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { try? await Task.sleep(for: .milliseconds(20)) }
    }
    private let bench = Route.discussion(.init(4190), .init(14))
    private let deepSleep = Route.discussion(.init(4201), .init(6))

    func testTapOpensInMostRecentlyActiveWindowOnly() async {
        let (windows, first, second, _) = await twoWindows()
        XCTAssertTrue(first.notifications === second.notifications && first.device === second.device, "One inbox and device setup")
        first.becameActive()
        windows.deliver(intent())
        await waitUntil { first.tabs[.notifications]?.path == [self.bench] }
        XCTAssertEqual(first.tabs[.notifications]?.path, [bench]); XCTAssertEqual(first.selectedTab, .notifications)
        XCTAssertEqual(second.selectedTab, .home); XCTAssertTrue(second.tabs[.notifications]!.path.isEmpty, "The other window's navigation is untouched")
        second.becameActive()
        windows.deliver(intent(5009, topic: 4201, post: 6))
        await waitUntil { second.tabs[.notifications]?.path == [self.deepSleep] }
        XCTAssertEqual(second.tabs[.notifications]?.path, [deepSleep])
        XCTAssertEqual(first.tabs[.notifications]?.path, [bench])
    }
    func testClosedWindowNoLongerReceivesTaps() async {
        let (windows, first, second, _) = await twoWindows()
        second.becameActive(); second.closeWindow()
        windows.deliver(intent())
        await waitUntil { first.tabs[.notifications]?.path == [self.bench] }
        XCTAssertEqual(first.tabs[.notifications]?.path, [bench])
        XCTAssertTrue(second.tabs[.notifications]!.path.isEmpty)
    }
    func testTapBeforeAnyWindowLaunchesIsHeldForTheFirstWindow() async {
        let (windows, _) = windows()
        windows.deliver(intent())
        let state = windows.makeWindow()
        await state.loadCommunities()
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(state.tabs[.notifications]!.path.isEmpty, "Nothing opens before the window has restored the account")
        state.notificationsReady()
        await waitUntil { state.tabs[.notifications]?.path == [self.bench] }
        XCTAssertEqual(state.tabs[.notifications]?.path, [bench])
    }
    func testSameTapInTwoWindowsOpensOnce() async {
        let (windows, first, second, _) = await twoWindows()
        first.becameActive(); windows.deliver(intent())
        await waitUntil { first.tabs[.notifications]?.path == [self.bench] }
        second.becameActive(); windows.deliver(intent())
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(second.tabs[.notifications]!.path.isEmpty)
        XCTAssertEqual(first.duplicateTaps, 1); XCTAssertEqual(second.duplicateTaps, 1, "One filter covers every window")
    }
    func testReadInOneWindowUpdatesSharedRowsBadgeAndUnreadCursor() async {
        let (_, first, second, _) = await twoWindows()
        await second.notifications.select(.unread); await second.refreshNotificationTotals()
        XCTAssertEqual(second.notificationBadge, "6")
        XCTAssertEqual(second.notifications.rows().map(\.id.rawValue), [5011, 5010, 5009, 5008, 5007, 5006])
        first.selectedTab = .notifications
        first.open(notification: first.notifications.item(.init(5011))!)
        let state = first.discussionState(bench, in: .notifications)
        await state.load(); first.displayed(bench, state: state)
        await waitUntil { second.notifications.item(.init(5011))?.read == true && second.notificationBadge == "5" }
        XCTAssertEqual(second.notifications.item(.init(5011))?.read, true)
        XCTAssertEqual(second.notificationBadge, "5", "The badge seen from the other window follows the server total")
        XCTAssertTrue(second.tabs[.notifications]!.acknowledgments.isEmpty, "Read-on-display bookkeeping stays in the opening window")
        // The confirmed read moved the Unread cursor back by one: paging to the end skips no unread row.
        for _ in 0..<5 where second.notifications.feed.nextOffset != nil { await second.notifications.loadMore() }
        XCTAssertEqual(second.notifications.rows().map(\.id.rawValue), [5010, 5009, 5008, 5007, 5006, 4990])
    }
    func testSignOutWithTwoWindowsClearsOnceAndResetsBoth() async {
        let (windows, first, second, _) = await twoWindows()
        await first.notifications.loadIfNeeded(); await first.refreshNotificationTotals()
        await first.device.enroll(account: first.account)
        XCTAssertEqual(first.device.enrollment, .ready)
        first.pendingIntent = intent(); second.pendingIntent = intent(5009, topic: 4201, post: 6); second.intentNeedsComposerDecision = true
        first.tabs[.notifications]?.acknowledgments[bench] = .init(5011)
        second.signOut()
        XCTAssertTrue(first.notifications.rows().isEmpty); XCTAssertNil(first.notificationBadge); XCTAssertNil(second.notificationBadge)
        XCTAssertEqual(windows.notifications.account, .guest)
        for state in [first, second] {
            XCTAssertNil(state.pendingIntent); XCTAssertFalse(state.intentNeedsComposerDecision); XCTAssertNil(state.username)
            XCTAssertTrue(state.tabs[.notifications]!.acknowledgments.isEmpty)
        }
        await waitUntil { windows.device.enrollment == .detached }
        XCTAssertEqual(windows.device.enrollment, .detached, "Device alerts detach once, for the device")
        // A tap that arrives after sign-out waits for sign-in in the window it lands in, and opens nothing.
        first.becameActive(); windows.deliver(intent())
        await waitUntil { first.pendingIntent != nil }
        XCTAssertTrue(first.authRequested); XCTAssertFalse(second.authRequested)
        XCTAssertTrue(first.tabs[.notifications]!.path.isEmpty)
    }
    func testRejectedKeyExpiresEveryWindowAndOpensOnlyInTheTappedOne() async {
        let (windows, first, second, fixture) = await twoWindows()
        fixture.credentialExpired = true
        second.becameActive(); windows.deliver(intent())
        await waitUntil { second.authRequested }
        XCTAssertNil(first.username); XCTAssertNil(second.username, "Every window agrees the session ended")
        XCTAssertTrue(second.authRequested); XCTAssertEqual(second.gate, .notification); XCTAssertEqual(second.pendingIntent, intent())
        XCTAssertFalse(first.authRequested, "Only the tapped window asks to sign in")
        XCTAssertTrue(second.tabs[.notifications]!.path.isEmpty, "No protected destination with a rejected key")
        await second.signIn()
        XCTAssertEqual(first.username, AppState.fixtureMember); XCTAssertEqual(second.username, AppState.fixtureMember)
        XCTAssertEqual(second.tabs[.notifications]?.path, [bench], "The same member returns to the tapped target there")
        XCTAssertTrue(first.tabs[.notifications]!.path.isEmpty)
        XCTAssertNil(first.pendingIntent); XCTAssertNil(second.pendingIntent)
    }
    func testOpenDraftHoldsTapOnlyInTheTargetWindow() async throws {
        let (windows, first, second, _) = await twoWindows()
        var draft = Draft(account: second.account, intent: .reply(topic: .init(4182), parent: .init(1)), body: "Original")
        draft.contextTitle = "Walnut"
        second.composer = ComposerState(draft: draft, app: second, origin: .home)
        second.composer?.draft.body = "Original plus changes"
        second.becameActive(); windows.deliver(intent())
        await waitUntil { second.intentNeedsComposerDecision }
        XCTAssertEqual(second.pendingIntent, intent()); XCTAssertNotNil(second.composer, "Changed writing is never interrupted")
        XCTAssertNil(first.pendingIntent); XCTAssertTrue(first.tabs[.notifications]!.path.isEmpty)
        XCTAssertNil(first.composer, "The draft stays owned by its own window")
        second.saveDraftAndOpenPendingNotification()
        XCTAssertNil(second.composer); XCTAssertEqual(second.tabs[.notifications]?.path, [bench])
        XCTAssertEqual(try second.draftStore.list(account: second.account).first?.body, "Original plus changes")
    }
    func testForegroundWithTwoWindowsMakesOneRefresh() async {
        let (_, first, second, fixture) = await twoWindows()
        await first.notifications.loadIfNeeded()
        let history = fixture.historyRequests, totals = fixture.totalsRequests
        async let a: Void = first.foregroundRefresh()
        async let b: Void = second.foregroundRefresh()
        _ = await (a, b)
        XCTAssertEqual(fixture.historyRequests - history, 1, "One shared refresh, not one per window")
        XCTAssertEqual(fixture.totalsRequests - totals, 1)
        await second.foregroundRefresh()
        XCTAssertEqual(fixture.historyRequests - history, 1, "Inside the 30-second throttle")
    }
}
