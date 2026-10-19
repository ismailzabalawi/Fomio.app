import XCTest

/// Compact/Cards feed appearance: menu, persistence, reading-position anchor, Back, pagination and card cases.
/// Uses fictional fixture content (`--card-cases`) only.
@MainActor final class FeedAppearanceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }

    func testMenuSwitchesBothWaysAndPersistsAcrossRelaunch() {
        var app = launch()
        XCTAssertTrue(app.scrollViews["feed-compact"].exists, "Compact is the default")
        XCTAssertTrue(app.buttons["Search discussions"].exists); XCTAssertTrue(app.buttons["New discussion"].exists)
        openOptions(app)
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
        let top = app.navigationBars.firstMatch.frame.maxY
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
        let top = app.navigationBars.firstMatch.frame.maxY
        let topic = app.buttons["topic-5002"]
        drag(app, topic, toY: top + 160)
        let before = topic.frame.minY
        let category = app.buttons["topic-category-8"]
        XCTAssertTrue(category.isHittable); XCTAssertGreaterThanOrEqual(category.frame.height, 44)
        category.tap()
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["feed-cards"].exists, "Category feeds use the same appearance")
        capture(app, "Category feed in Cards")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(topic.frame.minY - before), 3, "Category Back restores the Home reading position")
        topic.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
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
        app.buttons["Try again"].tap()
        let loaded = app.buttons["topic-4182"]
        scrollUntilHittable(app, loaded)
        choose(app, "Compact")
        XCTAssertTrue(loaded.exists, "Second page retained after switching")
        XCTAssertFalse(failure.exists)
        loaded.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
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
        // The image request starts when the card appears; its failure is asynchronous, so wait for the fallback.
        let fallback = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label CONTAINS 'Has image')"), object: failed)
        XCTAssertEqual(XCTWaiter.wait(for: [fallback], timeout: 10), .completed, "Failed media falls back to text")
        // Toolbar controls are system glass items; the options button matches the system Search control.
        XCTAssertEqual(app.buttons["feed-options"].frame.height, app.buttons["Search discussions"].frame.height)
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
                drag(app, app.buttons["topic-5001"], toY: app.navigationBars.firstMatch.frame.maxY + 20)
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
    /// The system may move toolbar items into its More overflow (regular-width iPad with accessibility text).
    private func openOptions(_ app: XCUIApplication) {
        let options = app.buttons["feed-options"]
        if options.exists && options.isHittable { options.tap(); return }
        let overflow = app.buttons["OverflowBarButtonItem"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 3), "Options are neither visible nor in the overflow")
        overflow.tap()
        let item = app.buttons["Home options"]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "Overflowed options keep their name"); item.tap()
    }
    /// Slow press-drags from mid-screen until the element's top reaches `y`, without deceleration.
    private func drag(_ app: XCUIApplication, _ element: XCUIElement, toY y: CGFloat) {
        scrollUntilHittable(app, element)
        let window = app.windows.firstMatch, height = window.frame.height
        let origin = window.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<6 {
            let delta = y - element.frame.minY
            if abs(delta) < 2 { break }
            let step = max(-height * 0.35, min(height * 0.35, delta))
            let startY = step < 0 ? height * 0.7 : height * 0.3
            origin.withOffset(CGVector(dx: window.frame.width / 2, dy: startY))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: window.frame.width / 2, dy: startY + step)), withVelocity: .slow, thenHoldForDuration: 0.5)
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
    private func scrollToTop(_ app: XCUIApplication) {
        var attempts = 0
        while !app.staticTexts["Latest"].isHittable && attempts < 15 { app.swipeDown(velocity: .fast); attempts += 1 }
        Thread.sleep(forTimeInterval: 1)
    }
    private func loadSecondPage(_ app: XCUIApplication) {
        let more = app.buttons["More discussions"]
        scrollUntilHittable(app, more); more.tap()
        XCTAssertTrue(app.buttons["topic-5005"].waitForExistence(timeout: 5))
        scrollToTop(app)
    }
    private func scrollUntilHittable(_ app: XCUIApplication, _ element: XCUIElement) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 12 { app.swipeUp(velocity: .slow); attempts += 1 }
        XCTAssertTrue(element.exists && element.isHittable, "\(element) not reachable")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
