import XCTest
import UIKit

@MainActor final class AdaptiveReadingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ arguments: [String] = [], waitForScope: Bool = true) -> XCUIApplication {
        if ProcessInfo.processInfo.environment["FOMIO_REQUIRE_REDUCE_MOTION"] == "1" {
            XCTAssertTrue(UIAccessibility.isReduceMotionEnabled, "Enable the actual simulator Reduce Motion setting before this run")
        }
        if ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_LANDSCAPE"] == "1" {
            XCUIDevice.shared.orientation = .landscapeLeft
            addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        }
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing", "--adaptive-search-cases"] + arguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        if waitForScope { XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 30)) }
        if ProcessInfo.processInfo.environment["FOMIO_NARROW_IPAD"] == "1" {
            narrowIPadWindow(app)
        }
        return app
    }
    private func narrowIPadWindow(_ app: XCUIApplication) {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
        let window = app.windows.firstMatch
        if window.frame.width < 1000 {
            expandIPadWindow(app, minimumWidth: 1000)
        }
        let before = window.frame
        XCTAssertGreaterThanOrEqual(before.width, 1000, "Start with an actual wide window")
        addTeardownBlock { @MainActor in
            app.activate()
            if app.buttons["scope-cancel"].exists { app.buttons["scope-cancel"].tap() }
            if window.frame.width < before.width - 20 { self.expandIPadWindow(app, minimumWidth: before.width - 20) }
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                window.frame.width >= before.width - 20
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        }
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -6, dy: -6))
        let target = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 600, dy: min(before.height - 80, 700)))
        corner.press(forDuration: 1, thenDragTo: target)
        let narrowed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = window.frame
            return app.state == .runningForeground && frame.width < 720
                && frame.width < before.width - 100 && frame.height >= 490
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [narrowed], timeout: 10), .completed,
                       "A live native window must resize; overview thumbnails do not count")
        recordWindow(app, "Actual narrow iPad acceptance window")
        capture(app, "Actual narrow iPad before interaction")
        let controls = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["window-controls:com.fomio.mobile"]
        XCTAssertTrue(controls.exists)
        XCTAssertFalse(app.buttons["community-scope"].frame.intersects(controls.frame),
                       "Floating window controls must not cover the community selector")
    }
    private func expandIPadWindow(_ app: XCUIApplication, minimumWidth: CGFloat) {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let controls = system.buttons["window-controls:com.fomio.mobile"]
        XCTAssertTrue(controls.waitForExistence(timeout: 10))
        controls.tap()
        let zoom = system.buttons["Zoom-button"]
        XCTAssertTrue(zoom.waitForExistence(timeout: 10))
        zoom.tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.state == .runningForeground && app.windows.firstMatch.frame.width >= minimumWidth
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 10), .completed,
                       "The actual native Zoom action must expand the app window")
    }
    private func find(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    private func search(_ app: XCUIApplication, _ term: String) {
        let field = app.textFields["topic-search-field"]
        // The magnifier toggles: it hides an open, empty field, so only tap it to reveal.
        if !field.exists { app.buttons["reveal-topic-search"].tap() }
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(term + "\n")
    }
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            let list = app.scrollViews["scoped-search-results"]
            if list.exists { list.swipeUp() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let screens = XCUIScreen.screens
        for (index, screen) in screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = screens.count == 1 ? name : "\(name) · screen \(index + 1) of \(screens.count)"
            attachment.lifetime = .keepAlways; add(attachment)
        }
    }
    /// Drive Open/Closed with Device Hub while the test waits for the actual
    /// adaptive shell. An orientation request does not establish a Duo fold.
    func testExactSearchBackAfterManualDuoFold() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_DUO_FOLD"] == "1" else {
            throw XCTSkip("Requires Device Hub Open, then Closed at DUO_SEARCH_WAIT_CLOSED")
        }
        let app = launch()
        NSLog("DUO_SEARCH_WAIT_OPEN")
        XCTAssertTrue(find(app, "reading-two-pane").waitForExistence(timeout: 90), "Start on the actual open display")
        search(app, "cracked diode")
        let topic = app.buttons["topic-4190"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); topic.tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["#14"].isHittable)
        recordWindow(app, "Duo open")
        capture(app, "Duo open exact reply before fold")
        NSLog("DUO_SEARCH_WAIT_CLOSED")
        XCTAssertTrue(find(app, "reading-one-pane").waitForExistence(timeout: 90), "Use the native Closed control")
        let back = app.buttons["back-to-topic-list"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Folding detail must expose return navigation")
        XCTAssertTrue(back.isHittable)
        recordWindow(app, "Duo folded")
        capture(app, "Duo folded exact reply and navigation")
        back.tap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "cracked diode")
        XCTAssertTrue(topic.exists)
        capture(app, "Duo folded Back retains exact search")
    }
    /// D1 (2026-10-25 Duo validation): after an auto-selected discussion is withdrawn by a
    /// fold and re-added by unfolding, choosing another discussion must keep its navigation
    /// chrome in two panes and after collapsing to one.
    func testSelectedDiscussionKeepsNavigationAfterCollapse() throws {
        let app = launchDefaultFixture(["--reading-size-override"])
        guard find(app, "reading-two-pane").waitForExistence(timeout: 30) else {
            throw XCTSkip("Requires a window wide enough for two panes")
        }
        let toggle = app.buttons["debug-toggle-compact-reading"]
        try exerciseCollapse(app, fold: {
            toggle.tap()
            XCTAssertTrue(self.find(app, "reading-one-pane").waitForExistence(timeout: 10))
        }, unfold: {
            toggle.tap()
            XCTAssertTrue(self.find(app, "reading-two-pane").waitForExistence(timeout: 10))
        })
    }
    func testSelectedDiscussionKeepsNavigationAfterManualDuoFold() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_DUO_FOLD"] == "1" else {
            throw XCTSkip("Requires Device Hub Closed and Open at each DUO_PRESS marker")
        }
        let app = launchDefaultFixture()
        XCTAssertTrue(find(app, "reading-two-pane").waitForExistence(timeout: 90), "Start on the actual open display")
        var presses = 0
        func press(_ control: String, until identifier: String) {
            presses += 1; NSLog("DUO_PRESS \(control) \(presses)")
            XCTAssertTrue(find(app, identifier).waitForExistence(timeout: 90), "Use the native \(control) control")
        }
        try exerciseCollapse(app, fold: { press("Closed", until: "reading-one-pane") },
                             unfold: { press("Open", until: "reading-two-pane") })
    }
    /// The default fixture: its discussions are long enough to scroll before collapsing.
    private func launchDefaultFixture(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        return app
    }
    /// The validation's sequence: read the auto-selected discussion, fold back to the list,
    /// unfold, choose another discussion and scroll it, then fold again.
    private func exerciseCollapse(_ app: XCUIApplication, fold: () -> Void, unfold: () -> Void) throws {
        let more = app.buttons["discussion-share"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        app.scrollViews["discussion-content"].swipeUp()
        fold()
        XCTAssertTrue(app.buttons["topic-4190"].waitForExistence(timeout: 10), "An untouched auto-selection folds to the list")
        XCTAssertFalse(app.buttons["back-to-topic-list"].exists)
        unfold()
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Unfolding returns to the same discussion with its actions")
        XCTAssertTrue(app.buttons["toggle-topic-list"].waitForExistence(timeout: 5))
        // Let the unfold's rotation and bar refresh settle before scrolling the list.
        Thread.sleep(forTimeInterval: 2)
        // Not the first row, which two panes auto-select; the validation's explicit choice.
        let topic = app.buttons["topic-4199"]
        // Scroll the list column from its top; the window's middle is the discussion in two panes.
        let window = app.windows.firstMatch
        func dragList(from start: CGFloat, to end: CGFloat) {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: start))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: end)))
        }
        if !(topic.exists && topic.isHittable) { for _ in 0..<4 { dragList(from: 0.35, to: 0.95) } }
        for _ in 0..<6 where !(topic.exists && topic.isHittable) { dragList(from: 0.75, to: 0.45) }
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); topic.tap()
        XCTAssertTrue(app.staticTexts["Sunil P."].waitForExistence(timeout: 10))
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The chosen discussion keeps its actions in two panes")
        XCTAssertTrue(app.buttons["toggle-topic-list"].exists)
        app.scrollViews["discussion-content"].swipeUp()
        fold()
        let back = app.buttons["back-to-topic-list"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Collapsing a chosen discussion must expose return navigation")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in back.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed, "Back becomes usable once the fold settles")
        XCTAssertTrue(more.exists, "The discussion's own actions survive the collapse")
        recordWindow(app, "Collapsed chosen discussion"); capture(app, "Collapsed chosen discussion keeps navigation")
        back.tap()
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        XCTAssertTrue(topic.isHittable, "Back returns to the topic list")
    }
    private func recordWindow(_ app: XCUIApplication, _ name: String) {
        let evidence = XCTAttachment(string: "Application: \(app.frame)\nWindow: \(app.windows.firstMatch.frame)\nActive screens: \(XCUIScreen.screens.count)\n\(app.debugDescription)")
        evidence.name = name + " geometry and hierarchy"; evidence.lifetime = .keepAlways; add(evidence)
    }
    func testChooserRetainsFilterAfterManualDuoFold() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_DUO_FOLD"] == "1" else {
            throw XCTSkip("Requires Device Hub Open, then Closed at DUO_CHOOSER_WAIT_CLOSED")
        }
        let app = launch()
        NSLog("DUO_CHOOSER_WAIT_OPEN")
        XCTAssertTrue(find(app, "reading-two-pane").waitForExistence(timeout: 90))
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Repairs")
        XCTAssertTrue(app.buttons["scope-6"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scope-5"].exists)
        let initialWidth = app.windows.firstMatch.frame.width
        recordWindow(app, "Duo open chooser")
        capture(app, "Duo open chooser before fold")
        NSLog("DUO_CHOOSER_WAIT_CLOSED")
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) > 80
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 90), .completed, "Use the actual native Closed control")
        XCTAssertTrue(filter.waitForExistence(timeout: 10), "The same chooser remains presented after folding")
        XCTAssertEqual(filter.value as? String, "Repairs")
        XCTAssertTrue(app.buttons["scope-5"].exists); XCTAssertTrue(app.buttons["scope-6"].exists)
        recordWindow(app, "Duo folded chooser")
        capture(app, "Duo folded chooser retains filter and ancestor")
        NSLog("DUO_CHOOSER_WAIT_REOPEN")
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 90), .completed, "Use the actual native Open control")
        XCTAssertEqual(filter.value as? String, "Repairs")
        XCTAssertTrue(app.buttons["scope-5"].exists); XCTAssertTrue(app.buttons["scope-6"].exists)
        recordWindow(app, "Duo reopened chooser")
        capture(app, "Duo reopened chooser retains filter and ancestor")
        app.buttons["scope-6"].tap()
        XCTAssertTrue(filter.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Repairs"))
        capture(app, "Duo reopened chooser selection updates scope")
    }
    func testDraftRetainsTextAfterManualDuoFoldAndKeepReopen() throws {
        try exerciseDuoDraftFold(placeCaretAtEnd: true)
    }
    func testGroupedFailureSurvivesManualDuoFoldUntilRetry() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_DUO_FOLD"] == "1" else {
            throw XCTSkip("Requires native Closed/Open at the Duo error markers")
        }
        let app = launch(["--search-initial-fails", "--dark"])
        XCTAssertTrue(find(app, "reading-two-pane").waitForExistence(timeout: 90))
        search(app, "Adaptive")
        let failure = find(app, "search-error")
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        let initialWidth = app.windows.firstMatch.frame.width
        let scopeLabelHeight = app.buttons["community-scope"].staticTexts.firstMatch.frame.height
        func verifyFailure(_ name: String) {
            XCTAssertTrue(failure.exists)
            XCTAssertFalse(app.buttons["topic-9101"].exists, "A one-shot failure must not be automatically retried during adaptation")
            XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "Adaptive")
            XCTAssertTrue(app.buttons["retry-topic-search"].exists)
            XCTAssertLessThanOrEqual(app.buttons["community-scope"].staticTexts.firstMatch.frame.height, scopeLabelHeight + 1,
                                    "The short scope name should retain its line count; branding must yield the space after folding")
            recordWindow(app, name); capture(app, name)
        }
        verifyFailure("Duo open grouped failure")
        NSLog("DUO_ERROR_WAIT_CLOSED")
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) > 80
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 90), .completed)
        verifyFailure("Duo folded grouped failure")
        NSLog("DUO_ERROR_WAIT_REOPEN")
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 90), .completed)
        verifyFailure("Duo reopened grouped failure")
        let retry = app.buttons["retry-topic-search"]
        scrollTo(retry, in: app); retry.tap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        XCTAssertFalse(failure.exists)
        capture(app, "Duo explicit Retry after fold recovers")
    }
    func testFocusedKeptDraftUnfoldsWithoutCaretCommand() throws {
        try exerciseDuoDraftFold(placeCaretAtEnd: false)
    }
    func testWideFloatingIPadSidebarWindowControls() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_WIDE_FLOATING_IPAD"] == "1" else {
            throw XCTSkip("Requires a wide iPad with native window resizing")
        }
        let app = launch(["--dark"])
        let window = app.windows.firstMatch
        let before = window.frame
        XCTAssertGreaterThanOrEqual(before.width, 1200)
        XCTAssertTrue(find(app, "reading-three-pane").waitForExistence(timeout: 10))
        addTeardownBlock { @MainActor in
            app.activate()
            let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -6, dy: -6))
            let original = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: before.width - 6, dy: before.height - 6))
            corner.press(forDuration: 1, thenDragTo: original)
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                window.frame.width >= before.width - 20
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        }
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -6, dy: -6))
        let smaller = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: before.width - 100, dy: before.height - 100))
        corner.press(forDuration: 1, thenDragTo: smaller)
        let floated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = window.frame
            return app.state == .runningForeground && frame.width >= 1080
                && frame.width < before.width - 40 && frame.height < before.height - 40
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [floated], timeout: 10), .completed,
                       "Only a live, actually resized wide window establishes this review")
        XCTAssertTrue(find(app, "reading-three-pane").exists)
        recordWindow(app, "Wide floating iPad sidebar")
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // The shell's identifier propagates onto this image in the native AX
        // tree; use its semantic label and verify uniqueness before geometry.
        let logos = app.images.matching(NSPredicate(format: "label == %@", "Fomio"))
        XCTAssertEqual(logos.count, 1)
        let logo = logos.firstMatch
        let windowControls = system.buttons["window-controls:com.fomio.mobile"]
        XCTAssertTrue(logo.exists)
        XCTAssertTrue(windowControls.exists)
        XCTAssertFalse(logo.frame.intersects(windowControls.frame), "System window controls must not cover the wordmark")
        let controls = XCTAttachment(string: system.debugDescription)
        controls.name = "Wide floating iPad native window controls"
        controls.lifetime = .keepAlways; add(controls)
        capture(app, "Wide floating iPad sidebar logo clearance for visual inspection")
    }
    private func exerciseDuoDraftFold(placeCaretAtEnd: Bool) throws {
        guard ProcessInfo.processInfo.environment["FOMIO_ADAPTIVE_DUO_FOLD"] == "1" else {
            throw XCTSkip("Requires native Closed/Open at the Duo draft markers")
        }
        let app = launch()
        XCTAssertTrue(find(app, "reading-two-pane").waitForExistence(timeout: 90))
        search(app, "Adaptive discussion 01")
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10)); app.buttons["topic-9101"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10)); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap()
        let text = "Folded reply remains readable."
        body.typeText(text)
        let initialWidth = app.windows.firstMatch.frame.width
        recordWindow(app, "Duo open draft")
        capture(app, "Duo open draft before folding")
        NSLog("DUO_DRAFT_WAIT_CLOSED")
        let folded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) > 80
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [folded], timeout: 90), .completed)
        XCTAssertEqual((body.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), text)
        let close = app.buttons["composer-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let reachable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in close.isHittable }, object: nil)
        let becameReachable = XCTWaiter.wait(for: [reachable], timeout: 5)
        recordWindow(app, "Duo folded draft before Close")
        capture(app, "Duo folded draft before Close")
        XCTAssertEqual(becameReachable, .completed, "Close must remain reachable after the fold settles")
        close.tap()
        XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 10)); app.buttons["Keep draft"].tap()
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 10)); app.buttons["me-drafts"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Resume draft: Reply · Repairs")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertEqual((body.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), text)
        recordWindow(app, "Duo folded kept draft reopened")
        capture(app, "Duo folded kept draft reopened")
        body.tap()
        if placeCaretAtEnd {
            // A generic tap does not establish an insertion point. Use the native
            // hardware-key command to place it at the document end before unfolding.
            app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: .command)
        }
        NSLog("DUO_DRAFT_WAIT_REOPEN")
        if ProcessInfo.processInfo.environment["FOMIO_DUO_MAIN_THREAD_CAPTURE"] == "1" {
            // Diagnostic run only: let the host debugger capture an unfolding hang
            // before an accessibility snapshot timeout tears down the app process.
            NSLog("DUO_DRAFT_DIAGNOSTIC_READY")
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "Host debugger capture window")], timeout: 60)
        }
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - initialWidth) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 90), .completed)
        let continuation = placeCaretAtEnd ? " Continued." : "Q7"
        app.typeText(continuation)
        let continued = try XCTUnwrap(body.value as? String).trimmingCharacters(in: .whitespacesAndNewlines)
        if placeCaretAtEnd { XCTAssertEqual(continued, text + continuation) }
        else {
            // This case checks the untouched tap-to-focus path. Its insertion point
            // is unspecified; exact end-caret retention is covered by the other case.
            XCTAssertEqual(continued.components(separatedBy: continuation).count, 2)
            XCTAssertEqual(continued.replacingOccurrences(of: continuation, with: ""), text)
        }
        recordWindow(app, "Duo open kept draft continued")
        capture(app, "Duo open kept draft continued")
    }
    func testSearchStartsCollapsedAndCancelReturnsToFeed() {
        let app = launch()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
        search(app, "noadaptivehitszzqx")
        XCTAssertTrue(app.staticTexts["No topics match “noadaptivehitszzqx”"].waitForExistence(timeout: 10))
        XCTAssertFalse(find(app, "search-error").exists)
        find(app, "search-no-results").buttons["Clear search"].tap()
        XCTAssertTrue(find(app, "search-no-results").waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.textFields["topic-search-field"].exists, "Clear search empties the query and keeps the field")
        app.buttons["reveal-topic-search"].tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForNonExistence(timeout: 10), "The magnifier hides an empty search")
        app.buttons["reveal-topic-search"].tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForExistence(timeout: 10), "and reveals it again")
        app.buttons["cancel-topic-search"].tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        capture(app, "Collapsed topic search after Cancel")
    }
    func testFailedCommunityListKeepsFilterAndManualRetryRecovers() {
        let app = launch(["--community-load-fails"])
        app.buttons["community-scope"].tap()
        XCTAssertTrue(app.staticTexts["Community list unavailable"].waitForExistence(timeout: 10))
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Repairs")
        XCTAssertTrue(app.staticTexts["No matches in loaded communities"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No communities match"].exists, "An unavailable catalog cannot establish an empty result")
        capture(app, "Unavailable catalog retains local chooser filter")
        app.buttons["retry-community-list"].tap()
        XCTAssertTrue(app.buttons["scope-6"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scope-5"].exists, "A matching child retains its parent context")
        XCTAssertFalse(app.staticTexts["Community list unavailable"].exists)
        XCTAssertEqual(filter.value as? String, "Repairs")
        capture(app, "Manual catalog Retry retains filter and ancestor")
        app.buttons["scope-6"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Repairs"))
    }
    func testResolvedCurrentCommunityMatchesWithoutContradictoryEmptyState() {
        let app = launch(["--preset", "partial-community"])
        let scope = app.buttons["community-scope"]
        let resolved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Turning"), object: scope)
        XCTAssertEqual(XCTWaiter.wait(for: [resolved], timeout: 10), .completed)
        scope.tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Turning")
        XCTAssertTrue(app.buttons["scope-9"].waitForExistence(timeout: 10))
        capture(app, "Resolved current category in partial catalog filter")
        XCTAssertFalse(app.staticTexts["No communities match"].exists, "A matching readable current category is a real match")
        XCTAssertTrue(app.staticTexts["current-community-parent"].exists, "Known parent context remains visible for the matching child")
        XCTAssertEqual(app.staticTexts["current-community-parent"].label, "Woodworking")
        app.buttons["scope-9"].tap()
        XCTAssertTrue(scope.label.contains("Turning"))
    }
    func testEmptySearchCancelKeepsMidFeedPosition() {
        let app = launch()
        let topic = app.buttons["topic-9105"]
        scrollTo(topic, in: app)
        let before = topic.frame.minY
        capture(app, "Feed before empty search reveal")
        app.buttons["reveal-topic-search"].tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForExistence(timeout: 10))
        app.buttons["cancel-topic-search"].tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        XCTAssertLessThan(abs(topic.frame.minY - before), 3, "Cancel without typing restores the original reading position")
        capture(app, "Feed after empty search Cancel")
    }
    func testGroupedFailureIsInlineAndManualRetryRecovers() {
        let app = launch(["--search-initial-fails"])
        search(app, "Adaptive")
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No topics match “Adaptive”"].exists)
        XCTAssertTrue(app.textFields["topic-search-field"].exists)
        capture(app, "Explicit grouped search failure")
        XCTAssertGreaterThanOrEqual(app.buttons["retry-topic-search"].frame.height, 44 - 0.001)
        XCTAssertGreaterThanOrEqual(app.buttons["cancel-topic-search"].frame.height, 44 - 0.001)
        app.buttons["retry-topic-search"].tap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        XCTAssertFalse(find(app, "search-error").exists)
        capture(app, "Successful search Retry")
    }
    func testRefreshFailureKeepsPreviousResultsUntilManualRetry() {
        let app = launch(["--search-refresh-fails"])
        search(app, "Adaptive")
        let first = app.buttons["topic-9101"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        app.buttons["feed-options"].tap()
        XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 5)); app.buttons["Refresh"].tap()
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Showing previous results"].exists)
        XCTAssertTrue(first.exists, "A failed refresh retains the permitted successful snapshot")
        XCTAssertFalse(find(app, "search-no-results").exists)
        capture(app, "Failed refresh retains previous results")
        app.buttons["retry-topic-search"].tap()
        XCTAssertTrue(find(app, "search-error").waitForNonExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Showing previous results"].exists)
        XCTAssertTrue(first.exists)
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "Adaptive")
        capture(app, "Manual refresh Retry replaces previous results")
    }
    func testPaginationFailureRetainsEarlierPageAndRetriesNextPage() {
        let app = launch(["--search-more-fails"])
        search(app, "Adaptive")
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        let more = app.buttons["More results"]
        scrollTo(more, in: app); more.tap()
        let footer = find(app, "search-page-error")
        XCTAssertTrue(footer.waitForExistence(timeout: 10))
        let retry = app.buttons["retry-topic-search"]
        scrollTo(retry, in: app); retry.tap()
        let later = app.buttons["topic-9107"]
        scrollTo(later, in: app); XCTAssertTrue(later.exists)
        XCTAssertFalse(find(app, "search-page-error").exists)
        capture(app, "Failed page retried without replacing earlier results")
    }
    func testCommunityChooserKeepsMatchingParentAndCancelKeepsScope() {
        let app = launch()
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Finishing")
        XCTAssertTrue(app.buttons["scope-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scope-2"].exists)
        XCTAssertGreaterThanOrEqual(app.buttons["scope-cancel"].frame.height, 44 - 0.001)
        app.buttons["scope-cancel"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("All communities"))
        app.buttons["community-scope"].tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Turning\n")
        XCTAssertEqual(filter.value as? String, "Turning", "Done dismisses the keyboard without changing the local filter")
        let turning = app.buttons["scope-9"]
        XCTAssertTrue(turning.waitForExistence(timeout: 10))
        for _ in 0..<4 where !turning.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(turning.isHittable); turning.tap()
        XCTAssertTrue(app.staticTexts["No discussions in Turning yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Turning"))
        capture(app, "Empty community distinct from search error")
        app.buttons["Choose a community"].tap()
        XCTAssertTrue(app.buttons["scope-cancel"].waitForExistence(timeout: 10), "The empty state opens the chooser")
        app.buttons["scope-cancel"].tap()
    }
    func testScopedAccessFailureRemovesRowsAndKeepsRecoveryVisible() {
        let app = launch(["--search-more-denied"])
        app.buttons["community-scope"].tap()
        // The iPad popover's lazy list creates lower rows only once they scroll into view.
        let electronics = app.buttons["scope-5"]
        for _ in 0..<4 where !electronics.isHittable { app.collectionViews.firstMatch.swipeUp() }
        electronics.tap()
        search(app, "Adaptive")
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        let more = app.buttons["More results"]
        scrollTo(more, in: app); more.tap()
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["topic-9101"].exists)
        XCTAssertFalse(find(app, "search-page-error").exists)
        XCTAssertFalse(find(app, "search-no-results").exists)
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "Adaptive")
        XCTAssertTrue(app.buttons["retry-topic-search"].exists)
        capture(app, "Scoped permission failure removes cached rows and retains recovery")
        app.buttons["community-scope"].tap()
        XCTAssertTrue(app.staticTexts["Community list unavailable"].waitForExistence(timeout: 10))
        app.buttons["scope-cancel"].tap()
        XCTAssertTrue(find(app, "search-error").exists)
        app.buttons["cancel-topic-search"].tap()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
    }
    func testScopeChangeKeepsQueryAndNeverShowsOldScopeResults() {
        let app = launch()
        search(app, "Adaptive")
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        app.buttons["community-scope"].tap()
        app.buttons["scope-9"].tap()
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "Adaptive")
        XCTAssertTrue(find(app, "search-no-results").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["topic-9101"].exists)
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Turning"))
        capture(app, "Query retained in empty selected community")
        app.buttons["community-scope"].tap(); app.buttons["scope-all"].tap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        app.buttons["cancel-topic-search"].tap()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
    }
    func testDarkArabicLargeTextErrorAndCancelStayReachable() {
        let app = launch(["--accessibility-text", "--rtl", "--dark", "--search-initial-fails"])
        recordWindow(app, "Arabic large text actual window")
        capture(app, "Arabic large text initial header")
        let reachableScope = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["community-scope"].isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reachableScope], timeout: 5), .completed)
        app.buttons["community-scope"].tap()
        XCTAssertTrue(app.buttons["scope-cancel"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["scope-cancel"].isHittable)
        capture(app, "Dark Arabic large text community chooser")
        app.buttons["scope-cancel"].tap()
        search(app, "Adaptive")
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["تعذر إكمال البحث. حاول مجددًا."].exists)
        let retry = app.buttons["retry-topic-search"]
        scrollTo(retry, in: app); XCTAssertTrue(retry.isHittable)
        capture(app, "Dark Arabic large text grouped failure")
        retry.tap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["cancel-topic-search"].isHittable)
        app.buttons["cancel-topic-search"].tap()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
        capture(app, "Dark Arabic large text collapsed search")
    }
    func testInlineSearchFailureAccessibilityAudit() throws {
        for arguments in [["--dark", "--search-initial-fails"], ["--dark", "--rtl", "--accessibility-text", "--search-initial-fails"]] {
            let app = launch(arguments)
            search(app, "Adaptive")
            XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Inline error audit hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
            capture(app, "Audited native inline search error")
            app.terminate()
        }
    }
    func testCommunityChooserAccessibilityAudit() throws {
        for arguments in [["--dark"], ["--dark", "--rtl", "--accessibility-text"]] {
            let app = launch(arguments)
            app.buttons["community-scope"].tap()
            let filter = app.textFields["community-filter"]
            // Done ends editing; audit the chooser itself rather than the system keyboard's prediction cells.
            // "Join" keeps a root and a child row that fit the iPad AX form sheet. With "Wood" the last row straddles
            // the sheet's bottom edge and the audit samples the dimmed feed behind its clipped text (iPad, iOS 27).
            XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Join\n")
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertEqual(filter.value as? String, "Join", "Done keeps the filter without a newline")
            XCTAssertTrue(app.buttons["scope-1"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["scope-3"].exists)
            // iPad keeps the system keyboard's prediction strip in the tree after Done; it is not app UI.
            try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
                issue.detailedDescription.contains("TUIPredictionViewCell")
            }
            capture(app, "Audited community chooser with filter")
            app.terminate()
        }
    }
    func testNativeVoiceOverChooserAndSearchRecovery() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_MANUAL_VOICEOVER"] == "1" else {
            throw XCTSkip("Enable native simulator VoiceOver at VO_REVIEW_WAIT_ENABLE")
        }
        var arguments = ["--dark", "--search-initial-fails"]
        if ProcessInfo.processInfo.environment["FOMIO_VOICEOVER_RTL_LARGE"] == "1" {
            arguments += ["--rtl", "--accessibility-text"]
        }
        let app = launch(arguments)
        let initialScopeLabel = app.buttons["community-scope"].label
        addTeardownBlock { @MainActor in
            if UIAccessibility.isVoiceOverRunning {
                NSLog("VO_REVIEW_WAIT_DISABLE")
                let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    !UIAccessibility.isVoiceOverRunning
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 90), .completed,
                               "Restore the original native VoiceOver-off setting before window cleanup")
            }
        }
        capture(app, "VoiceOver review prepared with isolated fixture")
        NSLog("VO_REVIEW_WAIT_ENABLE")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            UIAccessibility.isVoiceOverRunning
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 90), .completed,
                       "Use the actual simulator VoiceOver control")
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let introduction = system.alerts["VoiceOver Gestures"]
        if introduction.waitForExistence(timeout: 5) {
            let okay = introduction.buttons["OK"]
            XCTAssertTrue(okay.waitForExistence(timeout: 60), "Complete the native first-use introduction")
            okay.tap(); okay.doubleTap()
            XCTAssertTrue(introduction.waitForNonExistence(timeout: 10))
        }
        XCTAssertTrue(UIAccessibility.isVoiceOverRunning)
        let scope = app.buttons["community-scope"]
        scope.tap()
        capture(app, "VoiceOver community selector focus before activation")
        scope.doubleTap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        filter.tap(); filter.doubleTap()
        capture(app, "VoiceOver community filter activated for editing")
        filter.typeText("Finishing")
        XCTAssertEqual(filter.value as? String, "Finishing")
        XCTAssertTrue(app.buttons["scope-1"].exists); XCTAssertTrue(app.buttons["scope-2"].exists)
        let cancelScope = app.buttons["scope-cancel"]
        cancelScope.tap()
        capture(app, "VoiceOver chooser Cancel focus")
        cancelScope.doubleTap()
        XCTAssertTrue(filter.waitForNonExistence(timeout: 10))
        XCTAssertEqual(scope.label, initialScopeLabel)
        let reveal = app.buttons["reveal-topic-search"]
        reveal.tap(); reveal.doubleTap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.doubleTap()
        field.typeText("Adaptive\n")
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Adaptive")
        recordWindow(app, "VoiceOver inline search failure")
        capture(app, "VoiceOver failure after native search entry")
        let retry = app.buttons["retry-topic-search"]
        for _ in 0..<12 where !retry.isHittable {
            // Apple's VO-Right Arrow moves to the next accessible item and
            // scrolls it into view, including in a short accessibility-size window.
            app.typeKey(XCUIKeyboardKey.rightArrow.rawValue, modifierFlags: [.control, .option])
        }
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        capture(app, "VoiceOver Retry focus before activation")
        retry.doubleTap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        XCTAssertFalse(find(app, "search-error").exists)
        XCTAssertEqual(field.value as? String, "Adaptive")
        let cancelSearch = app.buttons["cancel-topic-search"]
        cancelSearch.tap(); cancelSearch.doubleTap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))
        XCTAssertTrue(UIAccessibility.isVoiceOverRunning)
        capture(app, "VoiceOver search Cancel returns to scoped feed")
    }
    func testNativeVoiceOverExternalAccessibilityActions() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_EXTERNAL_VOICEOVER_REVIEW"] == "1" else {
            throw XCTSkip("Native accessibility actions are performed at VO_EXTERNAL checkpoints")
        }
        var arguments = ["--dark", "--search-initial-fails"]
        if ProcessInfo.processInfo.environment["FOMIO_VOICEOVER_RTL_LARGE"] == "1" {
            arguments += ["--rtl", "--accessibility-text"]
        }
        let app = launch(arguments)
        let initialScope = app.buttons["community-scope"].label
        addTeardownBlock { @MainActor in
            NSLog("VO_EXTERNAL_WAIT_DISABLE")
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !UIAccessibility.isVoiceOverRunning
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 90), .completed)
        }
        recordWindow(app, "External VoiceOver initial window")
        NSLog("VO_EXTERNAL_WAIT_ENABLE")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in UIAccessibility.isVoiceOverRunning }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 90), .completed)
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 90))
        let filtered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            filter.value as? String == "Finishing" && app.buttons["scope-1"].exists && app.buttons["scope-2"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [filtered], timeout: 90), .completed)
        capture(app, "External VoiceOver filtered chooser and parent")
        NSLog("VO_EXTERNAL_WAIT_CHOOSER_CANCEL")
        XCTAssertTrue(filter.waitForNonExistence(timeout: 90))
        XCTAssertEqual(app.buttons["community-scope"].label, initialScope)
        let error = find(app, "search-error")
        XCTAssertTrue(error.waitForExistence(timeout: 90))
        let field = app.textFields["topic-search-field"]
        XCTAssertEqual(field.value as? String, "Adaptive")
        XCTAssertTrue(app.buttons["retry-topic-search"].exists)
        XCTAssertTrue(app.buttons["cancel-topic-search"].exists)
        recordWindow(app, "External VoiceOver retained error")
        capture(app, "External VoiceOver retained error and recovery actions")
        NSLog("VO_EXTERNAL_WAIT_RETRY")
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 90))
        XCTAssertFalse(error.exists)
        XCTAssertEqual(field.value as? String, "Adaptive")
        NSLog("VO_EXTERNAL_WAIT_SEARCH_CANCEL")
        XCTAssertTrue(field.waitForNonExistence(timeout: 90))
        XCTAssertEqual(app.buttons["community-scope"].label, initialScope)
        XCTAssertTrue(UIAccessibility.isVoiceOverRunning)
        capture(app, "External VoiceOver Cancel restores scoped feed")
    }
    func testIPadScopeAndEmptyCardRespondToNativeTextSize() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_IPAD_NATIVE_TEXT_GROWTH"] == "1" else {
            throw XCTSkip("Requires actual native text-size changes at IPAD_TEXT_GROWTH checkpoints")
        }
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
        let app = launch(["--dark"])
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        filter.tap(); filter.typeText("Turning\n")
        let turning = app.buttons["scope-9"]
        XCTAssertTrue(turning.waitForExistence(timeout: 10)); turning.tap()
        let title = app.staticTexts["No discussions in Turning yet"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let scope = app.buttons["community-scope"]
        let originalScope = scope.label
        let beforeTitle = title.frame.height
        let beforeScope = scope.staticTexts.firstMatch.frame.height
        recordWindow(app, "iPad native standard text before growth")
        NSLog("IPAD_TEXT_GROWTH_WAIT_AX5")
        let grown = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            title.frame.height > beforeTitle * 1.3
                && scope.staticTexts.firstMatch.frame.height > beforeScope * 1.3
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [grown], timeout: 90), .completed,
                       "Both the empty-card heading and scoped selector must respond to actual system text size")
        XCTAssertEqual(scope.label, originalScope)
        recordWindow(app, "iPad native AX5 scope and empty card")
        capture(app, "iPad native AX5 scope and empty card")
        NSLog("IPAD_TEXT_GROWTH_WAIT_LARGE")
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(title.frame.height - beforeTitle) < 2
                && abs(scope.staticTexts.firstMatch.frame.height - beforeScope) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 90), .completed)
        XCTAssertEqual(scope.label, originalScope)
        recordWindow(app, "iPad native text restored")
    }
    func testSearchAndChooserAtSystemAccessibilityTextSize() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_SYSTEM_ACCESSIBILITY_TEXT"] == "1" else {
            throw XCTSkip("Requires the simulator's actual accessibility-extra-extra-extra-large text setting")
        }
        // No --accessibility-text argument: the native system setting must reach SwiftUI.
        let app = launch(["--dark", "--rtl", "--search-initial-fails"])
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(filter.frame.height, 60)
        XCTAssertGreaterThanOrEqual(filter.frame.width, app.windows.firstMatch.frame.width * 0.5, "The input keeps a usable line of text beside decorative icons")
        filter.tap(); filter.typeText("Repairs")
        XCTAssertTrue(app.buttons["scope-6"].waitForExistence(timeout: 10))
        capture(app, "Native system AX5 Arabic community chooser")
        app.buttons["scope-cancel"].tap()
        search(app, "Adaptive")
        let field = app.textFields["topic-search-field"]
        XCTAssertGreaterThanOrEqual(field.frame.height, 60)
        XCTAssertGreaterThanOrEqual(field.frame.width, app.windows.firstMatch.frame.width * 0.5)
        XCTAssertEqual(field.value as? String, "Adaptive")
        XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
        let retry = app.buttons["retry-topic-search"]
        scrollTo(retry, in: app); XCTAssertTrue(retry.isHittable)
        capture(app, "Native system AX5 Arabic search error and Retry")
        retry.tap()
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["cancel-topic-search"].isHittable)
        app.buttons["cancel-topic-search"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))
        capture(app, "Native system AX5 Arabic collapsed search")
    }
    func testSystemTextSizeChangesRetainInputAndKeyboardFocus() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_SYSTEM_FONT_CHANGE"] == "1" else {
            throw XCTSkip("Requires native system text changes at SYSTEM_FONT_WAIT_AX5 and SYSTEM_FONT_WAIT_LARGE")
        }
        let app = launch(["--dark", "--rtl"])
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Repairs")
        XCTAssertLessThan(filter.frame.height, 60)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        NSLog("SYSTEM_FONT_WAIT_AX5")
        let larger = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in filter.frame.height >= 60 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [larger], timeout: 90), .completed)
        XCTAssertEqual(filter.value as? String, "Repairs")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.typeText("x") // No field tap: the same input must retain keyboard focus.
        XCTAssertEqual(filter.value as? String, "Repairsx")
        capture(app, "System size increase retains chooser query and keyboard focus")
        app.buttons["scope-cancel"].tap()
        app.buttons["reveal-topic-search"].tap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText("Adaptive")
        XCTAssertGreaterThanOrEqual(field.frame.height, 60)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        NSLog("SYSTEM_FONT_WAIT_LARGE")
        let smaller = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in field.frame.height < 60 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [smaller], timeout: 90), .completed)
        XCTAssertEqual(field.value as? String, "Adaptive")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.typeText("x")
        XCTAssertEqual(field.value as? String, "Adaptivex")
        capture(app, "System size decrease retains search query and keyboard focus")
        app.buttons["cancel-topic-search"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))
    }
    func testPullAtTopRevealsSearchWithoutReservedRow() {
        let app = launch()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
        let list = app.scrollViews["feed-compact"]
        XCTAssertTrue(list.exists)
        XCTAssertTrue(app.buttons["topic-9101"].waitForExistence(timeout: 10))
        // A deliberate drag at the loaded list's top exercises pull reveal without fling timing.
        // It starts on the first row: the list scrolls under the header, whose height varies with width.
        let start = app.buttons["topic-9101"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: 0, dy: list.frame.height * 0.45)),
            withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(app.textFields["topic-search-field"].waitForExistence(timeout: 10))
        app.buttons["cancel-topic-search"].tap()
        XCTAssertFalse(app.textFields["topic-search-field"].exists)
    }
    func testSearchFieldGrowsAtAccessibilityTextSize() {
        var standardHeight: CGFloat = 0
        for large in [false, true] {
            let app = launch(["--dark", "--search-initial-fails"] + (large ? ["--accessibility-text", "--rtl"] : []))
            search(app, "Adaptive")
            XCTAssertTrue(find(app, "search-error").waitForExistence(timeout: 10))
            let field = app.textFields["topic-search-field"]
            XCTAssertTrue(field.isHittable)
            XCTAssertTrue(app.buttons["retry-topic-search"].isHittable, "Error recovery remains reachable as the preview label grows")
            XCTAssertEqual(field.value as? String, "Adaptive")
            if large { XCTAssertGreaterThan(field.frame.height, standardHeight * 1.4, "Native single-line input height must grow with accessibility text") }
            else { standardHeight = field.frame.height }
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = large ? "Accessibility text field bounds" : "Standard text field bounds"
            hierarchy.lifetime = .keepAlways; add(hierarchy)
            capture(app, large ? "Accessibility text search field" : "Standard text search field")
            app.buttons["cancel-topic-search"].tap()
            XCTAssertFalse(app.textFields["topic-search-field"].exists)
            app.terminate()
        }
    }
    func testSearchOpensExactMatchedReplyAndReturnsToQuery() throws {
        let app = launch()
        XCUIDevice.shared.orientation = .portrait
        guard find(app, "reading-one-pane").waitForExistence(timeout: 10) else {
            throw XCTSkip("Compact Back requires an actual one-pane window; wide query retention is tested separately")
        }
        search(app, "cracked diode")
        let topic = app.buttons["topic-4190"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        XCTAssertTrue(topic.label.contains("match in reply 14"))
        topic.tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["#14"].isHittable, "Search opens the matched post number, rather than interpreting its PostID as a number")
        app.buttons["back-to-topic-list"].tap()
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "cracked diode")
        capture(app, "Exact reply search returns to retained query")
    }
    func testSavedReplyOpensExactPostContext() {
        let app = launch()
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        XCTAssertTrue(app.buttons["me-saved"].waitForExistence(timeout: 10)); app.buttons["me-saved"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved reply 14 in")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["#14"].isHittable)
        capture(app, "Saved reply opens exact post context")
    }
    func testPublicLinkRendersExactReplyOutsidePreviousCommunity() {
        let app = launch(["--preset", "public-link", "--dark"], waitForScope: false)
        XCTAssertTrue(app.staticTexts["#14"].waitForExistence(timeout: 10))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.staticTexts["#14"].isHittable }, object: nil)
        let becameVisible = XCTWaiter.wait(for: [visible], timeout: 5)
        recordWindow(app, "Public link exact destination")
        capture(app, "Public link exact destination")
        XCTAssertEqual(becameVisible, .completed)
        XCTAssertFalse(app.staticTexts["Discussion outside this community"].exists)
        XCTAssertTrue(app.buttons["discussion-reply"].exists)
        if app.buttons["back-to-topic-list"].exists { app.buttons["back-to-topic-list"].tap() }
        XCTAssertTrue(app.buttons["community-scope"].label.contains("All communities"))
        capture(app, "Public link uses All and exact fictional reply")
    }
    func testOutsideScopeReturnRetainsExactSearchReply() throws {
        let app = launch(["--dark"])
        var rotated = false
        defer { if rotated { XCUIDevice.shared.orientation = .portrait } }
        if !find(app, "reading-two-pane").exists {
            let before = app.windows.firstMatch.frame.size
            XCUIDevice.shared.orientation = .landscapeLeft; rotated = true
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(app.windows.firstMatch.frame.width - before.width) > 100
            }, object: nil)
            guard XCTWaiter.wait(for: [changed], timeout: 15) == .completed else {
                throw XCTSkip("Requires an actual window wide enough to show list and reading together")
            }
        }
        guard find(app, "reading-two-pane").waitForExistence(timeout: 10) else {
            throw XCTSkip("The actual rotated window cannot fit two readable columns")
        }
        search(app, "cracked diode")
        let topic = app.buttons["topic-4190"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); topic.tap()
        let post = app.staticTexts["#14"]
        XCTAssertTrue(post.waitForExistence(timeout: 10))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in post.isHittable }, object: nil)
        let becameVisible = XCTWaiter.wait(for: [visible], timeout: 5)
        recordWindow(app, "Exact reply before scope exclusion")
        capture(app, "Exact reply before scope exclusion")
        XCTAssertEqual(becameVisible, .completed, "The exact reply header must be visible in the short wide window")
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Turning")
        let choice = app.buttons["scope-9"]
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
        for _ in 0..<4 where !choice.isHittable { app.collectionViews.firstMatch.swipeUp() }
        choice.tap()
        XCTAssertTrue(app.staticTexts["Discussion outside this community"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["discussion-reply"].exists)
        capture(app, "Exact discussion excluded by unrelated community")
        let restore = app.buttons.matching(NSPredicate(format: "label == %@", "All communities")).firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 10)); restore.tap()
        XCTAssertTrue(post.waitForExistence(timeout: 10))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in post.isHittable }, object: nil)
        let restoredVisible = XCTWaiter.wait(for: [restored], timeout: 5)
        recordWindow(app, "Exact reply after restoring All")
        capture(app, "Exact reply after restoring All")
        XCTAssertEqual(restoredVisible, .completed, "Restoring All keeps the exact reply readable")
        XCTAssertTrue(app.buttons["discussion-reply"].exists)
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "cracked diode")
        capture(app, "All restores exact reply and original query")

        // Returning from a scope exclusion must retain a reader's newer position,
        // rather than always jumping back to the original highlighted match.
        let opening = app.staticTexts["#1"]
        let discussion = app.scrollViews["discussion-content"]
        for _ in 0..<8 where !opening.isHittable { discussion.swipeDown() }
        XCTAssertTrue(opening.isHittable)
        app.buttons["community-scope"].tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Turning")
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
        for _ in 0..<4 where !choice.isHittable { app.collectionViews.firstMatch.swipeUp() }
        choice.tap()
        XCTAssertTrue(app.staticTexts["Discussion outside this community"].waitForExistence(timeout: 10))
        XCTAssertTrue(restore.waitForExistence(timeout: 10)); restore.tap()
        let retained = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in opening.isHittable }, object: nil)
        let retainedVisible = XCTWaiter.wait(for: [retained], timeout: 5)
        recordWindow(app, "Reader position after second scope return")
        capture(app, "Reader position after second scope return")
        XCTAssertEqual(retainedVisible, .completed, "Returning to All preserves the newer reader position")
    }
    func testSelectedDiscussionReturnsToRetainedSearch() throws {
        let app = launch()
        // Back to the list exists only when list and discussion share one pane.
        guard find(app, "reading-one-pane").exists else { throw XCTSkip("Requires the one-pane layout, where the list and discussion alternate") }
        search(app, "Adaptive")
        let topic = app.buttons["topic-9101"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10))
        let back = app.buttons["back-to-topic-list"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(app.textFields["topic-search-field"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "Adaptive")
        XCTAssertTrue(topic.exists)
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10), "Reselecting the same topic must reopen detail")
        app.buttons["back-to-topic-list"].tap()
        capture(app, "Retained search and exact discussion return")
    }
}
