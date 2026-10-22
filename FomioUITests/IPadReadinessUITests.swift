import XCTest
import UIKit

@MainActor final class IPadReadinessUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) throws -> XCUIApplication {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad window acceptance") }
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 30))
        let window = app.windows.firstMatch
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard").frame
        if window.frame.width < screen.width - 40 {
            let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -6, dy: -6))
            let fullSize = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: screen.width - 6, dy: screen.height - 6))
            corner.press(forDuration: 1, thenDragTo: fullSize)
            let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                window.frame.width >= screen.width - 40
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 10), .completed)
        }
        let header = app.otherElements["browse-header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        let label = app.buttons["community-scope"].staticTexts.firstMatch
        XCTAssertGreaterThanOrEqual(label.frame.width, 90, "Scope must not collapse to one or two characters")
        XCTAssertGreaterThanOrEqual(app.buttons["community-scope"].frame.height + 0.001, 44)
        XCTAssertGreaterThanOrEqual(label.frame.minX, header.frame.minX - 1)
        XCTAssertLessThanOrEqual(label.frame.maxX, header.frame.maxX + 1)
        XCTAssertLessThanOrEqual(label.frame.maxY, header.frame.maxY + 1)
        if !arguments.contains("--accessibility-text") {
            let visible = app.buttons["community-scope"].frame
                .union(app.buttons["reveal-topic-search"].frame)
                .union(app.buttons["feed-options"].frame)
            XCTAssertLessThanOrEqual(visible.height + 12, 80,
                                     "Scope/actions plus padding must occupy one compact header, excluding the OS safe area")
        }
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func revealChoice(_ choice: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if choice.exists && choice.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(choice.exists && choice.isHittable)
    }
    private func rotateToPortrait(_ app: XCUIApplication) {
        let before = app.windows.firstMatch.frame.size
        XCUIDevice.shared.orientation = .portrait
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let size = app.windows.firstMatch.frame.size
            return size.width < size.height && abs(size.width - before.width) > 50
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed,
                       "An orientation request alone does not prove that the iPad window resized")
    }
    func testWideSidebarScopesAndExcludedDiscussionReturn() throws {
        let app = try launch()
        guard app.windows.firstMatch.frame.width >= 1080 else { throw XCTSkip("Requires an actual wide iPad window") }
        XCTAssertTrue(app.otherElements["reading-three-pane"].waitForExistence(timeout: 10))
        let topic = app.buttons["topic-4190"]
        XCTAssertTrue(topic.waitForExistence(timeout: 15)); topic.tap()
        let reply = app.buttons["discussion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        app.buttons["sidebar-1"].tap()
        XCTAssertTrue(app.buttons["sidebar-9"].waitForExistence(timeout: 10)); app.buttons["sidebar-9"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Turning"))
        XCTAssertTrue(app.staticTexts["Discussion outside this community"].waitForExistence(timeout: 10))
        XCTAssertFalse(reply.exists)
        capture(app, "Wide iPad excludes selected discussion outside Turning")
        if ProcessInfo.processInfo.environment["FOMIO_IPAD_ACCESSIBILITY_AUDIT"] == "1" { try audit(app) }
        app.buttons["sidebar-all"].tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertTrue(topic.isSelected, "All restores the same selected topic")
        app.buttons["sidebar-5"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Electronics"))
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); XCTAssertTrue(topic.isSelected)
        XCTAssertTrue(reply.exists, "Electronics includes the selected Repairs discussion")
        XCTAssertTrue(app.buttons["sidebar-6"].waitForExistence(timeout: 10)); app.buttons["sidebar-6"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Repairs"))
        XCTAssertTrue(topic.waitForExistence(timeout: 10)); XCTAssertTrue(topic.isSelected); XCTAssertTrue(reply.exists)
        app.buttons["sidebar-all"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("All communities"))
        XCTAssertTrue(app.buttons["Home"].isSelected, "Scope changes stay in the originating Home tab")
        XCTAssertTrue(topic.isSelected); XCTAssertTrue(reply.exists)
        capture(app, "Wide iPad sidebar root child All parity and retained discussion")
        app.buttons["hide-sidebar"].tap()
        XCTAssertTrue(app.otherElements["reading-two-pane"].waitForExistence(timeout: 10), "Hiding the sidebar leaves list and discussion")
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10), "Destinations return to the tab bar")
        XCTAssertTrue(topic.isSelected); XCTAssertTrue(reply.exists)
        capture(app, "Wide iPad with sidebar hidden")
        app.buttons["show-sidebar"].tap()
        XCTAssertTrue(app.otherElements["reading-three-pane"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sidebar-all"].isSelected)
    }
    func testNewWindowStartsWithIndependentBrowsing() throws {
        let app = try launch()
        app.buttons["community-scope"].tap()
        revealChoice(app.buttons["scope-2"], in: app)
        app.buttons["scope-2"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Finishing"))
        app.buttons["feed-options"].tap()
        let newWindow = app.buttons["new-browsing-window"]
        XCTAssertTrue(newWindow.waitForExistence(timeout: 5)); newWindow.tap()
        let independent = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons.matching(identifier: "community-scope").allElementsBoundByIndex.contains { $0.label.contains("All communities") && $0.isHittable }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [independent], timeout: 15), .completed)
        let scopes = app.buttons.matching(identifier: "community-scope").allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(scopes.count, 2, "Two native scenes must remain mounted")
        XCTAssertTrue(scopes.contains { $0.label.contains("Finishing") }, "Original scene retains its selected scope")
        capture(app, "Independent iPad browsing windows")
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "Native windows hierarchy"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testListDetailAndReplySurviveWindowRotation() throws {
        let app = try launch()
        let topic = app.buttons["topic-4182"]
        XCTAssertTrue(topic.waitForExistence(timeout: 15)); topic.tap()
        let reply = app.buttons["discussion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 15))
        XCTAssertTrue(topic.isHittable, "List and selected discussion must be visible together")
        capture(app, "iPad landscape list and discussion")
        reply.tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap(); body.typeText("iPad retained reply")
        rotateToPortrait(app)
        XCTAssertEqual(body.value as? String, "iPad retained reply")
        XCTAssertTrue(app.buttons["composer-close"].isHittable)
        capture(app, "iPad portrait retained composer")
        app.buttons["composer-close"].tap()
        app.buttons["Keep draft"].tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertTrue(topic.isHittable)
        capture(app, "iPad portrait retained reading selection")
    }
    func testOpenCommunityChooserRetainsFilterAcrossRotation() throws {
        let app = try launch()
        app.buttons["community-scope"].tap()
        let filter = app.textFields["community-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10)); filter.tap(); filter.typeText("Finishing")
        revealChoice(app.buttons["scope-2"], in: app)
        rotateToPortrait(app)
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        XCTAssertEqual(filter.value as? String, "Finishing")
        XCTAssertTrue(app.buttons["scope-1"].exists, "Matching child retains parent context")
        revealChoice(app.buttons["scope-2"], in: app)
        app.buttons["scope-2"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Finishing"))
        capture(app, "iPad chooser selection retained after rotation")
    }
    func testLargeTextRTLSearchAndChooserRemainReachable() throws {
        let app = try launch(["--accessibility-text", "--rtl", "--dark"])
        let wide = app.windows.firstMatch.frame.width >= 1340
        if wide { XCTAssertTrue(app.otherElements["reading-two-pane"].exists, "AX3 minima (×1.85) keep two panes at 1366 pt") }
        XCTAssertTrue(app.buttons["community-scope"].isHittable)
        app.buttons["community-scope"].tap()
        XCTAssertTrue(app.buttons["scope-cancel"].waitForExistence(timeout: 10))
        if wide { XCTAssertGreaterThan(app.textFields["community-filter"].frame.width, 400, "Large/AX text uses the form sheet, not the 360 pt popover") }
        capture(app, "iPad RTL accessibility community chooser")
        app.buttons["scope-cancel"].tap()
        // The form sheet dismisses with an animation; the header is covered until it finishes.
        XCTAssertTrue(app.buttons["scope-cancel"].waitForNonExistence(timeout: 10))
        let reveal = app.buttons["reveal-topic-search"]
        XCTAssertTrue(reveal.isHittable); reveal.tap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText("noipadresultszz\n")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "search-no-results").firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["cancel-topic-search"].isHittable)
        capture(app, "iPad dark RTL accessibility search")
        app.buttons["cancel-topic-search"].tap()
        XCTAssertFalse(field.exists)
    }

    func testNativeAccessibilityAuditWithSystemTextSizing() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_IPAD_ACCESSIBILITY_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in native audit: runtime completion must be recorded separately from layout checks")
        }
        let app = try launch(["--rtl", "--dark"])
        app.buttons["reveal-topic-search"].tap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText("noipadresultszz\n")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "search-no-results").firstMatch.waitForExistence(timeout: 10))
        // Let the audit vary system text size; --accessibility-text intentionally
        // fixes AX3 for the separate layout journey above.
        try audit(app)
        capture(app, "iPad system-sized RTL native accessibility audit")
    }
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            let detail = issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? "No associated element")
            let attachment = XCTAttachment(string: detail)
            attachment.name = "Unfiltered iPad audit issue"; attachment.lifetime = .keepAlways; self.add(attachment)
            return false
        }
    }
    func testNativeNarrowWindowKeepsQueryAndSelection() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_IPAD_WINDOW_RESIZE"] == "1" else {
            throw XCTSkip("Requires an iPadOS window with the native corner resize affordance")
        }
        let app = try launch()
        app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10))
        app.buttons["reveal-topic-search"].tap()
        let field = app.textFields["topic-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText("walnut\n")
        guard narrowWindow(app) else { return }
        let back = app.buttons["back-to-topic-list"]
        XCTAssertTrue(back.waitForExistence(timeout: 10)); back.tap()
        XCTAssertEqual(field.value as? String, "walnut")
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10))
        app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10))
        capture(app, "Narrow iPad retained search and selected discussion")
    }

    func testNativeResizeKeepsReplyAndKeyboardFocus() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_IPAD_WINDOW_RESIZE"] == "1" else {
            throw XCTSkip("Requires an iPadOS window with the native corner resize affordance")
        }
        let app = try launch()
        guard narrowWindow(app) else { return }
        app.buttons["topic-4182"].tap()
        let reply = app.buttons["discussion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10)); reply.tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap(); body.typeText("Window retained writing")
        guard maximizeUsingSystemControls(app) else { return }
        XCTAssertEqual(body.value as? String, "Window retained writing")
        // Send directly to the focused app, without tapping/refocusing the editor.
        // A hardware window shortcut can hide the software keyboard legitimately.
        app.typeKey(".", modifierFlags: [])
        XCTAssertEqual(body.value as? String, "Window retained writing.")
        XCTAssertTrue(app.buttons["composer-close"].isHittable)
        capture(app, "Resized iPad reply keeps writing and keyboard focus")
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
    }

    func testNativeResizeKeepsOpenChooserFilter() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_IPAD_WINDOW_RESIZE"] == "1" else {
            throw XCTSkip("Requires an iPadOS window with the native corner resize affordance")
        }
        let app = try launch()
        guard narrowWindow(app) else { return }
        app.buttons["community-scope"].tap()
        let field = app.textFields["community-filter"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText("Finishing")
        addTeardownBlock { @MainActor in
            let cancel = app.buttons["scope-cancel"]
            if cancel.exists && cancel.isHittable { cancel.tap() }
        }
        guard maximizeUsingSystemControls(app) else { return }
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Finishing")
        XCTAssertTrue(app.buttons["scope-cancel"].isHittable)
        capture(app, "Resized iPad chooser keeps its open filter")
        app.buttons["scope-cancel"].tap()
        XCTAssertTrue(app.buttons["community-scope"].label.contains("All communities"))
    }

    private func maximizeUsingSystemControls(_ app: XCUIApplication) -> Bool {
        let before = app.windows.firstMatch.frame
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let controls = system.buttons["window-controls:com.fomio.mobile"]
        guard controls.waitForExistence(timeout: 5), controls.isHittable else {
            XCTFail("Native window controls are unavailable; active presentation resize remains unverified"); return false
        }
        capture(app, "Active presentation before native system window action")
        controls.tap()
        let attachment = XCTAttachment(string: system.debugDescription)
        attachment.name = "Native multitasking menu"; attachment.lifetime = .keepAlways; add(attachment)
        let zoom = system.buttons["Zoom-button"]
        guard zoom.waitForExistence(timeout: 5) else {
            XCTFail("Native Zoom action is unavailable; active presentation resize remains unverified"); return false
        }
        zoom.tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.state == .runningForeground && app.windows.firstMatch.frame.width >= 720 && app.windows.firstMatch.frame.width > before.width + 100 && app.windows.firstMatch.frame.height >= 490
        }, object: nil)
        let result = XCTWaiter.wait(for: [expanded], timeout: 10)
        capture(app, "Active presentation after native system window action")
        guard result == .completed else { XCTFail("Native action did not expand the active window"); return false }
        return true
    }
    private func narrowWindow(_ app: XCUIApplication, useKeyboard: Bool = false) -> Bool {
        let window = app.windows.firstMatch
        let before = window.frame
        addTeardownBlock { @MainActor in
            app.activate()
            if window.frame.width >= before.width - 20 { return }
            if useKeyboard {
                app.typeKey("f", modifierFlags: .function)
            } else {
                let resizeCorner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                    .withOffset(CGVector(dx: -6, dy: -6))
                let restore = window.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: before.width - 6, dy: before.height - 6))
                resizeCorner.press(forDuration: 1, thenDragTo: restore)
            }
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                window.frame.width >= before.width - 20
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed,
                           "Restore the OS window so later journeys start at their intended width")
        }
        capture(app, "Before native iPad window resize")
        // Control-Globe-Left is Apple's native half-screen tiling shortcut. It
        // avoids the bottom-edge overview gesture when a modal owns interaction.
        if useKeyboard {
            app.typeKey(.leftArrow, modifierFlags: [.control, .function])
        } else {
            let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -6, dy: -6))
            let target = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 600, dy: min(before.height - 80, 700)))
            corner.press(forDuration: 1, thenDragTo: target)
        }
        let narrowed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = window.frame
            return app.state == .runningForeground && frame.width < 720 && frame.width < before.width - 100 && frame.height >= 490
        }, object: nil)
        let result = XCTWaiter.wait(for: [narrowed], timeout: 10)
        capture(app, "After native iPad window resize attempt")
        if result != .completed {
            let tree = XCTAttachment(string: app.debugDescription + "\nSYSTEM\n" + XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
            tree.name = "Native window controls"; tree.lifetime = .keepAlways; add(tree)
            XCTFail("Native resize did not produce a window below 720pt; narrow-window acceptance remains unverified")
            return false
        }
        let controls = XCTAttachment(string: XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
        controls.name = "Live narrow window system controls"; controls.lifetime = .keepAlways; add(controls)
        return true
    }
}
