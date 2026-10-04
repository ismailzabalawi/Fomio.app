import XCTest
import UIKit

@MainActor final class FomioUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    override func tearDown() { MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments.contains("--live") ? arguments : ["--fixture", "--ui-testing"] + arguments; app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        if !arguments.contains("--live") { XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)) }
        return app
    }
    func testNativeFormattingCaretTypingSurvivesSourceSwitch() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Before ")
        app.buttons["composer-more"].tap(); app.buttons["Format"].tap(); app.buttons["Bold"].firstMatch.tap()
        body.typeText("Bold")
        app.buttons["composer-keyboard-done"].tap(); app.buttons["composer-more"].tap(); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "Before **Bold**")
        app.buttons["composer-keyboard-done"].tap(); app.buttons["composer-close"].tap(); app.buttons["Discard"].tap()
    }
    func testNativeBlockFormAndMarkdownRoundTrip() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Writing before code\n")
        app.buttons["composer-keyboard-done"].tap(); app.buttons["composer-more"].tap(); app.buttons["Insert block"].tap(); app.buttons["Code"].tap()
        let code = app.textViews["block-body"]; XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("let greeting = 1")
        app.buttons["block-save"].tap()
        XCTAssertTrue(code.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["composer-more"].tap(); XCTAssertTrue(app.buttons["Edit in Markdown"].waitForExistence(timeout: 5)); app.buttons["Edit in Markdown"].tap()
        XCTAssertTrue((body.value as? String)?.contains("let greeting = 1") == true)
        XCTAssertTrue((body.value as? String)?.contains("```") == true)
        app.buttons["composer-keyboard-done"].tap(); app.buttons["composer-more"].tap(); app.buttons["Rich text"].tap()
        let editBlock = app.buttons["composer-block-edit-code"]
        XCTAssertTrue(editBlock.waitForExistence(timeout: 5), "A rich block must expose its native editing card")
        app.buttons["composer-keyboard-done"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: editBlock)], timeout: 5), .completed)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Native composer with code block"; capture.lifetime = .keepAlways; add(capture)
        editBlock.tap(); XCTAssertTrue(code.waitForExistence(timeout: 5)); XCTAssertEqual(code.value as? String, "let greeting = 1")
        app.navigationBars.buttons.element(boundBy: 0).tap(); XCTAssertTrue(code.waitForNonExistence(timeout: 5))
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
    }
    func testSwipeDismissalProtectsChangedWriting() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        XCTAssertTrue(app.textViews["composer-body"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.textViews["composer-body"].waitForNonExistence(timeout: 5))
        app.buttons["discussion-reply"].tap(); let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Keep this writing")
        app.buttons["composer-keyboard-done"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 5)); app.buttons["Keep draft"].tap()
    }
    func testHomeDiscussionReplyAndKeepDraft() {
        let app = launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)); app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5)); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("A durable native reply")
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Me").firstMatch.tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Resume draft: Reply · Finishing")).firstMatch.waitForExistence(timeout: 5))
    }
    func testGuestSignInDoesNotPost() {
        let app = launch(["--guest"])
        app.buttons["topic-4190"].tap(); app.buttons["discussion-reply"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to reply"].waitForExistence(timeout: 5)); let signIn = app.buttons["signin-continue"]; XCTAssertTrue(signIn.waitForExistence(timeout: 5)); signIn.tap()
        XCTAssertTrue(app.textViews["composer-body"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["composer-post"].isEnabled)
    }
    func testNotificationTargetsExactReply() {
        let app = launch()
        app.buttons.matching(identifier: "Notifications").firstMatch.tap()
        let notice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "devon replied")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5)); notice.tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 5))
    }
    func testUnconfirmedUIRequiresDuplicateWarning() {
        let app = launch(["--post-outcome", "unconfirmed"])
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Uncertain reply")
        app.buttons["composer-post"].tap()
        XCTAssertTrue(app.staticTexts["We couldn't confirm whether your reply posted"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-post"].isEnabled)
        app.buttons["Check again"].tap(); app.buttons["Post again…"].tap()
        XCTAssertTrue(app.alerts["Post again?"].waitForExistence(timeout: 5)); app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["composer-post"].isEnabled)
    }
    func testFailedPhotoKeepWarnsAndResumeRetainsWriting() {
        let app = launch(["--upload-fails"])
        let create = app.buttons["New discussion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5)); app.buttons["destination-2"].tap()
        XCTAssertTrue(app.textViews["composer-title"].waitForExistence(timeout: 5)); app.textViews["composer-title"].tap(); app.textViews["composer-title"].typeText("Photo recovery")
        app.textViews["composer-body"].tap(); app.textViews["composer-body"].typeText("Writing stays")
        app.buttons["composer-more"].tap(); let sample = app.buttons["Sample photo"]; XCTAssertTrue(sample.waitForExistence(timeout: 5)); sample.tap()
        XCTAssertTrue(app.buttons["Retry upload"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-post"].isEnabled)
        app.buttons["composer-close"].tap(); XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 5)); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["New discussion"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Me").firstMatch.tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap(); let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo recovery")).firstMatch; XCTAssertTrue(draft.waitForExistence(timeout: 5)); draft.tap()
        XCTAssertTrue(app.buttons["Resume upload"].waitForExistence(timeout: 5)); app.buttons["Remove photo"].firstMatch.tap()
        XCTAssertEqual(app.textViews["composer-title"].value as? String, "Photo recovery"); XCTAssertEqual((app.textViews["composer-body"].value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), "Writing stays")
    }
    func testDarkAccessibilityComposerRemainsReachable() {
        let app = launch(["--dark", "--accessibility-text"])
        let create = app.buttons["New discussion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5)); app.buttons["destination-2"].tap()
        XCTAssertTrue(app.buttons["composer-destination"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["composer-close"].isHittable)
        let body = app.textViews["composer-body"]
        app.swipeUp(); XCTAssertTrue(body.exists); body.tap(); body.typeText("Large text reply")
        XCTAssertTrue(app.buttons["composer-keyboard-done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-close"].isHittable)
        app.buttons["composer-keyboard-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
    func testArabicHomeRotationKeepsFeedReachable() {
        let app = launch(["-AppleLanguages", "(ar)", "-AppleLocale", "ar_JO", "--rtl"])
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
    }
    func testArabicComposerPreservesMixedTextAcrossModesAndRotation() {
        let app = launch(["-AppleLanguages", "(ar)", "-AppleLocale", "ar_JO", "--rtl"])
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("مرحبا Fomio")
        let written = body.value as? String
        app.buttons["composer-keyboard-done"].tap(); app.buttons["composer-more"].tap()
        XCTAssertTrue(app.buttons["التحرير بصيغة Markdown"].waitForExistence(timeout: 5)); app.buttons["التحرير بصيغة Markdown"].tap()
        XCTAssertEqual(body.value as? String, written)
        XCUIDevice.shared.orientation = .landscapeLeft
        let close = app.buttons["composer-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)], timeout: 5), .completed)
        // An iPad window can retain its size when device orientation changes.
        if UIDevice.current.userInterfaceIdiom == .phone { XCTAssertGreaterThan(app.frame.width, app.frame.height) }
        XCTAssertTrue(app.frame.contains(close.frame), "The native action must remain inside the rotated window")
        XCTAssertEqual(body.value as? String, written)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); capture.name = UIDevice.current.userInterfaceIdiom == .phone ? "Arabic composer landscape" : "Arabic composer after device orientation request"; capture.lifetime = .keepAlways; add(capture)
        XCUIDevice.shared.orientation = .portrait
    }
    func testSearchKeepsQueryAndResultsAfterDiscussion() {
        let app = launch()
        app.buttons["Search discussions"].tap()
        let query = app.searchFields.firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("desk")
        let topic = app.buttons["topic-4182"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        query.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(query.value as? String, "desk")
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "desk")
    }
    func testLiveDoesNotUseFixtureFallback() {
        let app = launch(["--live", "--unconfigured"])
        XCTAssertTrue(app.staticTexts["Community configuration needed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topic-4190"].exists)
    }
    func testKeyboardNextDoneAndKeepEditing() {
        let app = launch()
        let create = app.buttons["New discussion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap()
        XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5))
        app.buttons["destination-2"].tap()
        let title = app.textViews["composer-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)
        title.tap(); title.typeText("Keyboard journey")
        let next = app.buttons["composer-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        let body = app.textViews["composer-body"]
        body.typeText("First line\nSecond line")
        XCTAssertEqual(body.value as? String, "First line\nSecond line")
        app.buttons["composer-keyboard-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        body.tap(); body.typeText(" before")
        let beforeDialog = body.value as? String ?? ""
        app.buttons["composer-close"].tap()
        let keepEditing = app.buttons["composer-keep-editing"].firstMatch
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5)); keepEditing.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        body.typeText(" continued")
        let expectedBody = beforeDialog.replacingOccurrences(of: " before", with: " before continued")
        XCTAssertEqual(body.value as? String, expectedBody)
        XCTAssertEqual(title.value as? String, "Keyboard journey")
        app.buttons["composer-keyboard-done"].tap()
        title.tap(); title.typeText(" before")
        let beforeChooser = title.value as? String ?? ""
        app.buttons["composer-destination"].tap()
        XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5))
        app.buttons["destination-2"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        title.typeText(" revised")
        XCTAssertEqual(title.value as? String, beforeChooser.replacingOccurrences(of: " before", with: " before revised"))
        XCTAssertEqual(body.value as? String, expectedBody)
        title.typeText("\n")
        XCTAssertEqual(title.value as? String, beforeChooser.replacingOccurrences(of: " before", with: " before revised"))
        body.typeText(" final")
        XCTAssertEqual(body.value as? String, expectedBody.replacingOccurrences(of: " before continued", with: " before continued final"))
    }
    func testKeyboardDismissedAndRejectionVisibleAfterLongReply() {
        assertRecoveryVisible(outcome: "rejected", heading: "Couldn't post")
    }
    func testKeyboardDismissedAndAuthorizationVisibleAfterLongReply() {
        assertRecoveryVisible(outcome: "expired", heading: "You've been signed out")
    }
    private func assertRecoveryVisible(outcome: String, heading: String) {
        let app = launch(["--post-outcome", outcome])
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10))
        app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap()
        let writing = Array(repeating: "A long reply that retains its writing.", count: 12).joined(separator: "\n")
        body.typeText(writing)
        let enteredWriting = body.value as? String
        app.buttons["composer-post"].tap()
        let message = app.staticTexts[heading]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(message.isHittable)
        XCTAssertEqual(body.value as? String, enteredWriting)
        if outcome == "expired" { XCTAssertFalse(app.buttons["composer-post"].isEnabled) }
    }

}
