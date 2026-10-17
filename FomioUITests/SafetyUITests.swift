import XCTest

/// Reporting & Safety native flows against simulated fixture outcomes. Nothing is sent to a community.
@MainActor final class SafetyUITests: XCTestCase {
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
    private func openReplyReport(_ app: XCUIApplication) {
        let more = app.buttons["post-more-2"]; XCTAssertTrue(more.waitForExistence(timeout: 10)); more.tap()
        let report = app.buttons["Report reply"]; XCTAssertTrue(report.waitForExistence(timeout: 5)); report.tap()
    }

    func testReportReplyFromVisibleMenuShowsConfirmedReceipt() {
        let app = launch(["--preset", "discussion"])
        XCTAssertTrue(app.buttons["post-more-1"].waitForExistence(timeout: 10), "Opening post has a visible More button")
        openReplyReport(app)
        let send = app.buttons["report-send"]; XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled, "No reason chosen yet")
        XCTAssertFalse(app.buttons["Send @%{username} a message"].exists)
        capture(app, "R03 reason sheet")
        app.buttons["report-reason-8"].tap()
        XCTAssertTrue(send.isEnabled); send.tap()
        XCTAssertTrue(app.buttons["report-done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Report received"].exists)
        XCTAssertTrue(app.buttons["report-offer-ignore"].exists, "Ignore is a separate optional action")
        capture(app, "R06 report received")
        app.buttons["report-done"].tap()
        XCTAssertTrue(app.buttons["post-more-2"].waitForExistence(timeout: 5), "Returns to the same discussion")
    }

    func testRequiredDetailsAndDiscardConfirmation() {
        let app = launch(["--preset", "report"])
        let reason = app.buttons["report-reason-7"]; XCTAssertTrue(reason.waitForExistence(timeout: 10)); reason.tap()
        app.buttons["report-send"].tap()
        XCTAssertTrue(app.staticTexts["This reason needs a short description. Add it, then send."].waitForExistence(timeout: 5))
        let details = app.textFields["report-details"].exists ? app.textFields["report-details"] : app.textViews["report-details"]
        details.tap(); details.typeText("Same sales link in three threads.")
        capture(app, "R04 required details with keyboard")
        app.buttons["report-cancel"].tap()
        let discard = app.alerts["Discard this report?"]; XCTAssertTrue(discard.waitForExistence(timeout: 5))
        capture(app, "R11 discard edited report")
        discard.buttons["Keep editing"].tap()
        XCTAssertTrue(app.buttons["report-send"].waitForExistence(timeout: 5))
        XCTAssertEqual((app.textFields["report-details"].exists ? app.textFields["report-details"] : app.textViews["report-details"]).value as? String, "Same sales link in three threads.")
    }

    func testUnknownReceiptOffersCheckStatusInsteadOfRetry() {
        let app = launch(["--preset", "report", "--report-outcome", "timeout", "--timeout-not-received"])
        let reason = app.buttons["report-reason-8"]; XCTAssertTrue(reason.waitForExistence(timeout: 10)); reason.tap()
        app.buttons["report-send"].tap()
        let check = app.buttons["report-check-status"]; XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["report-send"].isEnabled, "Send is unavailable until the state is checked")
        capture(app, "R10d unknown receipt")
        check.tap()
        XCTAssertTrue(app.staticTexts["Your report wasn’t received"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["report-send"].isEnabled)
    }

    func testGuestReportReturnsAfterSignInWithoutSending() {
        let app = launch(["--guest", "--preset", "discussion"])
        openReplyReport(app)
        XCTAssertTrue(app.staticTexts["Sign in to report"].waitForExistence(timeout: 5))
        capture(app, "R09 guest gate")
        app.buttons["signin-continue"].tap()
        let send = app.buttons["report-send"]; XCTAssertTrue(send.waitForExistence(timeout: 10))
        XCTAssertFalse(send.isEnabled, "Rechecked target, no reason preselected, nothing sent")
        capture(app, "R09b back after sign-in")
    }

    func testIgnoreFromProfileThenCollapsedReplyAndShowOnce() {
        let app = launch(["--preset", "ignore-profile"])
        let ignore = app.buttons["profile-ignore"]; XCTAssertTrue(ignore.waitForExistence(timeout: 10))
        capture(app, "I01 profile")
        ignore.tap()
        let confirm = app.buttons["ignore-confirm"]; XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ignore-duration-forever"].isSelected)
        capture(app, "I02 ignore sheet")
        confirm.tap()
        XCTAssertTrue(app.buttons["profile-stop-ignoring"].waitForExistence(timeout: 5))
        capture(app, "I03 ignored profile")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let hidden = app.otherElements["ignored-2"].exists ? app.otherElements["ignored-2"] : app.descendants(matching: .any)["ignored-2"]
        XCTAssertTrue(hidden.waitForExistence(timeout: 10))
        capture(app, "I04 hidden reply")
        hidden.buttons["Show once"].tap()
        XCTAssertTrue(app.buttons["Hide again"].waitForExistence(timeout: 5))
    }

    func testRestrictedIgnoreStatesAreTruthful() {
        let newMember = launch(["--preset", "ignore-profile", "--new-member"])
        XCTAssertTrue(newMember.staticTexts["Ignore isn’t available for your account yet"].waitForExistence(timeout: 10))
        XCTAssertFalse(newMember.buttons["profile-ignore"].exists)
        capture(newMember, "I07a new member")
        newMember.terminate()
        let staff = launch(["--preset", "staff-profile"])
        XCTAssertTrue(staff.staticTexts["Moderators and admins can’t be ignored. If you’re concerned about a moderator, contact support."].waitForExistence(timeout: 10))
        XCTAssertFalse(staff.buttons["profile-ignore"].exists)
    }

    func testSafetyHelpForGuestsAndIgnoredUsersManagement() {
        let guest = launch(["--guest", "--preset", "safety"])
        XCTAssertTrue(guest.staticTexts["Community guidelines"].waitForExistence(timeout: 10))
        XCTAssertTrue(guest.staticTexts["contact-support-pending"].exists || guest.descendants(matching: .any)["contact-support-pending"].exists, "No invented contact")
        capture(guest, "H02b Safety & Help guest")
        guest.terminate()
        let member = launch(["--preset", "ignored-users", "--ignored", "devon,rowan.b"])
        let stop = member.buttons["stop-ignoring-devon"]; XCTAssertTrue(stop.waitForExistence(timeout: 10))
        capture(member, "I05 ignored users")
        stop.tap()
        XCTAssertTrue(member.alerts.buttons["Stop ignoring"].waitForExistence(timeout: 5))
        member.alerts.buttons["Stop ignoring"].tap()
        XCTAssertTrue(member.buttons["stop-ignoring-devon"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(member.buttons["stop-ignoring-rowan.b"].exists)
    }

    func testAccessibilityTextRTLAndDarkCaptures() {
        let large = launch(["--preset", "report", "--accessibility-text"])
        XCTAssertTrue(large.buttons["report-reason-8"].waitForExistence(timeout: 10))
        XCTAssertTrue(large.buttons["report-send"].exists, "Send stays reachable at accessibility sizes")
        capture(large, "A02 report at accessibility text size"); large.terminate()
        let rtl = launch(["--preset", "report", "--rtl", "--dark", "--report-outcome", "rateLimited"])
        let reason = rtl.buttons["report-reason-8"]; XCTAssertTrue(reason.waitForExistence(timeout: 10)); reason.tap()
        rtl.buttons["report-send"].tap()
        XCTAssertTrue(rtl.staticTexts["Too many reports right now"].waitForExistence(timeout: 5))
        capture(rtl, "A03 RTL dark rate-limited notice"); rtl.terminate()
        let ignore = launch(["--preset", "ignore", "--accessibility-text", "--dark"])
        XCTAssertTrue(ignore.buttons["ignore-confirm"].waitForExistence(timeout: 10))
        capture(ignore, "A02b ignore sheet large text dark")
    }
}
