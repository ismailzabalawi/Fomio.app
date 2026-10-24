import XCTest

/// Notifications with two browsing windows on iPad, against fictional fixtures. A push tap is simulated through the
/// real handler from inside one window (`--push-control`), which also makes that window the most recently used.
@MainActor final class MultiWindowNotificationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch() throws -> XCUIApplication {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Multiple browsing windows are an iPad capability") }
        let app = XCUIApplication(); app.launchArguments = ["--fixture", "--ui-testing", "--push-control"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10))
        return app
    }
    /// Opens a second window with Duo's New window action and returns both, oldest first.
    private func twoWindows(_ app: XCUIApplication) throws -> (XCUIElement, XCUIElement) {
        app.buttons["feed-options"].firstMatch.tap()
        let action = app.buttons["new-browsing-window"]
        XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
        let controls = app.buttons.matching(identifier: "simulate-push")
        // Frames, not `isHittable`: XCTest fails outright when asked about an element of a window that is off screen.
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in controls.count >= 2 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 10), .completed, "New window opens a second browsing window")
        let windows = app.windows.allElementsBoundByIndex.filter { $0.buttons["simulate-push"].exists }.sorted { $0.frame.minX < $1.frame.minX }
        XCTAssertEqual(windows.count, 2)
        // Full-screen app mode stacks the new window over the old one (both cover the screen); only one is visible.
        guard !windows[0].frame.intersects(windows[1].frame) else {
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "Stacked windows"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            throw XCTSkip("Both windows must be side by side (Split View or Stage Manager); this simulator stacks them full screen")
        }
        return (windows[0], windows[1])
    }
    private func tab(_ window: XCUIElement, _ name: String) {
        let tab = window.buttons.matching(identifier: name).firstMatch
        if tab.waitForExistence(timeout: 3), tab.isHittable { tab.tap(); return }
        // Beside the sidebar the tab bar is hidden; the sidebar carries the same destinations.
        window.buttons["sidebar-tab-\(name.lowercased())"].tap()
    }

    func testPushTapOpensOnlyInTheWindowItCameFrom() throws {
        let app = try launch()
        let (left, right) = try twoWindows(app)
        right.buttons["simulate-push"].tap()
        XCTAssertTrue(right.staticTexts["#14"].waitForExistence(timeout: 10))
        XCTAssertTrue(right.staticTexts["From your notification"].exists)
        XCTAssertFalse(left.staticTexts["#14"].exists, "The other window's navigation is untouched")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Push opened in the right window"; capture.lifetime = .keepAlways; add(capture)
    }
    func testReadInOneWindowShowsInTheOther() throws {
        let app = try launch()
        let (left, right) = try twoWindows(app)
        tab(right, "Notifications")
        let row = right.buttons["notification-5011"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); XCTAssertTrue(row.label.hasPrefix("Unread"))
        tab(left, "Notifications")
        left.buttons["notification-5011"].tap()
        XCTAssertTrue(left.staticTexts["#14"].waitForExistence(timeout: 5))
        let read = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH 'Unread')"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [read], timeout: 10), .completed, "The other window's row follows the shared inbox")
    }
    func testSignOutInOneWindowClearsBoth() throws {
        let app = try launch()
        let (left, right) = try twoWindows(app)
        tab(right, "Notifications")
        XCTAssertTrue(right.buttons["notification-5011"].waitForExistence(timeout: 10))
        tab(left, "Me")
        let signOut = left.buttons["Sign out"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5)); signOut.tap()
        let confirm = app.alerts.buttons["Sign out"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(right.staticTexts["Sign in to see notifications"].waitForExistence(timeout: 10))
        XCTAssertFalse(right.buttons["notification-5011"].exists, "Private rows leave every window")
    }
}
