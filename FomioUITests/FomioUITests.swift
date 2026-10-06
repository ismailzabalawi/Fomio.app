import XCTest
import UIKit

@MainActor final class FomioUITests: XCTestCase {
    func testLiveCategoryChildAboutAndTopicNavigation() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_LIVE_UI_TESTS"] == "1" else { throw XCTSkip("Live UI reads require explicit opt-in") }
        let app = launch(["--live"])
        let communities = app.buttons["Communities"].firstMatch
        XCTAssertTrue(communities.waitForExistence(timeout: 20)); communities.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 20)); search.tap(); search.typeText("Experiments\n")
        let child = app.buttons["community-54"]
        XCTAssertTrue(child.waitForExistence(timeout: 15)); XCTAssertTrue(app.buttons["community-45"].exists)
        let directory = XCTAttachment(screenshot: app.screenshot()); directory.name = "Live root and child category identity"; directory.lifetime = .keepAlways; add(directory)
        child.tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 15)); about.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        let topic = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "topic-")).firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 15))
        let feed = XCTAttachment(screenshot: app.screenshot()); feed.name = "Live subcategory header and feed"; feed.lifetime = .keepAlways; add(feed)
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 15))
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "Live topic opening post and reply controls"; detail.lifetime = .keepAlways; add(detail)
        XCTAssertFalse(app.staticTexts["Fixture preview"].exists)
    }
    func testCategoryDirectoryExpansionAboutAndChildCreate() {
        let app = launch(["--preset", "communities"])
        let expand = app.buttons["category-expand-1"]
        XCTAssertTrue(expand.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["community-4"].exists)
        expand.tap(); XCTAssertTrue(app.buttons["community-4"].waitForNonExistence(timeout: 5))
        expand.tap(); XCTAssertTrue(app.buttons["community-4"].waitForExistence(timeout: 5))
        app.buttons["community-4"].tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 5)); about.tap()
        XCTAssertTrue(app.staticTexts["Planes, saws, chisels and keeping them sharp."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["New discussion in Hand Tools"].tap()
        XCTAssertTrue(app.textViews["composer-body"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hand Tools")).firstMatch.exists)
        XCTAssertFalse(app.buttons["Post"].isEnabled)
        app.buttons["composer-close"].tap()
    }
    func testDirectoryFilterKeepsAncestorAndQueryAfterBack() {
        let app = launch(["--preset", "communities"])
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Finishing\n")
        XCTAssertTrue(app.buttons["community-1"].exists); XCTAssertFalse(app.buttons["community-5"].exists)
        let child = app.buttons["community-2"]; XCTAssertTrue(child.waitForExistence(timeout: 5)); child.tap()
        XCTAssertTrue(app.buttons["community-about"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(child.waitForExistence(timeout: 5)); XCTAssertEqual(search.value as? String, "Finishing")
        XCTAssertFalse(app.buttons["community-5"].exists)
    }
    func testCategoryDarkLargeTextAndThemeReflow() {
        let app = launch(["--preset", "communities", "--dark", "--accessibility-text", "--teal-theme"])
        let root = app.buttons["community-1"]; XCTAssertTrue(root.waitForExistence(timeout: 10)); root.tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.isHittable); XCTAssertGreaterThanOrEqual(about.frame.height, 44)
        XCTAssertTrue(app.buttons["New discussion in Woodworking"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Category dark accessibility teal"; capture.lifetime = .keepAlways; add(capture)
    }
    func testInserterCancelPreservesHiddenKeyboard() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Audit paragraph")
        dismissComposerKeyboard(app)
        app.buttons["composer-insert"].tap()
        XCTAssertTrue(app.buttons["composer-insert-cancel"].waitForExistence(timeout: 5))
        app.buttons["composer-insert-cancel"].tap()
        XCTAssertTrue(app.buttons["composer-insert"].waitForExistence(timeout: 5))
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Show keyboard"), object: app.buttons["composer-keyboard"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed, "Cancel should preserve hidden keyboard")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
    func testHeadingMenuDisablesUnsupportedInlineFormatting() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Heading")
        app.buttons["composer-block-type"].tap()
        app.buttons["composer-turn-into-Heading 2"].tap()
        app.buttons["composer-more"].tap(); app.buttons["Format"].tap()
        for label in ["Bold", "Italic", "Link"] {
            let action = app.buttons[label].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertFalse(action.isEnabled)
        }
        XCTAssertEqual(body.value as? String, "## Heading")
    }
    func testLargestTextSelectionFitsBar() {
        let app = launch(["--preset", "newtopic", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Audit paragraph")
        body.press(forDuration: 1.1)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
        else { body.doubleTap() }
        let done = app.buttons["composer-selection-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Largest text selection with compact composer bar"; capture.lifetime = .keepAlways; add(capture)
        for id in ["composer-insert", "composer-more", "composer-selection-done"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertTrue(app.frame.contains(button.frame), "Control outside screen: \(id), \(button.frame)")
        }
    }
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    override func tearDown() { MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments.contains("--live") ? arguments : ["--fixture", "--ui-testing"] + arguments; app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        if !arguments.contains("--live") {
            let ready = arguments.contains("communities") ? "community-1" : "topic-4182"
            XCTAssertTrue(app.buttons[ready].waitForExistence(timeout: 10))
        }
        return app
    }
    private func dismissComposerKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        // The floating bar's own control; a drag on a short reply also pulls the sheet and opens Keep/Discard.
        let toggle = app.buttons["composer-keyboard"]; XCTAssertEqual(toggle.label, "Hide keyboard"); toggle.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        // Hiding the keyboard keeps the floating bar reachable above the safe area.
        let docked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND label == %@", "Show keyboard"), object: app.buttons["composer-keyboard"])
        XCTAssertEqual(XCTWaiter.wait(for: [docked], timeout: 5), .completed)
    }
    func testNativeFormattingCaretTypingSurvivesSourceSwitch() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-insert"].isHittable); XCTAssertTrue(app.buttons["composer-more"].isHittable)
        let hiddenCapture = XCTAttachment(screenshot: app.screenshot()); hiddenCapture.name = "Composer entry bar without keyboard"; hiddenCapture.lifetime = .keepAlways; add(hiddenCapture)
        body.tap(); body.typeText("Before ")
        XCTAssertFalse(app.buttons["composer-keyboard-done"].exists)
        let more = app.buttons["composer-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: more)], timeout: 5), .completed)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Composer bar attached to keyboard"; capture.lifetime = .keepAlways; add(capture)
        // XCTest’s keyboard frame excludes the QuickType prediction row.
        XCTAssertLessThanOrEqual(more.frame.maxY, keyboard.frame.minY)
        XCTAssertLessThanOrEqual(keyboard.frame.minY - more.frame.maxY, 64, "Only the prediction row should separate formatting controls from the keys")
        more.tap(); app.buttons["Format"].tap(); app.buttons["Bold"].firstMatch.tap()
        body.typeText("Bold")
        app.buttons["composer-more"].tap(); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "Before **Bold**")
        app.buttons["composer-close"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["Discard"].tap()
    }
    func testFloatingBarTurnsBlockIntoHeadingAndInserterCancelKeepsCaret() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("What I tried")
        let chip = app.buttons["composer-block-type"]; XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Turn into: Paragraph")
        chip.tap(); let heading = app.buttons["composer-turn-into-Heading 2"]; XCTAssertTrue(heading.waitForExistence(timeout: 5)); heading.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Turn into: Heading 2"), object: chip)], timeout: 5), .completed)
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Changing the block type keeps the keyboard up")
        app.buttons["composer-insert"].tap()
        XCTAssertTrue(app.staticTexts["composer-insert-placement"].waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Add block sheet names its placement"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["composer-insert-cancel"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        body.typeText(" first")
        app.buttons["composer-more"].tap(); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "## What I tried first", "Cancel changes nothing and returns to the captured caret")
        app.buttons["composer-close"].tap(); app.buttons["Discard"].tap()
    }
    func testNativeBlockFormAndMarkdownRoundTrip() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Writing before code\n")
        app.buttons["composer-insert"].tap()
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Code")
        let codeBlock = app.buttons["Code"]; XCTAssertTrue(codeBlock.waitForExistence(timeout: 5)); codeBlock.tap()
        let code = app.textViews["block-body"]; XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("let greeting = 1")
        app.buttons["block-save"].tap()
        XCTAssertTrue(code.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        // After the pushed form closes, the bar must float above the keyboard again rather than behind it.
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["composer-more"].frame.maxY <= keyboardTop }, object: nil)], timeout: 5), .completed)
        app.buttons["composer-more"].tap()
        let markdown = app.buttons["Edit in Markdown"]
        if !markdown.waitForExistence(timeout: 2) { app.buttons["composer-more"].tap() }
        XCTAssertTrue(markdown.waitForExistence(timeout: 5)); markdown.tap()
        XCTAssertTrue((body.value as? String)?.contains("let greeting = 1") == true)
        XCTAssertTrue((body.value as? String)?.contains("```") == true)
        app.buttons["composer-more"].tap(); app.buttons["Rich text"].tap()
        let editBlock = app.buttons["composer-block-edit-code"]
        XCTAssertTrue(editBlock.waitForExistence(timeout: 5), "A rich block must expose its native editing card")
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
        dismissComposerKeyboard(app)
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
        create.tap(); app.buttons["composer-destination"].tap(); app.buttons["destination-toggle-1"].tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5)); app.buttons["destination-2"].tap()
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
        create.tap(); app.buttons["composer-destination"].tap(); app.buttons["destination-toggle-1"].tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5)); app.buttons["destination-2"].tap()
        XCTAssertTrue(app.buttons["composer-destination"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["composer-close"].isHittable)
        let body = app.textViews["composer-body"]
        app.swipeUp(); XCTAssertTrue(body.exists); body.tap(); body.typeText("Large text reply")
        XCTAssertFalse(app.buttons["composer-keyboard-done"].exists)
        XCTAssertTrue(app.buttons["composer-close"].isHittable)
        dismissComposerKeyboard(app)
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
        app.buttons["composer-more"].tap()
        XCTAssertTrue(app.buttons["التحرير بصيغة Markdown"].waitForExistence(timeout: 5)); app.buttons["التحرير بصيغة Markdown"].tap()
        XCTAssertEqual(body.value as? String, written)
        XCUIDevice.shared.orientation = .landscapeLeft
        let close = app.buttons["composer-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)], timeout: 5), .completed)
        // An iPad window can retain its size when device orientation changes.
        if UIDevice.current.userInterfaceIdiom == .phone {
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
            let result = XCTWaiter.wait(for: [rotated], timeout: 8)
            let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); evidence.name = "Arabic composer rotation outcome"; evidence.lifetime = .keepAlways; add(evidence)
            XCTAssertEqual(result, .completed, "Wait for the window rotation, rather than the already-visible Close button")
        }
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
    func testCommunityFieldSearchesInPlace() {
        let app = launch()
        let create = app.buttons["New discussion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap()
        let search = app.textFields["destination-search"]
        let field = app.buttons["composer-destination"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertFalse(search.exists)
        field.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["destination-2"].exists)
        // Families open and close; search looks inside closed ones.
        let woodworking = app.buttons["destination-toggle-1"]
        woodworking.tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5))
        woodworking.tap(); XCTAssertTrue(app.buttons["destination-2"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)
        search.tap(); search.typeText("repa")
        XCTAssertTrue(app.buttons["destination-6"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["destination-2"].exists)
        app.buttons["destination-6"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertTrue(field.label.contains("Repairs")); XCTAssertFalse(search.exists)
        // Choosing a community alone is not writing, so closing doesn't ask to keep a draft.
        app.buttons["composer-close"].tap()
        XCTAssertTrue(create.waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-keep-editing"].exists)
    }
    func testKeyboardBarNextAndKeepEditing() {
        let app = launch()
        let create = app.buttons["New discussion"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap()
        app.buttons["composer-destination"].tap(); app.buttons["destination-toggle-1"].tap()
        XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5))
        app.buttons["destination-2"].tap()
        let title = app.textViews["composer-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(app.keyboards.count, 0)
        title.tap(); title.typeText("Keyboard journey")
        XCTAssertFalse(app.buttons["composer-keyboard-done"].exists)
        title.typeText("\n")
        let body = app.textViews["composer-body"]
        body.typeText("First line\nSecond line")
        XCTAssertEqual(body.value as? String, "First line\nSecond line")
        body.typeText(" before")
        let beforeDialog = body.value as? String ?? ""
        app.buttons["composer-close"].tap()
        let keepEditing = app.buttons["composer-keep-editing"].firstMatch
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5)); keepEditing.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        body.typeText(" continued")
        let expectedBody = beforeDialog.replacingOccurrences(of: " before", with: " before continued")
        XCTAssertEqual(body.value as? String, expectedBody)
        XCTAssertEqual(title.value as? String, "Keyboard journey")
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
