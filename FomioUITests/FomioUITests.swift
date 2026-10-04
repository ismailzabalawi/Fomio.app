import XCTest

@MainActor final class FomioUITests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments.contains("--live") ? arguments : ["--fixture", "--ui-testing"] + arguments; app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        if !arguments.contains("--live") { XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)) }
        return app
    }
    func testHomeDiscussionReplyAndKeepDraft() {
        let app = launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)); app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5)); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("A durable native reply")
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Me"].tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap()
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
        app.tabBars.buttons["Notifications"].tap()
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
        XCTAssertTrue(app.textFields["composer-title"].waitForExistence(timeout: 5)); app.textFields["composer-title"].tap(); app.textFields["composer-title"].typeText("Photo recovery")
        app.textViews["composer-body"].tap(); app.textViews["composer-body"].typeText("Writing stays")
        app.swipeUp(); let sample = app.buttons["sample-photo"]; XCTAssertTrue(sample.waitForExistence(timeout: 5)); sample.tap()
        XCTAssertTrue(app.buttons["Retry upload"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-post"].isEnabled)
        app.buttons["composer-close"].tap(); XCTAssertTrue(app.buttons["Keep draft without photo"].waitForExistence(timeout: 5)); app.buttons["Keep draft without photo"].tap()
        XCTAssertTrue(app.buttons["New discussion"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Me"].tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap(); let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo recovery")).firstMatch; XCTAssertTrue(draft.waitForExistence(timeout: 5)); draft.tap()
        XCTAssertTrue(app.staticTexts["Photo not kept"].waitForExistence(timeout: 5)); app.buttons["Continue without photo"].tap()
        XCTAssertEqual(app.textFields["composer-title"].value as? String, "Photo recovery"); XCTAssertEqual(app.textViews["composer-body"].value as? String, "Writing stays")
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
        let title = app.textFields["composer-title"]
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
        app.buttons["composer-post"].tap()
        let message = app.staticTexts[heading]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(message.isHittable)
        XCTAssertEqual(body.value as? String, writing)
        if outcome == "expired" { XCTAssertFalse(app.buttons["composer-post"].isEnabled) }
    }

}
