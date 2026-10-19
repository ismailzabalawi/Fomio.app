import XCTest

/// Native notification journeys against fictional fixtures. Permission prompts and pushes are simulations.
@MainActor final class NotificationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    private func launch(_ arguments: [String] = [], inbox: Bool = true) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--fixture", "--ui-testing"] + arguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        if inbox {
            let tab = app.buttons.matching(identifier: "Notifications").firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
            XCTAssertTrue(app.buttons["notification-5011"].waitForExistence(timeout: 10))
        }
        return app
    }
    private func label(_ app: XCUIApplication, _ id: Int) -> String { app.buttons["notification-\(id)"].label }
    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func testExactReplyIsAcknowledgedAfterDisplayAndBackKeepsInbox() {
        let app = launch()
        XCTAssertTrue(label(app, 5011).hasPrefix("Unread. devon replied to your post"))
        app.buttons["notification-5011"].tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["From your notification"].exists)
        back(app)
        let row = app.buttons["notification-5011"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH 'Unread')"), object: row)], timeout: 5), .completed)
    }
    func testGroupedRepliesOpenParentBranchWithoutSingleAuthor() {
        let app = launch()
        XCTAssertTrue(label(app, 5010).contains("3 new replies to your post"))
        app.buttons["notification-5010"].tap()
        XCTAssertTrue(app.staticTexts["Your post · 3 new replies"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["#5"].waitForExistence(timeout: 5), "New replies to the parent are expanded")
    }
    func testUnavailableTargetStaysUnread() {
        let app = launch()
        app.buttons["notification-5006"].tap()
        XCTAssertTrue(app.staticTexts["This post isn't available"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["It may have been deleted, or you may no longer have access. The notification stays in your inbox, unread."].exists)
        back(app)
        XCTAssertTrue(app.buttons["notification-5006"].waitForExistence(timeout: 5))
        XCTAssertTrue(label(app, 5006).hasPrefix("Unread"))
    }
    func testFailedAcknowledgmentKeepsUnreadUntilRetry() {
        let app = launch(["--notif-ack-fails"])
        app.buttons["notification-5011"].tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 5))
        let retry = app.buttons["ack-retry-target-5011"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5)); retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        back(app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH 'Unread')"), object: app.buttons["notification-5011"])], timeout: 5), .completed)
    }
    func testUnreadFilterEmptyBatchKeepsLooking() {
        let app = launch()
        app.buttons["Unread"].tap()
        let keep = app.buttons["notification-keep-looking"]
        for _ in 0..<6 where !keep.exists { app.swipeUp() }
        if !keep.exists, app.buttons["notification-show-older"].exists { app.buttons["notification-show-older"].tap() }
        for _ in 0..<4 where !keep.exists { app.swipeUp() }
        XCTAssertTrue(keep.waitForExistence(timeout: 5)); keep.tap()
        XCTAssertTrue(app.buttons["notification-4990"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.staticTexts["That’s everything"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["That’s everything"].waitForExistence(timeout: 5))
    }
    func testUnsupportedRowsOfferOnlyHonestDestinations() {
        let app = launch()
        app.buttons["notification-5007"].tap()
        XCTAssertTrue(app.buttons["notification-open-website"].waitForExistence(timeout: 5)); app.buttons["notification-open-website"].tap()
        XCTAssertTrue(app.staticTexts["Website (simulated)"].waitForExistence(timeout: 5)); app.buttons["Done"].firstMatch.tap()
        back(app)
        XCTAssertTrue(label(app, 5007).hasPrefix("Unread"), "Opening the website handoff does not mark read")
    }
    func testAlertSetupSeparatesPermissionFromEnrollment() {
        let app = launch(["--preset", "notif-setup-fails"], inbox: false)
        let turnOn = app.buttons["alerts-turn-on"]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 10))
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "this \(device)")).firstMatch.exists, "Device wording follows the idiom")
        turnOn.tap()
        app.buttons["alerts-continue"].tap()
        let allow = app.alerts.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        let retry = app.buttons["alerts-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "Allowed with failed setup is not On")
        XCTAssertTrue(app.descendants(matching: .any)["alert-status"].label.contains("Setup didn’t finish"))
        retry.tap()
        XCTAssertTrue(app.descendants(matching: .any)["alert-status"].waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'On'"), object: app.descendants(matching: .any)["alert-status"])], timeout: 5), .completed)
    }
    func testPushTapWaitsForChangedComposer() {
        let app = launch(["--preset", "notif-push-composer"], inbox: false)
        XCTAssertTrue(app.alerts["Open the notification?"].waitForExistence(timeout: 10))
        app.alerts.buttons["Keep Writing"].tap()
        let open = app.buttons["pending-notification-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        XCTAssertTrue(app.alerts["Open the notification?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Save Draft and Open"].tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 5))
    }
    func testPushForAnotherAccountIsNotOpened() {
        let app = launch(["--preset", "notif-push-other-account"], inbox: false)
        XCTAssertTrue(app.staticTexts["This notification is for another account"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["#14"].exists)
    }
    func testExpiredKeyPushTapAsksToSignInThenOpensTarget() {
        let app = launch(["--preset", "notif-push-expired"], inbox: false)
        XCTAssertTrue(app.staticTexts["Sign in to open this notification"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["#14"].exists, "Nothing protected opens with a rejected key")
        app.buttons["signin-continue"].tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 10))
    }
}
