import XCTest

/// UI regressions for the 2026-10-15 independent review of 6162c57. Fixture content and fixture catalogs only.
@MainActor final class ReviewFixesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }

    /// `systemArabic` launches the app with Arabic as its iOS language (the reverse of the English simulators).
    private func launch(_ arguments: [String], systemArabic: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments + (systemArabic ? ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"] : [])
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement { app.buttons.matching(identifier: label).firstMatch }
    private func wait(_ element: XCUIElement, label predicate: String, _ value: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label \(predicate) %@", value), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(element.identifier): label \(predicate) \(value) — \(element.label)", file: file, line: line)
    }
    private func pullToRefresh(_ app: XCUIApplication, from element: XCUIElement, heading: String = "Latest") {
        // Pull-to-refresh only starts at the top; an appearance switch keeps the reading anchor further down.
        var attempts = 0
        while !app.staticTexts[heading].isHittable && attempts < 10 { app.swipeDown(velocity: .fast); attempts += 1 }
        // The refresh threshold grows with screen height; a fixed distance is too short on iPad.
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: max(0.2, element.frame.minY / window.frame.height)))
        start.press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)), withVelocity: .slow, thenHoldForDuration: 0.5)
    }
    private func selectLanguage(_ app: XCUIApplication, me: String, code: String) {
        tab(app, me).tap(); app.buttons["me-language"].tap()
        let row = app.buttons["language-\(code)"]; XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    }
    /// Large text can move the options item into the system overflow menu (regular-width iPad).
    private func openOptions(_ app: XCUIApplication, overflowLabel: String) {
        let options = app.buttons["feed-options"]
        if options.waitForExistence(timeout: 3) && options.isHittable { options.tap(); return }
        app.buttons["OverflowBarButtonItem"].tap()
        let item = app.buttons[overflowLabel]; XCTAssertTrue(item.waitForExistence(timeout: 3)); item.tap()
    }
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons["BackButton"]
        if button.waitForExistence(timeout: 3) { button.tap() } else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }
    /// Opens a quote reply; the quote becomes a UIKit attachment card with Edit and Remove controls.
    private func openQuoteComposer(_ app: XCUIApplication, quoteLabel: String) {
        let topic = app.buttons["topic-4190"]; XCTAssertTrue(topic.waitForExistence(timeout: 8)); topic.tap()
        let quote = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", quoteLabel)).firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 5)); quote.tap()
        XCTAssertTrue(app.buttons["composer-block-edit-quote"].waitForExistence(timeout: 8))
    }
    /// App-owned UIKit card: Edit leads Remove in the interface direction.
    private func assertCardDirection(_ app: XCUIApplication, remove: String, rightToLeft: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let edit = app.buttons["composer-block-edit-quote"].frame, removeFrame = app.buttons[remove].firstMatch.frame
        if rightToLeft { XCTAssertGreaterThan(edit.midX, removeFrame.midX, "card controls not mirrored", file: file, line: line) }
        else { XCTAssertLessThan(edit.midX, removeFrame.midX, "card controls mirrored in a left-to-right interface", file: file, line: line) }
    }
    private func closeComposer(_ app: XCUIApplication, discard: String) {
        app.buttons["composer-close"].tap()
        let button = app.buttons[discard].firstMatch
        if button.waitForExistence(timeout: 3) { button.tap() }
        XCTAssertTrue(app.buttons["composer-close"].waitForNonExistence(timeout: 5))
    }

    // MARK: 1. Retained error follows the language without refetching

    func testRetainedFeedErrorFollowsLanguageWithoutRefetch() {
        let app = launch(["--feed-fails-once"])
        XCTAssertTrue(app.staticTexts["Discussions unavailable"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["You’re offline. Your writing is kept on this device."].exists)
        capture(app, "1a English feed failure")
        selectLanguage(app, me: "Me", code: "ar")
        XCTAssertTrue(tab(app, "الصفحة الرئيسية").waitForExistence(timeout: 10))
        tab(app, "الصفحة الرئيسية").tap()
        XCTAssertTrue(app.staticTexts["النقاشات غير متاحة"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["أنت غير متصل. كتابتك محفوظة على هذا الجهاز."].exists, "retained app error renders in Arabic")
        XCTAssertFalse(app.staticTexts["You’re offline. Your writing is kept on this device."].exists)
        XCTAssertFalse(app.buttons["topic-4190"].exists, "returning Home did not refetch")
        capture(app, "1b Same retained error after switching to Arabic, no refetch")
        app.buttons["حاول مجددًا"].tap()
        XCTAssertTrue(app.buttons["topic-4190"].waitForExistence(timeout: 8), "explicit retry loads")
        capture(app, "1c Explicit retry loads the feed")
    }

    // MARK: 2. Explicit UIKit direction on an Arabic-language device

    func testArabicSystemLanguageColdEnglishFallbackKeepsAppUIKitLeftToRight() {
        let app = launch(["--l10n-offline", "--l10n-reset", "--language", "system"], systemArabic: true)
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10), "cold offline: bundled English")
        XCTAssertLessThan(tab(app, "Home").frame.midX, tab(app, "Me").frame.midX, "English tabs run left to right on an Arabic device")
        capture(app, "2a Arabic iOS language, cold offline English fallback")
        openQuoteComposer(app, quoteLabel: "Quote ")
        assertCardDirection(app, remove: "Remove", rightToLeft: false)
        capture(app, "2b English composer quote card, Arabic iOS language")
        app.buttons["composer-more"].tap(); Thread.sleep(forTimeInterval: 0.8)
        capture(app, "2c English More menu, Arabic iOS language")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        closeComposer(app, discard: "Discard")
    }

    func testArabicSystemLanguageSwitchArabicToEnglishRestoresAppUIKitDirection() {
        let app = launch(["--language", "ar"], systemArabic: true)
        XCTAssertTrue(tab(app, "الصفحة الرئيسية").waitForExistence(timeout: 10))
        XCTAssertGreaterThan(tab(app, "الصفحة الرئيسية").frame.midX, tab(app, "أنا").frame.midX)
        openQuoteComposer(app, quoteLabel: "اقتباس مشاركة")
        assertCardDirection(app, remove: "إزالة", rightToLeft: true)
        app.buttons["composer-more"].tap(); Thread.sleep(forTimeInterval: 0.8)
        capture(app, "2d Arabic More menu, Arabic iOS language")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        closeComposer(app, discard: "تجاهل")
        back(app)
        selectLanguage(app, me: "أنا", code: "en")
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        XCTAssertLessThan(tab(app, "Home").frame.midX, tab(app, "Me").frame.midX, "English restores left-to-right on an Arabic device")
        tab(app, "Home").tap()
        openQuoteComposer(app, quoteLabel: "Quote ")
        assertCardDirection(app, remove: "Remove", rightToLeft: false)
        app.buttons["composer-more"].tap(); Thread.sleep(forTimeInterval: 0.8)
        capture(app, "2e English More menu after Arabic → English, Arabic iOS language")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        closeComposer(app, discard: "Discard")
    }

    // MARK: 3. Media recovery: same source after refresh, and replaced source

    /// Actual image requests per fixture file, counted by the Debug fixture media server.
    private func mediaRequests(_ app: XCUIApplication) -> [String: Int] {
        let label = app.staticTexts["fixture-media-requests"].firstMatch.label
        return Dictionary(uniqueKeysWithValues: label.split(separator: ";").compactMap { pair -> (String, Int)? in
            let parts = pair.split(separator: "="); guard parts.count == 2, let n = Int(parts[1]) else { return nil }
            return (String(parts[0]), n)
        })
    }
    private func waitForRequests(_ app: XCUIApplication, _ expected: [String: Int], file: StaticString = #filePath, line: UInt = #line) {
        let readout = app.staticTexts["fixture-media-requests"].firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 5), file: file, line: line)
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline && mediaRequests(app) != expected { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertEqual(mediaRequests(app), expected, file: file, line: line)
    }

    func testFailedMediaRecoversAfterRefreshAndReplacementInCompactThenCards() {
        let app = launch(["--media-recovery"])
        let restored = app.buttons["topic-5006"], replaced = app.buttons["topic-5007"]
        XCTAssertTrue(restored.waitForExistence(timeout: 8))
        wait(restored, label: "CONTAINS", "started by theo"); wait(replaced, label: "CONTAINS", "started by mara_k")
        wait(restored, label: "ENDSWITH", "ago"); wait(replaced, label: "ENDSWITH", "ago")
        // One request each, both fail; the failed sources are not retried on their own.
        waitForRequests(app, ["missing-original.jpg": 1, "restored.jpg": 1])
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(mediaRequests(app), ["missing-original.jpg": 1, "restored.jpg": 1], "no automatic retry loop")
        XCTAssertFalse(restored.label.contains("Has image"), "failed media falls back to text")
        XCTAssertFalse(replaced.label.contains("Has image"))
        capture(app, "3a Compact: both images failed, text only")
        pullToRefresh(app, from: restored)
        wait(restored, label: "CONTAINS", "Has image"); wait(replaced, label: "CONTAINS", "Has image")
        // The failed same source is retried once; the replacement is loaded once; the old URL is not requested again.
        waitForRequests(app, ["missing-original.jpg": 1, "restored.jpg": 2, "replacement.jpg": 1])
        capture(app, "3b Compact: restored source and replacement both shown after refresh")
        // A later refresh keeps both recovered images: no new load attempt for either.
        pullToRefresh(app, from: restored)
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertEqual(mediaRequests(app), ["missing-original.jpg": 1, "restored.jpg": 2, "replacement.jpg": 1], "recovered images are not reloaded by a later refresh")
        XCTAssertTrue(restored.label.contains("Has image") && replaced.label.contains("Has image"))
        capture(app, "3b2 Compact: second refresh, no reload")
        // Cards use a different (wide) media view; it may load each image at most once for the new layout.
        openOptions(app, overflowLabel: "Home options"); app.buttons["Cards"].tap()
        XCTAssertTrue(app.scrollViews["feed-cards"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        let switched = mediaRequests(app)
        XCTAssertEqual(switched["missing-original.jpg"], 1)
        XCTAssertTrue((2...3).contains(switched["restored.jpg"] ?? 0) && (1...2).contains(switched["replacement.jpg"] ?? 0), "\(switched)")
        XCTAssertTrue(restored.label.contains("Has image") && replaced.label.contains("Has image"))
        capture(app, "3c Cards: recovered media kept after appearance switch")
        let afterSwitch = mediaRequests(app)
        replaced.tap(); XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        back(app)
        XCTAssertTrue(app.scrollViews["feed-cards"].waitForExistence(timeout: 5))
        XCTAssertTrue(restored.label.contains("Has image"), "Back keeps recovered media")
        pullToRefresh(app, from: restored)
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(restored.label.contains("Has image") && replaced.label.contains("Has image"), "a refresh of loaded media keeps it")
        XCTAssertEqual(mediaRequests(app), afterSwitch, "Back and another refresh request nothing again")
        capture(app, "3d Cards after Back and a second refresh")
    }

    func testMediaRecoveryInArabicCardsWithAccessibilityText() {
        let app = launch(["--media-recovery", "--language", "ar", "--accessibility-text"])
        let restored = app.buttons["topic-5006"], replaced = app.buttons["topic-5007"]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        wait(restored, label: "CONTAINS", "بدأه")
        openOptions(app, overflowLabel: "خيارات الصفحة الرئيسية"); app.buttons["بطاقات"].tap()
        XCTAssertTrue(app.scrollViews["feed-cards"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(restored.label.contains("يحتوي على صورة")); XCTAssertFalse(replaced.label.contains("يحتوي على صورة"))
        capture(app, "3e Arabic Cards, accessibility text: failed media text only")
        pullToRefresh(app, from: restored, heading: "الحديثة")
        wait(restored, label: "CONTAINS", "يحتوي على صورة"); wait(replaced, label: "CONTAINS", "يحتوي على صورة")
        capture(app, "3f Arabic Cards, accessibility text: media recovered after refresh")
    }
}
