import XCTest

/// Interface language journeys against the Debug fixture catalog transport. Fixture catalogs stand in for the
/// proposed backend endpoint; they are not evidence that a deployed endpoint exists.
@MainActor final class LocalizationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String], namespace: String = UUID().uuidString, keepPreferences: Bool = false, systemArabic: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments + (keepPreferences ? ["--keep-preferences"] : [])
            + (systemArabic ? ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"] : [])
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = namespace
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
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
        select(app, tab: "Communities"); app.buttons["community-4"].tap()
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        select(app, tab: "Home"); app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Kept across languages")
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))

        select(app, tab: "Me"); app.buttons["me-language"].tap()
        let arabic = app.buttons["language-ar"]; XCTAssertTrue(arabic.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language-en"].isSelected, "English is the default choice")
        XCTAssertFalse(app.buttons["language-system"].exists, "no implicit device-language row")
        capture(app, "Language screen, English")
        arabic.tap()
        waitForArabic(app)
        XCTAssertTrue(app.buttons["language-ar"].isSelected)
        assertRightToLeftTabs(app)
        capture(app, "Language screen after switching to Arabic")

        select(app, tab: "المجتمعات")
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5), "community stack kept")
        XCTAssertTrue(app.buttons["community-about"].label.contains("نبذة"))
        capture(app, "Community feed kept after language change, Arabic")
        select(app, tab: "الصفحة الرئيسية")
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5), "discussion stack kept")
        XCTAssertEqual(app.buttons["discussion-reply"].label.contains("الرد على"), true)
        capture(app, "Discussion kept after language change, Arabic RTL")

        select(app, tab: "أنا"); back(app)
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
        select(app, tab: "Me"); app.buttons["me-language"].tap()
        XCTAssertTrue(app.otherElements["language-pending"].waitForExistence(timeout: 5) || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hasn’t downloaded yet")).firstMatch.exists)
        capture(app, "Cold offline launch: English with Arabic pending")
    }

    func testIncompleteServerCatalogIsRejectedAndEnglishRemains() {
        let app = launch(["--language", "ar", "--l10n-incomplete-ar"])
        XCTAssertTrue(tab(app, "Me").waitForExistence(timeout: 10))
        XCTAssertFalse(tab(app, "أنا").waitForExistence(timeout: 4), "a partial catalog must never activate")
        capture(app, "Incomplete Arabic response rejected")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement { app.descendants(matching: .any)[identifier].firstMatch }
    private func text(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }
    private func openLanguage(_ app: XCUIApplication, me: String) {
        select(app, tab: me)
        let row = app.buttons["language-en"]
        if !row.waitForExistence(timeout: 2) { app.buttons["me-language"].tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testArabicDeviceFreshInstallStaysEnglishAfterCatalogDiscovery() {
        // Arabic iOS language, a site whose default locale is Arabic, and Arabic offered: still English.
        let namespace = UUID().uuidString
        let app = launch(["--l10n-reset", "--l10n-site-default-ar"], namespace: namespace, systemArabic: true)
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        openLanguage(app, me: "Me")
        XCTAssertTrue(app.buttons["language-ar"].waitForExistence(timeout: 5), "Arabic was discovered")
        XCTAssertTrue(app.buttons["language-en"].isSelected)
        XCTAssertFalse(app.buttons["language-tlh"].exists, "Klingon: no plural rules in this app")
        XCTAssertFalse(app.buttons["language-de"].exists, "German: incomplete")
        XCTAssertTrue(app.buttons["language-he"].exists, "Hebrew: Discourse translations with English fallback")
        XCTAssertTrue(app.buttons["language-he"].label.contains("Partly translated"), "partly translated languages say so")
        XCTAssertFalse(app.buttons["language-ar"].label.contains("Partly translated"), "Arabic is fully translated (overlay)")
        XCTAssertFalse(app.buttons["language-system"].exists)
        XCTAssertFalse(tab(app, "أنا").waitForExistence(timeout: 2), "discovery never switches the language")
        capture(app, "Arabic iOS fresh install: English after catalog discovery")
        app.terminate()
        let again = launch(["--l10n-site-default-ar"], namespace: namespace, keepPreferences: true, systemArabic: true)
        XCTAssertTrue(tab(again, "Home").waitForExistence(timeout: 10))
        XCTAssertFalse(tab(again, "أنا").waitForExistence(timeout: 3), "relaunch after background download stays English")
    }

    func testExplicitSelectionPersistsAcrossRelaunchAndOffline() {
        let namespace = UUID().uuidString
        let app = launch([], namespace: namespace)
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        openLanguage(app, me: "Me")
        app.buttons["language-ar"].tap()
        waitForArabic(app)
        app.terminate()
        let offline = launch(["--l10n-offline"], namespace: namespace, keepPreferences: true)
        waitForArabic(offline, timeout: 3)
        openLanguage(offline, me: "أنا")
        XCTAssertTrue(offline.buttons["language-ar"].isSelected, "the explicit choice persisted")
        capture(offline, "Explicit Arabic choice after relaunch, offline")
    }

    func testFailedSelectionKeepsEnglishAndOffersRetry() {
        let namespace = UUID().uuidString
        let app = launch(["--l10n-incomplete-ar"], namespace: namespace)
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        openLanguage(app, me: "Me")
        app.buttons["language-ar"].tap()
        XCTAssertTrue(element(app, "language-failed").waitForExistence(timeout: 8), "failure is reported")
        XCTAssertTrue(app.buttons["language-en"].isSelected, "the choice is unchanged")
        XCTAssertTrue(tab(app, "Me").exists)
        capture(app, "Incomplete Arabic selection rejected, English kept")
        app.terminate()
        let again = launch(["--l10n-incomplete-ar"], namespace: namespace, keepPreferences: true)
        XCTAssertTrue(tab(again, "Home").waitForExistence(timeout: 10))
        XCTAssertFalse(tab(again, "أنا").waitForExistence(timeout: 3), "a failed selection is not persisted")
    }

    func testRemovedLanguageKeepsCachedCopyAndSaysSo() {
        let namespace = UUID().uuidString
        let first = launch(["--language", "ar"], namespace: namespace)
        waitForArabic(first)
        first.terminate()
        let app = launch(["--l10n-removed-ar"], namespace: namespace, keepPreferences: true)
        waitForArabic(app, timeout: 3)
        openLanguage(app, me: "أنا")
        XCTAssertTrue(text(app, containing: "آخر نسخة").waitForExistence(timeout: 5), "says the last downloaded copy is shown")
        XCTAssertFalse(app.buttons["language-ar"].exists, "a removed language is not offered")
        waitForArabic(app, timeout: 1)
        capture(app, "Removed Arabic: cached copy kept, notice shown")
    }

    func testRemovedLanguageWithoutCacheShowsEnglishAndSaysSo() {
        let app = launch(["--language", "ar", "--l10n-removed-ar", "--l10n-reset"])
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10), "no cache: English")
        openLanguage(app, me: "Me")
        XCTAssertTrue(text(app, containing: "so Fomio shows English").waitForExistence(timeout: 5), "honest English fallback notice")
        XCTAssertFalse(text(app, containing: "last downloaded version").exists)
        XCTAssertFalse(text(app, containing: "hasn’t downloaded yet").exists)
        capture(app, "Removed Arabic without cache: English, notice shown")
    }

    /// A tab whose label contains `text`: English fallback labels in a right-to-left catalog are wrapped in invisible isolates.
    private func tabContaining(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.tabBars.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists
            ? app.tabBars.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            : app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testHebrewMixesDiscourseHebrewWithEnglishFallbackRightToLeftAndSurvivesOfflineRelaunch() {
        let namespace = UUID().uuidString
        let app = launch(["--card-cases"], namespace: namespace)
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        openLanguage(app, me: "Me")
        let hebrew = app.buttons["language-he"]
        XCTAssertTrue(hebrew.label.contains("Partly translated"))
        capture(app, "Language list with partly translated languages")
        hebrew.tap()
        // Discourse's Hebrew for mapped keys, English fallback for Fomio-only keys, right-to-left order.
        let home = tab(app, "בית")
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Hebrew Home (Discourse js.home)")
        let me = tabContaining(app, "Me")
        XCTAssertTrue(me.exists, "English fallback tab")
        XCTAssertTrue(tabContaining(app, "Communities").exists)
        XCTAssertGreaterThan(home.frame.midX, me.frame.midX, "right to left: Home on the right")
        XCTAssertTrue(app.buttons["language-he"].isSelected)
        capture(app, "Hebrew Language screen, mixed Hebrew and English")
        select(app, tab: "בית")
        let topic = app.buttons["topic-5002"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        capture(app, "Hebrew Home feed with English fallback")
        topic.tap()
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(back.frame.midX, app.windows.firstMatch.frame.width / 2, "Back on the right")
        capture(app, "Hebrew discussion, mixed text")
        app.terminate()
        let offline = launch(["--l10n-offline", "--card-cases"], namespace: namespace, keepPreferences: true)
        XCTAssertTrue(tab(offline, "בית").waitForExistence(timeout: 5), "cached Hebrew catalog used offline")
        XCTAssertTrue(tabContaining(offline, "Me").exists)
    }

    func testRussianWithoutOverlayUsesDiscourseTextRussianPluralsAndEnglishFallback() {
        let app = launch(["--card-cases"])
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        openLanguage(app, me: "Me")
        XCTAssertTrue(app.buttons["language-ru"].label.contains("Partly translated"))
        app.buttons["language-ru"].tap()
        let home = tab(app, "Главная")
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Russian Home (Discourse js.home)")
        XCTAssertTrue(tab(app, "Communities").exists, "English fallback, no isolates in a left-to-right catalog")
        XCTAssertLessThan(home.frame.midX, tab(app, "Me").frame.midX, "left to right")
        select(app, tab: "Главная")
        // Discourse's Russian plural forms (js.review.replies): 3 → "ответа" (few), 1 → "ответ" (one).
        let three = app.buttons["topic-5002"], one = app.buttons["topic-5004"]
        XCTAssertTrue(three.waitForExistence(timeout: 10))
        XCTAssertTrue(three.label.contains("3 ответа"), three.label)
        XCTAssertTrue(reveal(app, "topic-5004").label.contains("1 ответ"), one.label)
        // A Fomio-only phrase without a Russian overlay is English.
        XCTAssertTrue(app.buttons["topic-5001"].label.contains("No replies yet"))
        capture(app, "Russian Home feed: Discourse Russian plurals and English fallback")
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

        select(app, tab: "المجتمعات"); XCTAssertTrue(app.buttons["community-4"].waitForExistence(timeout: 5))
        capture(app, "Communities, Arabic")
        app.buttons["community-4"].tap(); XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        capture(app, "Community feed, Arabic")
        app.buttons["community-about"].tap(); XCTAssertTrue(app.buttons["تم"].waitForExistence(timeout: 5))
        capture(app, "Community About, Arabic"); app.buttons["تم"].tap()

        select(app, tab: "الصفحة الرئيسية"); reveal(app, "topic-4190").tap()
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

        select(app, tab: "الإشعارات"); XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ردّ عليك")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Notifications, Arabic")
        select(app, tab: "أنا"); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5))
        capture(app, "Me, Arabic")

        // Re-selecting the tab returns its stack to the root (search is still active there).
        select(app, tab: "الصفحة الرئيسية"); tab(app, "الصفحة الرئيسية").tap()
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
