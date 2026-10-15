import XCTest

/// Interface language journeys against the Debug fixture catalog transport. Fixture catalogs stand in for the
/// proposed backend endpoint; they are not evidence that a deployed endpoint exists.
@MainActor final class LocalizationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String], namespace: String = UUID().uuidString, keepPreferences: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments + (keepPreferences ? ["--keep-preferences"] : [])
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = namespace
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement { app.buttons.matching(identifier: label).firstMatch }
    private func waitForArabic(_ app: XCUIApplication, timeout: TimeInterval = 10) {
        // Home is always on the first tab-bar page (large text paginates the iPad top tab bar).
        XCTAssertTrue(tab(app, "الصفحة الرئيسية").waitForExistence(timeout: timeout), "Arabic catalog did not activate")
    }
    /// In a right-to-left interface the first tab (Home) sits on the trailing (right) side.
    private func assertRightToLeftTabs(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let home = tab(app, "الصفحة الرئيسية").frame, me = tab(app, "أنا").frame
        XCTAssertGreaterThan(home.midX, me.midX, "tabs are not mirrored", file: file, line: line)
    }
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons["BackButton"]
        if button.waitForExistence(timeout: 3) { button.tap() } else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }
    /// Feeds are lazy; scroll until a topic further down has been created.
    private func reveal(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5), identifier)
        return element
    }

    func testSwitchingLanguageKeepsNavigationDraftsAndMirrorsLayout() {
        let app = launch([])
        XCTAssertTrue(tab(app, "Communities").waitForExistence(timeout: 10))
        let home = tab(app, "Home"), me = tab(app, "Me")
        XCTAssertGreaterThan(me.frame.midX, home.frame.midX, "English tabs run left to right")
        // Leave state behind in two tabs: a pushed community and a pushed discussion with a kept reply draft.
        tab(app, "Communities").tap(); app.buttons["community-4"].tap()
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        home.tap(); app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Kept across languages")
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))

        me.tap(); app.buttons["me-language"].tap()
        XCTAssertTrue(app.buttons["language-system"].waitForExistence(timeout: 5))
        let arabic = app.buttons["language-ar"]; XCTAssertTrue(arabic.waitForExistence(timeout: 5))
        capture(app, "Language screen, English")
        arabic.tap()
        waitForArabic(app)
        XCTAssertTrue(app.buttons["language-ar"].isSelected)
        assertRightToLeftTabs(app)
        capture(app, "Language screen after switching to Arabic")

        tab(app, "المجتمعات").tap()
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5), "community stack kept")
        XCTAssertTrue(app.buttons["community-about"].label.contains("نبذة"))
        capture(app, "Community feed kept after language change, Arabic")
        tab(app, "الصفحة الرئيسية").tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5), "discussion stack kept")
        XCTAssertEqual(app.buttons["discussion-reply"].label.contains("الرد على"), true)
        capture(app, "Discussion kept after language change, Arabic RTL")

        tab(app, "أنا").tap(); back(app)
        XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap()
        XCTAssertTrue(app.staticTexts["Kept across languages"].waitForExistence(timeout: 5), "draft survives the switch")
        capture(app, "Drafts, Arabic")
        back(app); app.buttons["me-language"].tap(); app.buttons["language-en"].tap()
        XCTAssertTrue(tab(app, "Me").waitForExistence(timeout: 5))
        XCTAssertGreaterThan(tab(app, "Me").frame.midX, tab(app, "Home").frame.midX)
    }

    func testWarmOfflineLaunchUsesCachedArabicImmediately() {
        let namespace = UUID().uuidString
        let first = launch(["--language", "ar"], namespace: namespace)
        waitForArabic(first)
        first.terminate()
        let app = launch(["--l10n-offline"], namespace: namespace, keepPreferences: true)
        // The fixture transport is offline; Arabic can only come from the validated cache.
        waitForArabic(app, timeout: 3)
        assertRightToLeftTabs(app)
        capture(app, "Warm offline launch from cached Arabic")
    }

    func testColdOfflineFirstLaunchShowsCompleteEnglish() {
        let app = launch(["--language", "ar", "--l10n-offline"])
        XCTAssertTrue(tab(app, "Me").waitForExistence(timeout: 10))
        XCTAssertFalse(tab(app, "أنا").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Latest"].exists)
        tab(app, "Me").tap(); app.buttons["me-language"].tap()
        XCTAssertTrue(app.otherElements["language-pending"].waitForExistence(timeout: 5) || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hasn’t downloaded yet")).firstMatch.exists)
        capture(app, "Cold offline launch: English with Arabic pending")
    }

    func testIncompleteServerCatalogIsRejectedAndEnglishRemains() {
        let app = launch(["--language", "ar", "--l10n-incomplete-ar"])
        XCTAssertTrue(tab(app, "Me").waitForExistence(timeout: 10))
        XCTAssertFalse(tab(app, "أنا").waitForExistence(timeout: 4), "a partial catalog must never activate")
        capture(app, "Incomplete Arabic response rejected")
    }

    func testChangedSiteOverrideAppearsAfterRefresh() {
        let app = launch(["--l10n-changed-override"])
        // The server's English revision renames Home; the fresh install refreshes on launch.
        XCTAssertTrue(tab(app, "Home feed").waitForExistence(timeout: 10))
        capture(app, "English site override revision applied")
    }

    func testArabicPrimaryScreensComposerAndAccessibility() {
        let app = launch(["--language", "ar", "--card-cases"])
        waitForArabic(app)
        assertRightToLeftTabs(app)
        XCTAssertTrue(app.staticTexts["الحديثة"].waitForExistence(timeout: 5))
        capture(app, "Home with pinned, Arabic-titled and long topics, Arabic UI")
        let topic = reveal(app, "topic-4190")
        XCTAssertTrue(topic.label.contains("بدأه"), topic.label)
        capture(app, "Home further down, Arabic")

        tab(app, "المجتمعات").tap(); XCTAssertTrue(app.buttons["community-4"].waitForExistence(timeout: 5))
        capture(app, "Communities, Arabic")
        app.buttons["community-4"].tap(); XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        capture(app, "Community feed, Arabic")
        app.buttons["community-about"].tap(); XCTAssertTrue(app.buttons["تم"].waitForExistence(timeout: 5))
        capture(app, "Community About, Arabic"); app.buttons["تم"].tap()

        tab(app, "الصفحة الرئيسية").tap(); reveal(app, "topic-4190").tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        capture(app, "Discussion, Arabic")
        app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertEqual(body.label, "نص الرد")
        XCTAssertEqual(app.buttons["composer-post"].label, "نشر")
        body.tap(); body.typeText("شكرًا devon، the 2A fuse is fine")
        capture(app, "Reply composer, mixed Arabic and English text")
        app.buttons["composer-more"].tap(); capture(app, "Composer More menu, Arabic")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        app.buttons["composer-close"].tap(); XCTAssertTrue(app.buttons["الاحتفاظ بالمسودة"].waitForExistence(timeout: 5)); app.buttons["الاحتفاظ بالمسودة"].tap()

        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5)); back(app)
        app.buttons["ابحث في النقاشات"].firstMatch.tap()
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("oak\n")
        XCTAssertTrue(app.staticTexts["النقاشات"].waitForExistence(timeout: 5))
        capture(app, "Search results, Arabic")

        tab(app, "الإشعارات").tap(); XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ردّ عليك")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Notifications, Arabic")
        tab(app, "أنا").tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5))
        capture(app, "Me, Arabic")

        // Re-selecting the tab returns its stack to the root (search is still active there).
        tab(app, "الصفحة الرئيسية").tap(); tab(app, "الصفحة الرئيسية").tap()
        let create = app.buttons["نقاش جديد"].firstMatch; XCTAssertTrue(create.waitForExistence(timeout: 5)); create.tap()
        XCTAssertTrue(app.buttons["composer-destination"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["composer-title"].label, "العنوان")
        capture(app, "New discussion composer, Arabic")
        app.buttons["composer-insert"].tap(); XCTAssertTrue(app.buttons["composer-insert-cancel"].waitForExistence(timeout: 5))
        capture(app, "Add block, Arabic"); app.buttons["composer-insert-cancel"].tap()
    }

    func testArabicAccessibilityTextSizesKeepControlsReachable() {
        let app = launch(["--language", "ar", "--accessibility-text", "--card-cases"])
        waitForArabic(app)
        capture(app, "Home, Arabic, accessibility text")
        reveal(app, "topic-4190").tap(); XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        capture(app, "Discussion, Arabic, accessibility text")
        app.buttons["discussion-reply"].tap()
        XCTAssertTrue(app.buttons["composer-post"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["composer-post"].isHittable)
        XCTAssertTrue(app.buttons["composer-close"].isHittable)
        capture(app, "Composer, Arabic, accessibility text")
    }
}
