import XCTest
@testable import Fomio

/// Notification contracts: live adapter request shapes (sanitized stubs), destinations, paging, acknowledgment,
/// totals scope, account isolation, ignored authors, incoming taps and device setup states.
@MainActor final class NotificationTests: XCTestCase {
    private func live(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) -> DiscourseService {
        StubURLProtocol.captured = nil; StubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let site = LiveConfiguration(baseURL: URL(string: "https://notif-\(UUID().uuidString).example/forum")!, callbackURL: URL(string: "testfixture://callback")!, scopes: "read,write,notifications,session_info")
        let credential = Credential(key: "fictional-test-key", clientID: "fictional-client", site: site.baseURL.absoluteString)
        return DiscourseService(configuration: site, session: URLSession(configuration: config), credentials: { _ in credential })
    }
    private func fixtureApp(_ arguments: (FixtureService) -> Void = { _ in }) async -> (AppState, FixtureService) {
        let service = FixtureService(); arguments(service)
        let app = AppState(service: service, fixture: service, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        await app.loadCommunities()
        return (app, service)
    }
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool, timeout: Double = 3) async {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { try? await Task.sleep(for: .milliseconds(20)) }
    }

    // MARK: Live adapter contract

    func testHistoryUsesRawWindowReadFilterAndRetainsEveryType() async throws {
        let json = #"{"notifications":[{"id":5010,"notification_type":2,"read":false,"topic_id":42,"post_number":21,"slug":"radio","fancy_title":"Radio &amp; caps","data":{"display_username":"3 replies","original_username":"ama","reply_to_post_number":4,"consolidated_count":3}},{"id":5007,"notification_type":800,"read":false,"data":{"display_username":"lena","consolidated_count":"oops","reply_to_post_number":{"x":1}}}],"total_rows_notifications":130,"seen_notification_id":4998,"load_more_notifications":"/notifications?offset=60"}"#
        let service = live { _ in (200, Data(json.utf8)) }
        let page = try await service.notificationHistory(offset: 0, limit: 60, filter: .unread)
        let url = try XCTUnwrap(StubURLProtocol.captured?.url)
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.path, "/forum/notifications.json")
        XCTAssertEqual(query["offset"], "0"); XCTAssertEqual(query["limit"], "60"); XCTAssertEqual(query["filter"], "unread")
        XCTAssertNil(query["filter_by_types"], "History ignores type filters; never imply type filtering")
        XCTAssertNil(query["recent"], "Recent without silent bumps the seen cursor")
        XCTAssertEqual(StubURLProtocol.captured?.value(forHTTPHeaderField: "User-Api-Key"), "fictional-test-key")
        XCTAssertEqual(page.items.count, 2, "Unknown plugin types and mistyped data keys are retained")
        XCTAssertEqual(page.nextOffset, 60, "Next offset follows the raw window, not the two returned rows")
        let grouped = page.items[0]
        XCTAssertTrue(grouped.isGroupedReplies); XCTAssertEqual(grouped.replyBucket, PostNumber(4)); XCTAssertEqual(grouped.consolidatedCount, 3)
        XCTAssertNil(grouped.actor, "“3 replies” is not an author"); XCTAssertEqual(grouped.topicTitle, "Radio & caps")
        XCTAssertEqual(page.items[1].kind, .unknown(800)); XCTAssertNil(page.items[1].consolidatedCount)
        let end = try await live { _ in (200, Data(#"{"notifications":[],"total_rows_notifications":61}"#.utf8)) }.notificationHistory(offset: 60, limit: 60, filter: .all)
        XCTAssertNil(end.nextOffset, "Only the server total ends history")
    }
    func testMarkReadSendsOnlyAnExactIDAndUnconfirmedSuccessIsNotRead() async throws {
        let service = live { request in
            XCTAssertEqual(request.httpMethod, "PUT"); XCTAssertEqual(request.url?.path, "/forum/notifications/mark-read.json")
            let body = try? JSONSerialization.jsonObject(with: StubURLProtocol.body(request)) as? [String: Any]
            XCTAssertEqual(body?["id"] as? Int, 5011); XCTAssertEqual(body?.count, 1)
            return (200, Data(#"{"success":"OK"}"#.utf8))
        }
        try await service.markNotificationRead(NotificationID(5011))
        do { try await service.markNotificationRead(NotificationID(0)); XCTFail("A missing ID must never reach the bulk path") }
        catch { XCTAssertEqual(StubURLProtocol.captured?.url?.path, "/forum/notifications/mark-read.json") }
        let odd = live { _ in (200, Data("{}".utf8)) }
        do { try await odd.markNotificationRead(NotificationID(7)); XCTFail("Unexpected success body is not proof") }
        catch { XCTAssertEqual(error as? RepositoryError, .unconfirmed) }
    }
    func testTotalsUseServerUnreadNotificationsWithCap() async throws {
        let service = live { request in XCTAssertEqual(request.url?.path, "/forum/notifications/totals.json"); return (200, Data(#"{"username":"m","unread_notifications":99,"unread_personal_messages":3}"#.utf8)) }
        let totals = try await service.notificationTotals()
        XCTAssertEqual(totals.unread, 99); XCTAssertEqual(totals.badgeText, "99+")
        XCTAssertNil(NotificationTotals(unread: 0).badgeText)
    }

    // MARK: Destinations and copy

    func testDestinationsKeepTopicPostNumberAndGroupedBucketsDistinct() {
        let site = URL(string: "https://community.example/forum")!
        func item(_ kind: NotificationKind, topic: Int? = 9, post: Int? = 15, bucket: Int? = nil, count: Int? = nil) -> NotificationItem {
            NotificationItem(id: .init(1), kind: kind, read: false, topicID: topic.map { TopicID($0) }, postNumber: post.map { PostNumber($0) }, slug: "t", displayUsername: "ruth", originalUsername: "ruth", replyBucket: bucket.map { PostNumber($0) }, consolidatedCount: count)
        }
        XCTAssertEqual(NotificationResolver.destination(item(.replied), site: site, username: "sam"), .post(.init(9), .init(15)))
        XCTAssertEqual(NotificationResolver.destination(item(.mentioned, post: 1), site: site, username: "sam"), .topic(.init(9)))
        XCTAssertEqual(NotificationResolver.destination(item(.replied, post: 21, bucket: 4, count: 3), site: site, username: "sam"), .groupedReplies(.init(9), parent: .init(4), count: 3))
        XCTAssertEqual(NotificationResolver.destination(item(.replied, post: 12, bucket: 1, count: 2), site: site, username: "sam"), .groupedReplies(.init(9), parent: nil, count: 2))
        XCTAssertEqual(NotificationResolver.destination(item(.replied, bucket: 4, count: 1), site: site, username: "sam"), .post(.init(9), .init(15)), "A single bucketed reply is exact")
        XCTAssertEqual(NotificationResolver.destination(item(.privateMessage, post: 2), site: site, username: "sam"), .website(URL(string: "https://community.example/forum/t/t/9/2")!))
        XCTAssertEqual(NotificationResolver.destination(item(.unknown(1000), topic: nil, post: nil), site: site, username: "sam"), .unsupported)
        XCTAssertEqual(NotificationResolver.destination(item(.unknown(800)), site: nil, username: "sam"), .unsupported, "No configured site means no web fallback")
        var badge = item(.grantedBadge, topic: nil, post: nil); badge.badgeID = 3; badge.badgeName = "Nice Reply!"
        XCTAssertEqual(NotificationResolver.destination(badge, site: site, username: "sam"), .website(URL(string: "https://community.example/forum/badges/3/nice-reply-?username=sam")!))
        XCTAssertTrue(NotificationResolver.isSameSite(URL(string: "https://community.example/forum/t/x/1")!, site: site))
        XCTAssertFalse(NotificationResolver.isSameSite(URL(string: "https://community.example/other")!, site: site))
        XCTAssertFalse(NotificationResolver.isSameSite(URL(string: "https://evil.example/forum")!, site: site))
    }
    func testGroupedCopyNeverCreditsOneAuthor() {
        var grouped = NotificationItem(id: .init(1), kind: .replied, read: false, topicID: .init(1), displayUsername: "3 replies", originalUsername: "ama", replyBucket: .init(4), consolidatedCount: 3)
        XCTAssertEqual(NotificationCopy(grouped).full, "3 new replies to your post")
        grouped.replyBucket = .init(1)
        XCTAssertEqual(NotificationCopy(grouped).full, "3 new replies to your discussion")
        let collapsed = NotificationItem(id: .init(2), kind: .replied, read: false, topicID: .init(1), displayUsername: "2 replies", originalUsername: "ama")
        XCTAssertFalse(NotificationCopy(collapsed).full.contains("ama"))
        XCTAssertEqual(NotificationCopy(NotificationItem(id: .init(3), kind: .unknown(900), read: false)).full, "Activity Fomio can’t show yet")
    }

    // MARK: Store behaviour

    func testFilteredEmptyPageIsNotEndOfHistory() async {
        let (app, _) = await fixtureApp()
        let store = app.notifications
        await store.select(.unread)
        XCTAssertEqual(store.rows().count, 6); XCTAssertEqual(store.feed.nextOffset, 6)
        await store.loadMore()
        XCTAssertEqual(store.rows().count, 6, "Second unread window is filtered out by permissions")
        XCTAssertTrue(store.feed.lastPageEmpty); XCTAssertEqual(store.feed.nextOffset, 12, "An empty filtered page keeps history open")
        await store.loadMore()
        XCTAssertTrue(store.rows().contains { $0.id == .init(4990) }); XCTAssertNil(store.feed.nextOffset)
    }
    func testBadgeIsServerTotalNotLoadedRows() async {
        let (app, _) = await fixtureApp()
        await app.notifications.loadIfNeeded(); await app.notifications.refreshTotals()
        let loadedUnread = app.notifications.rows().filter { !$0.read }.count
        XCTAssertEqual(app.notificationBadge, "6", "Server scope: unread rows newer than the seen cursor")
        XCTAssertEqual(loadedUnread, 6)
        await app.notifications.loadMore(); await app.notifications.loadMore(); await app.notifications.loadMore()
        XCTAssertGreaterThan(app.notifications.rows().filter { !$0.read }.count, 6)
        XCTAssertEqual(app.notificationBadge, "6", "Loading more rows never changes the badge")
    }
    func testAcknowledgmentFailureAndUnknownOutcomesReconcile() async {
        let (app, fixture) = await fixtureApp { $0.notices.nextAcknowledgment = .fail }
        let store = app.notifications
        await store.loadIfNeeded()
        await store.acknowledge(.init(5011))
        XCTAssertEqual(store.item(.init(5011))?.read, false)
        guard case .failed? = store.acknowledgments[.init(5011)] else { return XCTFail("Failure must be visible") }
        await store.acknowledge(.init(5011))
        XCTAssertEqual(store.item(.init(5011))?.read, true); XCTAssertNil(store.acknowledgments[.init(5011)])
        fixture.notices.nextAcknowledgment = .unknown
        await store.acknowledge(.init(5009))
        XCTAssertEqual(store.acknowledgments[.init(5009)], .unknown); XCTAssertEqual(store.item(.init(5009))?.read, false, "Unknown is not read")
        await store.recheck(.init(5009))
        XCTAssertEqual(store.item(.init(5009))?.read, true, "Server truth says the write landed"); XCTAssertNil(store.acknowledgments[.init(5009)])
        XCTAssertEqual(store.totals?.unread, 4)
    }
    func testAcknowledgesOnlyAfterTargetIsDisplayedAndNeverForUnavailableTargets() async {
        let (app, _) = await fixtureApp()
        app.selectedTab = .notifications
        await app.notifications.loadIfNeeded()
        let exact = app.notifications.item(.init(5011))!
        app.open(notification: exact)
        let route = Route.discussion(.init(4190), .init(14))
        XCTAssertEqual(app.tabs[.notifications]?.path.last, route)
        XCTAssertEqual(app.notifications.item(.init(5011))?.read, false, "Opening does not acknowledge")
        let state = app.discussionState(route)
        app.displayed(route, state: state)
        XCTAssertEqual(app.notifications.item(.init(5011))?.read, false, "Not displayed yet")
        await state.load(); app.displayed(route, state: state)
        await waitUntil { app.notifications.item(.init(5011))?.read == true }
        XCTAssertEqual(app.notifications.item(.init(5011))?.read, true)

        let missing = app.notifications.item(.init(5006))!
        app.open(notification: missing)
        let gone = Route.discussion(.init(4999), .init(6))
        let failed = app.discussionState(gone)
        await failed.load(); app.displayed(gone, state: failed)
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(failed.errorKind, .unavailable)
        XCTAssertEqual(app.notifications.item(.init(5006))?.read, false, "Unavailable targets stay unread")
    }
    func testGroupedRepliesOpenParentBranchWithRepliesExpanded() async {
        let (app, _) = await fixtureApp()
        app.selectedTab = .notifications
        await app.notifications.loadIfNeeded()
        app.open(notification: app.notifications.item(.init(5010))!)
        let route = Route.thread(.init(4205), .init(4))
        XCTAssertEqual(app.tabs[.notifications]?.path.last, route, "Bucket 4 opens the parent branch, not post #5")
        let state = app.discussionState(route)
        XCTAssertEqual(state.focus, .groupedReplies(3))
        await state.load()
        let parent = state.highlight.flatMap { state.nodes[$0] }
        XCTAssertEqual(parent?.number, PostNumber(4))
        XCTAssertTrue(state.expanded.contains(parent!.id))
        XCTAssertFalse(state.children[parent!.id, default: []].isEmpty)
    }
    func testRefreshReconcilesOtherDeviceReadsAndConsolidatedReplacement() async {
        let (app, fixture) = await fixtureApp()
        let store = app.notifications
        await store.loadIfNeeded()
        fixture.notices.markRead(.init(5009))
        fixture.notices.consolidate(replacing: .init(5010), with: .init(5020), count: 4)
        await store.refresh()
        XCTAssertEqual(store.item(.init(5009))?.read, true)
        XCTAssertEqual(store.syncNote, "Updated. 1 notification was read on another device.")
        XCTAssertFalse(store.rows().contains { $0.id == .init(5010) }, "Replaced consolidated ID is dropped")
        XCTAssertEqual(store.rows().first?.id, .init(5020)); XCTAssertEqual(store.rows().first?.consolidatedCount, 4)
        XCTAssertEqual(Set(store.rows().map(\.id)).count, store.rows().count, "No duplicates")
    }
    func testStaleResultsFromPreviousAccountAreDiscardedAndSignOutClears() async {
        let (app, fixture) = await fixtureApp()
        fixture.notices.delay = .milliseconds(300)
        let load = Task { await app.notifications.loadIfNeeded() }
        try? await Task.sleep(for: .milliseconds(50))
        app.notifications.reset(account: AccountID(rawValue: "https://other.example:someone"))
        await load.value
        XCTAssertTrue(app.notifications.rows().isEmpty, "A late page for the old account is discarded")
        fixture.notices.delay = .zero
        app.notifications.reset(account: app.account)
        await app.notifications.loadIfNeeded(); await app.notifications.refreshTotals()
        app.pendingIntent = NotificationIntent(site: NotificationFixture.site, username: "jonah.w", kind: .replied)
        app.signOut()
        XCTAssertTrue(app.notifications.rows().isEmpty); XCTAssertNil(app.notifications.totals); XCTAssertNil(app.notificationBadge); XCTAssertNil(app.pendingIntent)
        XCTAssertEqual(app.notifications.account, .guest)
    }
    func testIgnoredAuthorsAreHiddenAndAFullyHiddenPageIsNotTheEnd() async {
        let (app, _) = await fixtureApp()
        app.safety = SafetySession(username: AppState.fixtureMember, canIgnoreUsers: true, ignoredUsers: ["devon", "priya", "sunil.p", "alex.h", "theo"])
        let hidden: (NotificationItem) -> Bool = { item in item.filterNames.contains { app.isBlocked($0) } }
        await app.notifications.loadMore(hiding: hidden)
        let visible = app.notifications.rows().filter { !hidden($0) }
        XCTAssertFalse(visible.contains { $0.filterNames.contains("devon") })
        XCTAssertEqual(visible.map(\.id), [.init(5010)], "Grouped row has no ignored actor")
        XCTAssertNotNil(app.notifications.feed.nextOffset)
    }

    // MARK: Incoming taps

    func testIncomingTapValidationAccountSiteDuplicatesAndComposer() async {
        let (app, _) = await fixtureApp()
        await app.notifications.loadIfNeeded()
        let intent = NotificationIntent(site: NotificationFixture.site, username: "Jonah.W", notificationID: .init(5011), topicID: .init(4190), postNumber: .init(14), kind: .replied)
        var other = intent; other.site = URL(string: "https://elsewhere.example")!; other.notificationID = .init(1)
        await app.receive(other)
        XCTAssertNotNil(app.banner); XCTAssertTrue(app.tabs[.notifications]!.path.isEmpty); app.banner = nil
        var foreign = intent; foreign.username = "mara_k"; foreign.notificationID = .init(2)
        await app.receive(foreign)
        XCTAssertEqual(app.tabs[.notifications]?.path, [.notificationMismatch("mara_k")])
        await app.receive(intent); await app.receive(intent)
        XCTAssertEqual(app.duplicateTaps, 1)
        XCTAssertEqual(app.tabs[.notifications]?.path, [.discussion(.init(4190), .init(14))])
        XCTAssertEqual(app.notifications.item(.init(5011))?.read, false, "Receiving or tapping does not mark read")

        var draft = Draft(account: app.account, intent: .reply(topic: .init(4182), parent: .init(1)), body: "Original")
        draft.contextTitle = "Walnut"
        app.composer = ComposerState(draft: draft, app: app, origin: .home)
        app.composer?.draft.body = "Original plus changes"
        var later = intent; later.notificationID = .init(5009); later.topicID = .init(4201); later.postNumber = .init(6)
        await app.receive(later)
        XCTAssertEqual(app.pendingIntent, later); XCTAssertTrue(app.intentNeedsComposerDecision); XCTAssertNotNil(app.composer, "Changed writing is never interrupted")
        app.keepWritingWithPendingNotification()
        XCTAssertNotNil(app.pendingIntent)
        app.saveDraftAndOpenPendingNotification()
        XCTAssertNil(app.composer); XCTAssertNil(app.pendingIntent)
        XCTAssertEqual(app.tabs[.notifications]?.path, [.discussion(.init(4201), .init(6))])
        XCTAssertEqual(try app.draftStore.list(account: app.account).first?.body, "Original plus changes")
    }
    func testSignedOutTapKeepsIntentWithoutFetchingAndMissingIDNeverAcknowledges() async {
        let service = FixtureService()
        let app = AppState(service: service, fixture: service, configuration: nil, store: DraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        app.signOut()
        let intent = NotificationIntent(site: NotificationFixture.site, username: "jonah.w", topicID: .init(4190), postNumber: .init(14), kind: .replied)
        await app.receive(intent)
        XCTAssertEqual(app.pendingIntent, intent); XCTAssertTrue(app.authRequested); XCTAssertEqual(app.gate, .notification)
        XCTAssertTrue(app.tabs[.notifications]!.path.isEmpty, "No protected content before sign-in")
        await app.signIn()
        XCTAssertEqual(app.tabs[.notifications]?.path, [.discussion(.init(4190), .init(14))])
        XCTAssertTrue(app.tabs[.notifications]!.acknowledgments.isEmpty, "A payload without a notification ID never acknowledges")
        XCTAssertNil(NotificationIntent.parse(["fomio_site": "http://community.example", "fomio_username": "a", "notification_type": 2]))
        XCTAssertEqual(NotificationIntent.parse(["fomio_site": "https://community.example", "fomio_username": "a", "notification_type": "2", "topic_id": 4, "post_number": 0])?.postNumber, nil)
    }

    // MARK: Device setup

    func testDeviceStatusSeparatesPermissionFromEnrollment() async {
        let unavailable = NotificationDevice(permissions: SimulatedAlertPermission(), enrollments: UnavailableAlertEnrollment(), isPad: false)
        XCTAssertEqual(unavailable.status, .unavailable, "Live builds have no relay; permission alone never reads as On")
        let permission = SimulatedAlertPermission(), enrollment = SimulatedAlertEnrollment(); enrollment.step = .milliseconds(10); enrollment.failNext = true
        let device = NotificationDevice(permissions: permission, enrollments: enrollment, isPad: true)
        XCTAssertEqual(device.wording.device, "iPad"); XCTAssertEqual(device.wording.system, "iPadOS")
        await device.refreshPermission(); XCTAssertEqual(device.status, .off)
        let request = Task { await device.requestPermission(account: .fixture) }
        await waitUntil { device.simulatedPrompt != nil }
        device.answerSimulatedPrompt(true)
        await request.value
        XCTAssertEqual(device.status, .failed, "Allowed but setup failed is not On")
        await device.enroll(account: .fixture); XCTAssertEqual(device.status, .on)
        await device.detach(); XCTAssertEqual(device.status, .detached)
        device.setSimulatedPermission(false); XCTAssertEqual(device.status, .detached)
        device.bind(account: .fixture); XCTAssertEqual(device.status, .notAllowed)
        XCTAssertEqual(NotificationSettingsView.describe(.notAllowed, words: .current(isPad: false)).detail.contains("iOS Settings"), true)
    }

    // MARK: Independent audit regressions

    private func auditStore(pageSize: Int = 2) -> (NotificationStore, FixtureService) {
        let service = FixtureService()
        service.notices.pageSize = pageSize
        service.notices.rows = (1...8).reversed().map { n in NotificationFixture.Row(item: NotificationItem(id: .init(n), kind: .replied, read: false, topicID: .init(n), postNumber: .init(2), topicTitle: "Restricted topic \(n)")) }
        let store = NotificationStore(service: service, account: .fixture); store.pageSize = pageSize
        return (store, service)
    }
    func testAuditAcknowledgmentLeavesUnreadAndKeepsCursorAligned() async {
        let (store, _) = auditStore()
        await store.select(.unread)
        XCTAssertEqual(store.rows().map(\.id.rawValue), [8, 7])
        await store.acknowledge(.init(8))
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7], "A confirmed read leaves the Unread list")
        await store.loadMore()
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7, 6, 5], "The shifted unread cursor does not skip ID 6")
        // Acknowledged from All while Unread is partially loaded.
        await store.select(.all)
        XCTAssertEqual(store.rows().map(\.id.rawValue), [8, 7])
        await store.acknowledge(.init(7))
        XCTAssertFalse(store.rows(.unread).contains { $0.id.rawValue == 7 })
        XCTAssertEqual(store.feeds[.unread]?.nextOffset, 2)
        await store.select(.unread); await store.loadMore()
        XCTAssertEqual(store.rows().map(\.id.rawValue), [6, 5, 4, 3])
    }
    func testAuditAcknowledgmentDuringInFlightUnreadPageRestartsWithoutGap() async {
        let (store, service) = auditStore()
        await store.select(.unread)
        service.notices.delay = .milliseconds(700)
        let page = Task { await store.loadMore() }
        try? await Task.sleep(for: .milliseconds(100))
        await store.acknowledge(.init(8))
        await page.value
        service.notices.delay = .zero
        while store.feed.nextOffset != nil { await store.loadMore() }
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7, 6, 5, 4, 3, 2, 1], "Every remaining unread row appears exactly once")
    }
    func testAuditRefreshWithoutOverlapRestartsAndDropsRestrictedRows() async {
        let (store, service) = auditStore()
        await store.loadMore()
        service.notices.rows = service.notices.rows.map { var row = $0; row.inaccessible = true; return row }
        await store.refresh()
        XCTAssertTrue(store.rows().isEmpty); XCTAssertNil(store.item(.init(8)), "Restricted titles leave memory")
        XCTAssertTrue(store.feed.lastPageEmpty); XCTAssertEqual(store.feed.nextOffset, 2, "History continues from the authoritative window")
        let (replaced, replacedService) = auditStore()
        await replaced.loadMore()
        replacedService.notices.rows = (20...27).reversed().map { n in NotificationFixture.Row(item: NotificationItem(id: .init(n), kind: .mentioned, read: false, topicID: .init(n), postNumber: .init(2))) }
        await replaced.refresh()
        XCTAssertEqual(replaced.rows().map(\.id.rawValue), [27, 26], "A fully replaced window keeps no old IDs")
        XCTAssertEqual(replaced.feed.nextOffset, 2)
    }
    func testAuditRecheckRequiresPositiveEvidence() async {
        let (store, service) = auditStore()
        await store.loadMore()
        service.notices.nextAcknowledgment = .fail
        await store.acknowledge(.init(8))
        service.notices.rows[0].inaccessible = true
        await store.recheck(.init(8))
        XCTAssertEqual(store.item(.init(8))?.read, false, "Absence from filtered history is not a confirmed read")
        XCTAssertEqual(store.acknowledgments[.init(8)], .unknown)
        XCTAssertFalse(service.notices.rows[0].item.read)
        service.notices.rows[0].inaccessible = false; service.notices.markRead(.init(8))
        await store.recheck(.init(8))
        XCTAssertEqual(store.item(.init(8))?.read, true, "A returned read row confirms the write"); XCTAssertNil(store.acknowledgments[.init(8)])
    }
    func testAuditGroupedRepliesAcknowledgeOnlyAfterRepliesLoad() async {
        let (app, fixture) = await fixtureApp()
        app.selectedTab = .notifications
        await app.notifications.loadIfNeeded()
        app.open(notification: app.notifications.item(.init(5010))!)
        let route = Route.thread(.init(4205), .init(4))
        let state = app.discussionState(route)
        fixture.failNextChildren = true
        await state.load(); app.displayed(route, state: state)
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertNotNil(state.page); XCTAssertNil(state.error)
        let parent = state.highlight!
        XCTAssertNotNil(state.childErrors[parent], "Parent loaded, replies failed")
        XCTAssertFalse(state.requiredContentReady)
        XCTAssertEqual(app.notifications.item(.init(5010))?.read, false, "Grouped notification stays unread without its replies")
        XCTAssertNotNil(app.tabs[.notifications]?.acknowledgments[route], "Acknowledgment stays pending for the retry")
        await state.loadChildren(parent, depth: 0, first: true)
        XCTAssertTrue(state.requiredContentReady)
        app.displayed(route, state: state)
        await waitUntil { app.notifications.item(.init(5010))?.read == true }
        XCTAssertEqual(app.notifications.item(.init(5010))?.read, true)
    }

    func testExpiredKeyTapKeepsIntentAndRoutesAfterSignIn() async {
        let (app, fixture) = await fixtureApp()
        await app.notifications.loadIfNeeded()
        fixture.credentialExpired = true
        let intent = NotificationIntent(site: NotificationFixture.site, username: "jonah.w", notificationID: .init(5011), topicID: .init(4190), postNumber: .init(14), kind: .replied)
        await app.receive(intent)
        XCTAssertEqual(app.pendingIntent, intent); XCTAssertTrue(app.authRequested); XCTAssertEqual(app.gate, .notification)
        XCTAssertTrue(app.tabs[.notifications]!.path.isEmpty, "No protected destination with a rejected key")
        await app.signIn()
        XCTAssertNil(app.pendingIntent)
        XCTAssertEqual(app.tabs[.notifications]?.path, [.discussion(.init(4190), .init(14))], "Same member returns to the tapped target")
        XCTAssertEqual(app.notifications.item(.init(5011))?.read, false, "Nothing is acknowledged before display")
    }
    func testLiveCredentialCheckTreatsInvalidAccessAsExpired() async throws {
        let rejected = live { request in XCTAssertEqual(request.url?.path, "/forum/session/current.json"); return (403, Data(#"{"error_type":"invalid_access"}"#.utf8)) }
        let isValid = try await rejected.credentialIsValid(username: "member")
        XCTAssertFalse(isValid)
        let accepted = live { _ in (200, Data(#"{"current_user":{"username":"Member"}}"#.utf8)) }
        let stillValid = try await accepted.credentialIsValid(username: "member")
        XCTAssertTrue(stillValid)
        let other = live { _ in (200, Data(#"{"current_user":{"username":"someone"}}"#.utf8)) }
        let mismatch = try await other.credentialIsValid(username: "member")
        XCTAssertFalse(mismatch)
    }

    // MARK: 2026-10-19 audit regressions

    private func suspendedRefresh(_ store: NotificationStore, _ service: FixtureService) async -> Task<Void, Never> {
        service.suspendNextHistory = true
        let refresh = Task { await store.refresh() }
        while !service.historySuspended { await Task.yield() }
        return refresh
    }
    func testAudit2StaleUnreadRefreshCannotRestoreAcknowledgedRow() async {
        let (store, service) = auditStore()
        await store.select(.unread)
        let refresh = await suspendedRefresh(store, service)
        await store.acknowledge(.init(8))
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7])
        service.resumeHistory(); await refresh.value
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7, 6], "The refresh re-fetched after the acknowledgment: a fresh first window, without ID 8")
        XCTAssertNotEqual(store.item(.init(8))?.read, false, "ID 8 is never held as unread again (it is read or no longer loaded)")
        while store.feed.nextOffset != nil { await store.loadMore() }
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7, 6, 5, 4, 3, 2, 1], "No unread row is skipped")
    }
    func testAudit2StaleAllRefreshKeepsConfirmedReadAndUnreadStaysAligned() async {
        let (store, service) = auditStore()
        await store.select(.unread)
        await store.select(.all)
        let refresh = await suspendedRefresh(store, service)
        await store.acknowledge(.init(8))
        service.resumeHistory(); await refresh.value
        XCTAssertEqual(store.item(.init(8))?.read, true, "A stale All snapshot cannot downgrade a confirmed read")
        XCTAssertEqual(store.rows().first?.id, .init(8))
        await store.select(.unread)
        while store.feed.nextOffset != nil { await store.loadMore() }
        XCTAssertEqual(store.rows().map(\.id.rawValue), [7, 6, 5, 4, 3, 2, 1])
    }
    func testAudit2StaleAllPageCannotDowngradeConfirmedRead() async {
        let (store, service) = auditStore()
        await store.loadMore()
        service.suspendNextHistory = true
        let page = Task { await store.loadMore() }
        while !service.historySuspended { await Task.yield() }
        await store.acknowledge(.init(5))
        service.resumeHistory(); await page.value
        XCTAssertEqual(store.item(.init(5))?.read, true)
        XCTAssertEqual(store.rows().map(\.id.rawValue), [8, 7, 6, 5])
    }
    func testAudit2GroupedRowSurvivesIgnoringItsOriginalMember() async {
        let (app, _) = await fixtureApp()
        app.safety = SafetySession(username: AppState.fixtureMember, canIgnoreUsers: true, ignoredUsers: ["ines.r", "devon"])
        let hidden: (NotificationItem) -> Bool = { item in item.filterNames.contains { app.isBlocked($0) } }
        var grouped = NotificationItem(id: .init(90), kind: .replied, read: false, topicID: .init(90), postNumber: .init(5), displayUsername: "3 replies", originalUsername: "ines.r", replyBucket: .init(4), consolidatedCount: 3)
        XCTAssertNil(grouped.actor); XCTAssertFalse(hidden(grouped), "Other members' replies in the bucket stay visible")
        grouped.replyBucket = nil; grouped.consolidatedCount = nil
        XCTAssertFalse(hidden(grouped), "A collapsed multi-reply row is not credited to one member either")
        let single = NotificationItem(id: .init(91), kind: .replied, read: false, topicID: .init(91), postNumber: .init(2), displayUsername: "devon", originalUsername: "devon")
        XCTAssertTrue(hidden(single), "Individual notifications from an ignored member stay hidden")
        await app.notifications.loadIfNeeded()
        let fixtureGrouped = try? XCTUnwrap(app.notifications.item(.init(5010)))
        XCTAssertEqual(fixtureGrouped?.originalUsername, "ines.r"); XCTAssertEqual(fixtureGrouped.map(hidden), false)
    }
}
