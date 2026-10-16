import XCTest

/// Interface language and core navigation against the LIVE site (no fixture), anonymous reads only.
/// Opt-in: `TEST_RUNNER_FOMIO_LIVE_UI_TESTS=1`. Each test uses its own storage namespace, so it starts as a fresh
/// install for interface language and catalog cache. Live non-English selection is not covered here: the site
/// offers only English until another language is approved for `fomio_app_locales`.
@MainActor final class LiveLocalizationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["FOMIO_LIVE_UI_TESTS"] == "1" else { throw XCTSkip("Live UI reads require explicit opt-in") }
        MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait }
    }

    private func launch(_ arguments: [String], namespace: String, system: String = "en", keepPreferences: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--live", "--ui-testing"] + arguments + (keepPreferences ? ["--keep-preferences"] : [])
            + ["-AppleLanguages", "(\(system))", "-AppleLocale", system == "ar" ? "ar_SA" : "en_US"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = namespace
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement { app.buttons.matching(identifier: label).firstMatch }
    private func firstTopic(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "topic-[0-9]+")).firstMatch
    }
    /// English interface: English tab names, none of the Arabic ones.
    private func assertEnglish(_ app: XCUIApplication, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: timeout), "English Home tab", file: file, line: line)
        XCTAssertTrue(tab(app, "Me").exists, file: file, line: line)
        XCTAssertFalse(tab(app, "الصفحة الرئيسية").exists, "no Arabic interface", file: file, line: line)
        XCTAssertLessThan(tab(app, "Home").frame.midX, tab(app, "Me").frame.midX, "tabs run left to right", file: file, line: line)
    }
    /// Opens Me › Language and waits for the live list (English always; other rows only if the site offers them).
    private func openLanguage(_ app: XCUIApplication) {
        tab(app, "Me").tap()
        let row = app.buttons["language-en"]
        if !row.waitForExistence(timeout: 3) { app.buttons["me-language"].tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
    }

    func testLiveFreshInstallOnArabicDeviceIsEnglishAndEnglishChoicePersistsAndSurvivesOfflineCatalog() {
        let namespace = UUID().uuidString
        let app = launch(["--l10n-reset"], namespace: namespace, system: "ar")
        assertEnglish(app)
        XCTAssertTrue(firstTopic(app).waitForExistence(timeout: 20), "live feed loaded")
        capture(app, "Live 1 Arabic iOS fresh install: English Home")
        openLanguage(app)
        XCTAssertTrue(app.buttons["language-en"].isSelected, "English is the default choice")
        XCTAssertFalse(app.buttons["language-ar"].exists, "Arabic is not offered by the live allowlist")
        XCTAssertFalse(app.buttons["language-system"].exists, "no device-language row")
        capture(app, "Live 2 Me › Language: English from the live index")
        app.buttons["language-en"].tap()
        XCTAssertTrue(app.buttons["language-en"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language-en"].isSelected)
        XCTAssertFalse(app.otherElements["language-failed"].exists)
        assertEnglish(app, timeout: 5)
        app.terminate()

        // Relaunch online: the choice and English persist.
        let again = launch([], namespace: namespace, system: "ar", keepPreferences: true)
        assertEnglish(again)
        openLanguage(again)
        XCTAssertTrue(again.buttons["language-en"].isSelected)
        again.terminate()

        // Relaunch with catalog requests failing: the cached live catalog (or bundled English) is shown, no failure.
        let offline = launch(["--l10n-offline"], namespace: namespace, system: "ar", keepPreferences: true)
        assertEnglish(offline)
        openLanguage(offline)
        XCTAssertTrue(offline.buttons["language-en"].isSelected)
        capture(offline, "Live 3 Relaunch with catalog requests offline: English kept")
    }

    func testLiveColdStartWithoutAnyCatalogFallsBackToBundledEnglishOnEnglishDevice() {
        let app = launch(["--l10n-reset", "--l10n-offline"], namespace: UUID().uuidString, system: "en")
        assertEnglish(app)
        XCTAssertTrue(firstTopic(app).waitForExistence(timeout: 20))
        openLanguage(app)
        XCTAssertTrue(app.buttons["language-en"].isSelected)
        capture(app, "Live 4 English iOS, no cache, catalog offline: bundled English")
    }

    func testLiveBackSwipeAnchorsAndFeedAppearancePersistence() {
        let namespace = UUID().uuidString
        let app = launch(["--l10n-reset"], namespace: namespace)
        assertEnglish(app)
        let topic = firstTopic(app)
        XCTAssertTrue(topic.waitForExistence(timeout: 20))
        let identifier = topic.identifier, anchor = topic.frame.minY
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 20))
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertLessThan(back.frame.midX, app.windows.firstMatch.frame.width / 2, "Back on the left")
        capture(app, "Live 5 Live discussion with native Back")
        back.tap()
        let same = app.buttons[identifier]
        XCTAssertTrue(same.waitForExistence(timeout: 10))
        XCTAssertLessThan(abs(same.frame.minY - anchor), 4, "tap Back returns to the same position")
        same.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 20))
        let window = app.windows.firstMatch, origin = window.coordinate(withNormalizedOffset: .zero)
        let y = window.frame.height * 0.55, width = window.frame.width
        origin.withOffset(CGVector(dx: 2, dy: y)).press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: width * 0.85, dy: y)), withVelocity: .default, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["discussion-reply"].waitForNonExistence(timeout: 5), "edge swipe pops")
        XCTAssertTrue(same.waitForExistence(timeout: 10))
        XCTAssertLessThan(abs(same.frame.minY - anchor), 4, "swipe Back returns to the same position")

        // Cards, then relaunch: the appearance persists.
        app.buttons["feed-options"].tap()
        let cards = app.buttons["Cards"]; XCTAssertTrue(cards.waitForExistence(timeout: 5)); cards.tap()
        XCTAssertTrue(app.scrollViews["feed-cards"].waitForExistence(timeout: 10))
        capture(app, "Live 6 Live feed in Cards")
        app.terminate()
        let again = launch([], namespace: namespace, keepPreferences: true)
        XCTAssertTrue(again.scrollViews["feed-cards"].waitForExistence(timeout: 20), "Cards persisted across relaunch")
        again.buttons["feed-options"].tap()
        let compact = again.buttons["Compact"]; XCTAssertTrue(compact.waitForExistence(timeout: 5)); compact.tap()
        XCTAssertTrue(again.scrollViews["feed-compact"].waitForExistence(timeout: 10))
    }
}
