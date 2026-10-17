import XCTest

/// Ignored-author previews in feeds, search and notifications, and Arabic safety copy. Fixture outcomes only.
@MainActor final class SafetyPreviewUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    func testFeedCardCollapsesIgnoredAuthorPreviewUntilShowOnce() {
        let app = launch(["--ignored", "devon"])
        let hidden = element(app, "topic-hidden-4190"); XCTAssertTrue(hidden.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["topic-4190"].exists, "Title and discussion target stay")
        XCTAssertFalse(element(app, "topic-hidden-4182").exists, "Other authors are unaffected")
        capture(app, "Feed card from ignored author")
        hidden.buttons["Show once"].tap()
        XCTAssertTrue(hidden.waitForNonExistence(timeout: 5))
    }

    func testSearchSnippetFromIgnoredMatchAuthorIsCollapsed() {
        let app = launch(["--ignored", "mara_k", "--preset", "search"])
        let hidden = element(app, "search-hidden-4182"); XCTAssertTrue(hidden.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["topic-4182"].exists)
        capture(app, "Search match from ignored author")
        hidden.buttons["Show once"].tap()
        XCTAssertTrue(hidden.waitForNonExistence(timeout: 5))
    }

    func testNotificationFromIgnoredActorIsCollapsed() {
        let app = launch(["--ignored", "devon", "--preset", "notifications"])
        let hidden = element(app, "notice-hidden-1"); XCTAssertTrue(hidden.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "priya mentioned you")).firstMatch.exists)
        capture(app, "Notification from ignored actor")
        hidden.buttons["Show once"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "devon replied to you")).firstMatch.waitForExistence(timeout: 5))
    }

    func testArabicReportSheetUsesTranslatedCopy() {
        let app = launch(["--preset", "report", "-AppleLanguages", "(ar)", "-AppleLocale", "ar"])
        let send = app.buttons["report-send"]; XCTAssertTrue(send.waitForExistence(timeout: 10))
        XCTAssertEqual(send.label, "إرسال البلاغ")
        // Formatted arguments are wrapped in bidi isolate marks, so match the fixed text and the localized noun separately.
        let question = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "لماذا تبلّغ عن هذا", "الرد")).firstMatch
        XCTAssertTrue(question.exists)
        capture(app, "Arabic report sheet")
    }
}
