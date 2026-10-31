import XCTest

/// Compact/Cards feed appearance: menu, persistence, reading-position anchor, Back, pagination and card cases.
/// Uses fictional fixture content (`--card-cases`) only.
@MainActor final class FeedAppearanceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }

    func testMenuSwitchesBothWaysAndPersistsAcrossRelaunch() {
        var app = launch()
        XCTAssertTrue(app.scrollViews["feed-compact"].exists, "Compact is the default")
        XCTAssertTrue(app.buttons["reveal-topic-search"].exists)
        openOptions(app)
        XCTAssertTrue(app.buttons["New discussion"].exists, "Create stays reachable, beside Search or in the options menu")
        XCTAssertTrue(app.buttons["Compact"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["Compact"].isSelected); XCTAssertFalse(app.buttons["Cards"].isSelected)
        capture(app, "Home options menu, Compact selected")
        app.buttons["Cards"].tap()
        XCTAssertTrue(app.scrollViews["feed-cards"].waitForExistence(timeout: 5))
        capture(app, "Cards appearance")
        app.terminate()
        app = launch(keepPreferences: true)
        XCTAssertTrue(app.scrollViews["feed-cards"].exists, "Cards persists after relaunch")
        openOptions(app)
        XCTAssertTrue(app.buttons["Cards"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["Cards"].isSelected)
        capture(app, "Relaunched, Cards selected")
        app.buttons["Compact"].tap()
        XCTAssertTrue(app.scrollViews["feed-compact"].waitForExistence(timeout: 5))
        app.terminate()
        app = launch(keepPreferences: true)
        XCTAssertTrue(app.scrollViews["feed-compact"].exists, "Compact persists after relaunch")
    }

    func testSwitchKeepsMidFeedTopicAnchorBothDirections() {
        let app = launch()
        loadSecondPage(app)
        let top = app.descendants(matching: .any).matching(identifier: "browse-header").firstMatch.frame.maxY
        let topic = app.buttons["topic-5003"]
        drag(app, topic, toY: top + 44)
        let before = topic.frame.minY
        choose(app, "Cards")
        XCTAssertLessThan(abs(topic.frame.minY - before), 28, "Same topic keeps its reading position in Cards")
        capture(app, "Mid-feed anchor after Compact → Cards")
        let cards = topic.frame.minY
        choose(app, "Compact")
        XCTAssertLessThan(abs(topic.frame.minY - cards), 28, "Anchor kept after Cards → Compact")
        XCTAssertLessThan(abs(topic.frame.minY - before), 6, "Round trip returns to the original position")

        // Partly scrolled past the top: the same topic remains the first one visible after each switch.
        let partial = app.buttons["topic-5004"]
        drag(app, partial, toY: top - 40)
        XCTAssertLessThan(partial.frame.minY, top)
        for value in ["Cards", "Compact"] {
            choose(app, value)
            XCTAssertLessThan(partial.frame.minY, top + 4, "\(value): anchor topic still begins at or above the top")
            XCTAssertGreaterThan(partial.frame.maxY, top + 20, "\(value): anchor topic is still the visible reading position")
            capture(app, "Partly hidden anchor in \(value)")
        }
    }

    func testCardsSurviveCategoryAndTopicBack() {
        let app = launch()
        choose(app, "Cards")
        let top = app.descendants(matching: .any).matching(identifier: "browse-header").firstMatch.frame.maxY
        let topic = app.buttons["topic-5002"]
        drag(app, topic, toY: top + 160)
        let before = topic.frame.minY
        let category = app.buttons["topic-category-8"]
        XCTAssertTrue(category.isHittable); XCTAssertGreaterThanOrEqual(category.frame.height, 43.5, "Accessibility frames round to 44 points")
        category.tap()
        XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["feed-cards"].exists, "Category feeds use the same appearance")
        capture(app, "Category feed in Cards")
        app.buttons["community-scope"].tap(); app.buttons["scope-all"].tap()
        XCTAssertTrue(app.buttons["community-scope"].waitForNonExistence(timeout: 5), "All shows the untitled list")
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(topic.frame.minY - before), 3, "Choosing All restores the Home reading position")
        topic.tap()
        returnToTopicList(app)
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(topic.frame.minY - before), 3, "Topic Back restores the Home reading position")
        XCTAssertTrue(app.scrollViews["feed-cards"].exists)
    }

    func testSwitchKeepsPaginationErrorAndLoadedPages() {
        let app = launch(["--feed-more-fails"])
        let more = app.buttons["More discussions"]
        scrollUntilHittable(app, more); more.tap()
        let failure = app.staticTexts["Couldn’t load more"]
        XCTAssertTrue(failure.waitForExistence(timeout: 5))
        choose(app, "Cards")
        scrollUntilHittable(app, failure)
        XCTAssertTrue(app.buttons["topic-5004"].exists, "Loaded first page retained")
        capture(app, "Pagination error retained in Cards")
        app.buttons["Retry"].tap()
        let loaded = app.buttons["topic-4182"]
        scrollUntilHittable(app, loaded)
        choose(app, "Compact")
        XCTAssertTrue(loaded.exists, "Second page retained after switching")
        XCTAssertFalse(failure.exists)
        loaded.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        returnToTopicList(app)
        XCTAssertTrue(loaded.waitForExistence(timeout: 5)); XCTAssertTrue(app.scrollViews["feed-compact"].exists)
    }

    func testCardCasesOmitAbsentFieldsAndKeepSeparateTargets() {
        let app = launch()
        let pinned = app.buttons["topic-5001"]
        XCTAssertTrue(pinned.label.contains("Pinned")); XCTAssertTrue(pinned.label.contains("No replies yet")); XCTAssertTrue(pinned.label.contains("started by devon"))
        XCTAssertTrue(pinned.label.contains("active 3 hours ago"))
        XCTAssertTrue(app.buttons["topic-category-5"].exists, "Category is a sibling target")
        XCTAssertFalse(pinned.buttons.count > 0, "No nested buttons inside the topic target")
        let sparse = app.buttons["topic-5003"]
        XCTAssertFalse(sparse.label.contains("started by")); XCTAssertFalse(sparse.label.contains("active"))
        XCTAssertTrue(sparse.label.contains("No replies yet"))
        let failed = app.buttons["topic-5004"]
        scrollUntilHittable(app, failed)
        // The image fails asynchronously after the row appears; the card then drops its media slot.
        let fellBack = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label CONTAINS %@)", "Has image"), object: failed)
        XCTAssertEqual(XCTWaiter.wait(for: [fellBack], timeout: 10), .completed, "Failed media falls back to text")
        // Toolbar controls are system glass items; the options button matches the system Search control.
        XCTAssertEqual(app.buttons["feed-options"].frame.height, app.buttons["reveal-topic-search"].frame.height)
        loadSecondPage(app)
        for value in ["Compact", "Cards"] {
            choose(app, value)
            let long = app.buttons["topic-5005"]; scrollUntilHittable(app, long)
            XCTAssertTrue(long.label.contains("Photo:"))
            capture(app, "\(value): long title with photo")
        }
    }

    func testDarkAccessibilityTextAndRightToLeftCaptures() {
        for (name, arguments) in [("Dark AX3", ["--dark", "--accessibility-text"]), ("Arabic RTL", ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_JO", "--rtl"]), ("Teal dark", ["--dark", "--teal-theme"])] {
            let app = launch(arguments)
            let arabic = arguments.contains("(ar)")
            for value in ["Compact", "Cards"] {
                choose(app, value, label: arabic ? (value == "Compact" ? "مضغوط" : "بطاقات") : value)
                XCTAssertTrue(app.buttons["topic-4190"].waitForExistence(timeout: 3))
                capture(app, "\(name) \(value) top")
                drag(app, app.buttons["topic-5001"], toY: app.descendants(matching: .any).matching(identifier: "browse-header").firstMatch.frame.maxY + 20)
                capture(app, "\(name) \(value) scrolled")
                scrollToTop(app)
            }
            app.terminate()
        }
    }

    // MARK: Helpers

    private func launch(_ arguments: [String] = [], keepPreferences: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing", "--card-cases"] + arguments + (keepPreferences ? ["--keep-preferences"] : [])
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["topic-4190"].waitForExistence(timeout: 10))
        return app
    }
    private func choose(_ app: XCUIApplication, _ title: String, label: String? = nil) {
        openOptions(app)
        let item = app.buttons[label ?? title]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.scrollViews["feed-\(title.lowercased())"].waitForExistence(timeout: 5))
        XCTAssertTrue(item.waitForNonExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.4)
    }
    /// Options now lives in the stable content header, outside native toolbar overflow.
    private func openOptions(_ app: XCUIApplication) {
        let options = app.buttons["feed-options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5)); options.tap()
    }
    /// Slow press-drags from mid-screen until the element's top reaches `y`, without deceleration.
    private func drag(_ app: XCUIApplication, _ element: XCUIElement, toY y: CGFloat) {
        scrollUntilHittable(app, element)
        // Gestures start inside the feed list: on a wide split view the detail pane would take them instead.
        let feed = feedList(app), height = feed.frame.height
        let origin = feed.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<6 {
            let delta = y - element.frame.minY
            // A press-drag shorter than this lands as a tap on the card under the start point.
            if abs(delta) < 12 { break }
            let step = max(-height * 0.35, min(height * 0.35, delta))
            let startY = step < 0 ? height * 0.7 : height * 0.3
            origin.withOffset(CGVector(dx: feed.frame.width / 2, dy: startY))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: feed.frame.width / 2, dy: startY + step)), withVelocity: .slow, thenHoldForDuration: 0.5)
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
    private func feedList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed-")).firstMatch
    }
    /// Compact width pushes the discussion and offers Back; a two-pane split view already shows the list.
    private func returnToTopicList(_ app: XCUIApplication) {
        let back = app.buttons["back-to-topic-list"]
        if back.waitForExistence(timeout: 2) { back.tap() }
    }
    private func scrollToTop(_ app: XCUIApplication) {
        var attempts = 0
        let first = app.buttons["topic-4190"]
        let top = app.descendants(matching: .any).matching(identifier: "browse-header").firstMatch.frame.maxY
        // Frame only: isHittable fails outright while the first row is scrolled out of the viewport.
        while !(first.exists && first.frame.minY >= top) && attempts < 15 { feedList(app).swipeDown(velocity: .fast); attempts += 1 }
        // Pulling at the top reveals the new search field; keep the appearance journey on the feed.
        if app.buttons["cancel-topic-search"].exists { app.buttons["cancel-topic-search"].tap() }
        Thread.sleep(forTimeInterval: 1)
    }
    private func loadSecondPage(_ app: XCUIApplication) {
        let more = app.buttons["More discussions"]
        scrollUntilHittable(app, more); more.tap()
        XCTAssertTrue(app.buttons["topic-5005"].waitForExistence(timeout: 5))
        scrollToTop(app)
    }
    private func scrollUntilHittable(_ app: XCUIApplication, _ element: XCUIElement) {
        // In two panes the list scrolls under its floating tabs and header, where XCUITest still reports
        // an element as hittable but a tap at its centre would reach the tab or header control instead.
        let tabs = app.descendants(matching: .any).matching(identifier: "list-tab-bar").firstMatch
        let header = app.descendants(matching: .any).matching(identifier: "browse-header").firstMatch
        func above() -> Bool { tabs.exists && header.exists && element.exists && element.frame.midY <= header.frame.maxY }
        func reachable() -> Bool {
            guard element.exists else { return false }
            if tabs.exists && header.exists && !(header.frame.maxY..<tabs.frame.minY).contains(element.frame.midY) { return false }
            return element.isHittable
        }
        var attempts = 0
        while !reachable() && attempts < 16 {
            if tabs.exists {
                // Short drags without momentum, so a tall card can't jump from below the tabs to under the header.
                let list = feedList(app), centre = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                centre.press(forDuration: 0.05, thenDragTo: centre.withOffset(CGVector(dx: 0, dy: above() ? 160 : -160)), withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                feedList(app).swipeUp(velocity: .slow)
            }
            attempts += 1
        }
        XCTAssertTrue(reachable(), "\(element) not reachable")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
