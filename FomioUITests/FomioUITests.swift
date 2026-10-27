import XCTest
import UIKit

/// Opt-in Device Hub width journeys and a probe that attaches to a prepared reply.
/// The attach-only probe never launches, activates or rotates the app.
@MainActor final class PreparedReplyResizeUITests: XCTestCase {
    func testTypedHistoryAfterWidthCycle() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_TYPED_WIDTH_HISTORY_PROBE"] == "1" else {
            throw XCTSkip("Requires the same manually resized reply containing Qqq on the normal display")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.fomio.mobile")
        XCTAssertEqual(app.state, .runningForeground)
        let body = app.textViews["composer-body"]
        XCTAssertEqual(body.value as? String, "Qqq")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        for (label, expected) in [("Undo", "Qq"), ("Redo", "Qqq")] {
            app.buttons["composer-more"].tap()
            let action = app.buttons[label]
            XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isEnabled)
            action.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", expected), object: body)], timeout: 10), .completed)
            XCTAssertTrue(app.keyboards.firstMatch.exists)
        }
    }
    func testKeyboardAndHistoryAcrossManualWidths() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_KEYBOARD_WIDTH_JOURNEY"] == "1" else {
            throw XCTSkip("Requires Device Hub compact → regular → compact width controls")
        }
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.fomio.mobile")
        app.launchArguments = ["--fixture", "--ui-testing"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 15))
        app.buttons["topic-4182"].tap()
        app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap(); body.typeText("Trait draft.")
        func history(_ label: String, expected: String) {
            app.buttons["composer-more"].tap()
            let action = app.buttons[label]
            XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isEnabled)
            action.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", expected), object: body)], timeout: 10), .completed)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        }
        history("Undo", expected: "Trait draft")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let initialCapture = XCTAttachment(screenshot: app.screenshot())
        initialCapture.name = "Compact before expansion"; initialCapture.lifetime = .keepAlways; add(initialCapture)
        let displayScale = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.scale ?? 1
        var redoText = "Trait draft."
        for (name, regular) in [("Regular", true), ("Compact returned", false)] {
            NSLog("KEYBOARD_WIDTH_WAIT_%@", name)
            let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let expected = CGSize(width: regular ? 1000 : 466, height: 678)
                let window = app.windows.firstMatch.frame.size
                // Resize-mode accessibility can report the window divided by
                // display scale, while the Application frame remains stale.
                return [app.frame.size, window,
                        CGSize(width: window.width * displayScale, height: window.height * displayScale)]
                    .contains { abs($0.width - expected.width) < 1 && abs($0.height - expected.height) < 1 }
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 180), .completed)
            XCTAssertEqual(body.value as? String, "Trait draft")
            XCTAssertTrue(app.keyboards.firstMatch.exists)
            let more = app.buttons["composer-more"]
            NSLog("KEYBOARD_WIDTH_GEOMETRY %@ app=%@ window=%@ more=%@ keyboard=%@ hittable=%d", name, NSCoder.string(for: app.frame), NSCoder.string(for: app.windows.firstMatch.frame), NSCoder.string(for: more.frame), NSCoder.string(for: app.keyboards.firstMatch.frame), more.isHittable)
            let geometryCapture = XCTAttachment(screenshot: app.screenshot())
            geometryCapture.name = name + " keyboard geometry"; geometryCapture.lifetime = .keepAlways; add(geometryCapture)
            if ProcessInfo.processInfo.environment["FOMIO_KEYBOARD_GEOMETRY_HOLD"] == "1" {
                NSLog("KEYBOARD_WIDTH_INSPECT %@", app.debugDescription)
                _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(value: false), object: nil)], timeout: 60)
            }
            let clear = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                more.isHittable && more.frame.maxY <= app.keyboards.firstMatch.frame.minY
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [clear], timeout: 10), .completed)
            XCTAssertLessThanOrEqual(more.frame.maxY, app.keyboards.firstMatch.frame.minY)
            history("Redo", expected: redoText)
            history("Undo", expected: "Trait draft")
            body.typeText("q")
            XCTAssertEqual(body.value as? String, "Trait draftq")
            history("Undo", expected: "Trait draft")
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = name; capture.lifetime = .keepAlways; add(capture)
            redoText = "Trait draftq"
        }
    }
    func testPendingHistoryAndKeyboard() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_REPLY_RESIZE_PROBE"] == "1" else {
            throw XCTSkip("Requires a prepared fixture reply with pending redo and manual window resizing")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.fomio.mobile")
        XCTAssertEqual(app.state, .runningForeground)
        let body = app.textViews["composer-body"]
        XCTAssertEqual(body.value as? String, "Trait draft")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        func assertBarAboveKeyboard() {
            let more = app.buttons["composer-more"]
            XCTAssertTrue(more.isHittable)
            XCTAssertLessThanOrEqual(more.frame.maxY, app.keyboards.firstMatch.frame.minY,
                                     "Formatting must remain above docked and floating keyboards")
        }
        assertBarAboveKeyboard()
        func history(_ label: String, expected: String) {
            app.buttons["composer-more"].tap()
            let action = app.buttons[label]
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            XCTAssertTrue(action.isEnabled)
            action.tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: body)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
            XCTAssertTrue(app.keyboards.firstMatch.exists)
            assertBarAboveKeyboard()
        }
        history("Redo", expected: "Trait draft.")
        history("Undo", expected: "Trait draft")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Prepared reply resize history and keyboard"; capture.lifetime = .keepAlways; add(capture)
    }
}

@MainActor final class FomioUITests: XCTestCase {
    func testComposerMoreRefreshesUndoRedoAfterEachAction() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap(); body.typeText("Menu history.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            for (label, expected) in [("Undo", "Menu history"), ("Redo", "Menu history.")] {
                app.buttons["composer-more"].tap()
                let action = menuAction(app, label)
                let appeared = action.waitForExistence(timeout: 5)
                if !appeared {
                    let capture = XCTAttachment(screenshot: app.screenshot())
                    capture.name = "More failed to expose " + label
                    capture.lifetime = .keepAlways; add(capture)
                    let hierarchy = XCTAttachment(string: app.debugDescription)
                    hierarchy.name = "Missing menu action hierarchy"
                    hierarchy.lifetime = .keepAlways; add(hierarchy)
                }
                XCTAssertTrue(appeared, "More must expose " + label); XCTAssertTrue(action.isEnabled)
                action.tap()
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", expected), object: body)], timeout: 10), .completed)
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            }
        }
    }
    func testDuoPhotoReplyAcrossManualFolds() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_DUO_PHOTO_TEST"] == "1" else { throw XCTSkip("Requires Duo fold controls and native photo-picker selection") }
        let app = launch(["--upload-fails"])
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        do {
            body.tap(); body.typeText("Photo fold draft.")
            tapSettled(app, app.buttons["composer-more"]); app.buttons["Add photo"].tap()
            NSLog("DUO_PHOTO_PICKER_READY")
            // The known fixture is the first item in the provisioned simulator's grid.
            let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 30), app.debugDescription)
            photo.tap()
            let confirmPhoto = app.buttons["Done"]
            XCTAssertTrue(confirmPhoto.waitForExistence(timeout: 5), app.debugDescription)
            confirmPhoto.tap()
        }
        XCTAssertTrue(app.buttons["Retry upload"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.buttons.matching(identifier: "Retry upload").count, 1)
        let rich = try XCTUnwrap(body.value as? String)
        XCTAssertTrue(rich.contains("Photo fold draft."))
        func capture(_ name: String) {
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
        }
        func fold(_ marker: String, expected: String) {
            let before = app.frame.size
            NSLog("DUO_PHOTO_WAIT_%@ width=%f height=%f", marker, before.width, before.height)
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(app.frame.width - before.width) > 50 || abs(app.frame.height - before.height) > 50
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 120), .completed, "Use Device Hub's fold control")
            XCTAssertEqual(body.value as? String, expected)
            XCTAssertEqual(app.buttons.matching(identifier: "Retry upload").count, 1)
            let post = app.descendants(matching: .any).matching(identifier: "composer-post").firstMatch
            XCTAssertTrue(post.waitForExistence(timeout: 10), "Post remains present after the sheet transition")
            XCTAssertFalse(post.isEnabled)
            capture(marker)
        }
        capture("Photo inserted closed")
        fold("RICH_OPEN", expected: rich)
        fold("RICH_CLOSED", expected: rich)
        app.buttons["composer-more"].tap(); app.buttons["Edit in Markdown"].tap()
        let source = try XCTUnwrap(body.value as? String)
        XCTAssertTrue(source.contains("Photo fold draft.")); XCTAssertTrue(source.contains("fomio-attachment://"))
        XCTAssertEqual(source.components(separatedBy: "fomio-attachment://").count - 1, 1)
        fold("MARKDOWN_OPEN", expected: source)
        XCTAssertTrue(app.buttons["composer-preview"].exists)
        fold("MARKDOWN_CLOSED", expected: source)
        XCTAssertTrue(app.buttons["composer-preview"].exists)
        app.buttons["composer-close"].tap()
        XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 10)); app.buttons["Keep draft"].tap()
        app.buttons.matching(identifier: "Me").firstMatch.tap(); app.buttons["me-drafts"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Oil vs. hardwax on a walnut desk top?")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.buttons["Resume upload"].waitForExistence(timeout: 10))
        app.buttons["composer-more"].tap(); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, source)
        XCTAssertEqual(app.buttons.matching(identifier: "Resume upload").count, 1)
        capture("Saved photo reply reopened")
    }
    func testDuoPendingMarkdownRedoProbe() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_DUO_REDO_PROBE"] == "1" else { throw XCTSkip("Requires the prepared fixture reply with pending redo") }
        let app = XCUIApplication(bundleIdentifier: "com.fomio.mobile")
        guard app.state == .runningForeground else { throw XCTSkip("Prepared app must remain running") }
        let body = app.textViews["composer-body"]
        XCTAssertEqual(body.value as? String, "**Duo** reply.\n\n- q")
        XCTAssertTrue(app.buttons["composer-preview"].exists)
        app.buttons["composer-more"].tap()
        let redo = app.buttons["Redo"]
        XCTAssertTrue(redo.waitForExistence(timeout: 5))
        XCTAssertTrue(redo.isEnabled)
        redo.tap()
        XCTAssertTrue(NSPredicate(format: "value == %@", "**Duo** reply.\n\n- qq").evaluate(with: body) || XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "**Duo** reply.\n\n- qq"), evaluatedWith: body)], timeout: 10) == .completed)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Markdown redo after unfolding"; capture.lifetime = .keepAlways; add(capture)
    }
    func testCaptureIllustrativeStoreScreenshots() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_STORE_CAPTURES"] == "1" else { throw XCTSkip("Store captures require explicit opt-in") }
        let app = launch(["--store-preview"])
        let topic = app.buttons["topic-4188"]
        XCTAssertTrue(topic.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["fixture-banner"].exists)
        func capture(_ name: String) {
            Thread.sleep(forTimeInterval: 1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        capture("Illustrative-01-Home")
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-share"].waitForExistence(timeout: 10))
        capture("Illustrative-02-Discussion")
        app.swipeUp()
        capture("Illustrative-04-Replies")
        app.buttons.matching(identifier: "Communities").firstMatch.tap()
        XCTAssertTrue(app.buttons["community-1"].waitForExistence(timeout: 10))
        capture("Illustrative-03-Communities")
    }
    func testCaptureLiveStoreScreenshots() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_STORE_CAPTURES"] == "1" else { throw XCTSkip("Store captures require explicit live read opt-in") }
        let app = launch(["--live"])
        let topic = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "topic-[0-9]+" )).firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 30))
        func capture(_ name: String) {
            // Let the iPad tab/toolbar transition finish before recording a store asset.
            Thread.sleep(forTimeInterval: 1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        capture("Store-01-Home")
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-share"].waitForExistence(timeout: 20))
        capture("Store-02-Discussion")
        app.buttons.matching(identifier: "Communities").firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "community-[0-9]+" )).firstMatch.waitForExistence(timeout: 20))
        capture("Store-03-Communities")
        XCTAssertFalse(app.staticTexts["Fixture preview"].exists)
    }
    func testReportCustomReasonAndBlockThenUnblock() {
        let app = launch()
        app.buttons["topic-4182"].tap()
        let safety = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Report or block @")).firstMatch
        XCTAssertTrue(safety.waitForExistence(timeout: 5)); safety.tap()
        app.buttons["Report post"].tap()
        let reason = app.buttons["Something else"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5)); reason.tap()
        XCTAssertFalse(app.buttons["Send report"].isEnabled)
        let details = app.textFields["Explain your concern"]
        XCTAssertTrue(details.waitForExistence(timeout: 5)); details.tap(); details.typeText("Fictional concern for the fixture moderators")
        app.buttons["Send report"].tap()
        XCTAssertTrue(safety.waitForExistence(timeout: 5)); safety.tap()
        app.buttons["Block member…"].tap()
        let confirm = app.buttons["Block member"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Hidden because you blocked @")).firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        app.buttons["Blocked members"].tap()
        let unblock = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "unblock-")).firstMatch
        XCTAssertTrue(unblock.waitForExistence(timeout: 5)); unblock.tap()
        let confirmUnblock = app.buttons["Unblock member"].firstMatch
        XCTAssertTrue(confirmUnblock.waitForExistence(timeout: 5)); confirmUnblock.tap()
        XCTAssertTrue(app.staticTexts["No blocked members"].waitForExistence(timeout: 5))
    }
    func testRestrictedAccountDeletionExplainsSupportAndCanBeCancelled() {
        let app = launch()
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        let delete = app.buttons["Delete account…"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10)); delete.tap()
        XCTAssertTrue(app.staticTexts["This account cannot be deleted automatically. Contact support for help deleting your account and associated data."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete account permanently"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Restricted account deletion"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["Close"].tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign out"].exists)
    }
    func testLiveCategoryChildAboutAndTopicNavigation() throws {
        guard ProcessInfo.processInfo.environment["FOMIO_LIVE_UI_TESTS"] == "1" else { throw XCTSkip("Live UI reads require explicit opt-in") }
        let app = launch(["--live"])
        let communities = app.buttons["Communities"].firstMatch
        XCTAssertTrue(communities.waitForExistence(timeout: 20)); communities.tap()
        XCTAssertTrue(app.buttons["community-42"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["community-11"].exists)
        for id in [34, 49, 50, 51, 52, 53] { XCTAssertFalse(app.buttons["community-\(id)"].exists) }
        let consolidated = XCTAttachment(screenshot: app.screenshot()); consolidated.name = "Live consolidated General hierarchy and native icons"; consolidated.lifetime = .keepAlways; add(consolidated)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 20)); search.tap(); search.typeText("Experiments\n")
        let child = app.buttons["community-54"]
        XCTAssertTrue(child.waitForExistence(timeout: 15)); XCTAssertTrue(app.buttons["community-45"].exists)
        let directory = XCTAttachment(screenshot: app.screenshot()); directory.name = "Live root and child category identity"; directory.lifetime = .keepAlways; add(directory)
        child.tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 15)); about.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        let topic = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "topic-[0-9]+" )).firstMatch
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
        app.buttons["feed-options"].tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 5)); about.tap()
        XCTAssertTrue(app.staticTexts["Planes, saws, chisels and keeping them sharp."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        newDiscussionControl(app, title: "New discussion in Hand Tools").tap()
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
        XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["community-scope"].label.contains("Finishing"))
        // Duo moves the system Back action into its native rail, outside the navigation bar.
        let railBack = app.buttons["BackButton"]
        if railBack.exists { railBack.tap() }
        else { app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Communities' OR label == 'Back'")).firstMatch.tap() }
        XCTAssertTrue(child.waitForExistence(timeout: 5)); XCTAssertEqual(search.value as? String, "Finishing")
        XCTAssertFalse(app.buttons["community-5"].exists)
    }
    func testCategoryDarkLargeTextAndThemeReflow() {
        let app = launch(["--preset", "communities", "--dark", "--accessibility-text", "--teal-theme"])
        let root = app.buttons["community-1"]; XCTAssertTrue(root.waitForExistence(timeout: 10)); root.tap()
        let scope = app.buttons["community-scope"]
        XCTAssertTrue(scope.isHittable); XCTAssertGreaterThanOrEqual(scope.frame.height, 44)
        app.buttons["feed-options"].tap()
        let about = app.buttons["community-about"]; XCTAssertTrue(about.waitForExistence(timeout: 5))
        // Native menu rows use system metrics; check 44-point sizing on our custom selector.
        XCTAssertTrue(about.isHittable)
        XCTAssertTrue(app.buttons["feed-create"].exists)
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
    func testHeadingMenuEnablesVisualInlineFormatting() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Heading")
        tapSettled(app.buttons["composer-block-type"])
        chooseTurnInto(app, "composer-turn-into-Heading 2")
        tapSettled(app.buttons["composer-more"]); app.buttons["Format"].tap()
        for label in ["Bold", "Italic", "Link"] {
            let action = app.buttons[label].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isEnabled)
        }
        XCTAssertEqual(body.value as? String, "Heading")
    }
    func testVisualDraftRecoversAfterTerminationWithExactMarkdown() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Recovery check")
        tapSettled(app.buttons["composer-block-type"]); chooseTurnInto(app, "composer-turn-into-Heading 2")
        XCTAssertEqual(body.value as? String, "Recovery check")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "## Recovery check")
        tapSettled(app.buttons["composer-more"]); app.buttons["Rich text"].tap()
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10))
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap()
        let draft = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume draft:")).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); draft.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, "Recovery check")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "## Recovery check")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Recovered formatted draft after relaunch"; capture.lifetime = .keepAlways; add(capture)
    }
    func testVisualChecklistCanBeCreatedAndCheckedWithoutSource() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Sand the surface")
        tapSettled(app.buttons["composer-block-type"]); chooseTurnInto(app, "composer-turn-into-Checklist")
        XCTAssertEqual(body.value as? String, "Sand the surface")
        let check = app.buttons["composer-task-0"]
        XCTAssertTrue(check.waitForExistence(timeout: 5)); XCTAssertEqual(check.value as? String, "Unchecked"); check.tap()
        XCTAssertEqual(check.value as? String, "Checked")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "- [x] Sand the surface")
    }
    func testVisualHeadingMarkdownPreviewAndReturnPreserveDraft() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("What I tried")
        tapSettled(app.buttons["composer-block-type"]); chooseTurnInto(app, "composer-turn-into-Heading 2")
        XCTAssertEqual(body.value as? String, "What I tried")
        let visual = XCTAttachment(screenshot: app.screenshot()); visual.name = "WYSIWYG heading without syntax"; visual.lifetime = .keepAlways; add(visual)
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "## What I tried")
        body.typeText("\n> A quieter finish\n- Thin coats")
        let source = body.value as? String
        let markdown = XCTAttachment(screenshot: app.screenshot()); markdown.name = "Markdown source with Preview"; markdown.lifetime = .keepAlways; add(markdown)
        app.buttons["composer-preview"].tap()
        let preview = app.textViews["composer-preview-body"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertEqual(preview.value as? String, "What I tried\nA quieter finish\nThin coats")
        XCTAssertFalse(preview.isEnabled && app.keyboards.firstMatch.exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Rendered Markdown preview"; capture.lifetime = .keepAlways; add(capture)
        tapBack(app)
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(body.value as? String, source)
        tapSettled(app.buttons["composer-more"]); app.buttons["Rich text"].tap()
        XCTAssertEqual(body.value as? String, "What I tried\nA quieter finish\nThin coats")
        body.typeText(" matter")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, source! + " matter")
    }
    func testLargestTextSelectionFitsBar() {
        let app = launch(["--preset", "newtopic", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        // At this size the wrapped destination and title push the body's centre below the screen (iOS 27: y 788–988
        // on an 874-pt window), so a centre tap misses. Tap its visible top edge; focus then scrolls it into view.
        let visibleTop = min(0.5, max(0.02, (app.frame.maxY - body.frame.minY - 24) / max(body.frame.height, 1)))
        let bar = app.buttons["composer-insert"]
        // iPhone Duo opens with the title focused, so the keyboard and its floating bar already cover the body.
        let barCoversBody = bar.exists && body.frame.minY + 44 > bar.frame.minY
        if UIDevice.current.userInterfaceIdiom == .phone && !barCoversBody { body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: visibleTop)).tap() }
        else {
            // iPad form sheet: an edge tap can land outside the sheet. The body starts under the floating bar, so
            // scroll the composer (not the feed behind the sheet) until its first line clears the bar, then tap it.
            let composer = app.scrollViews.containing(.textView, identifier: "composer-body").firstMatch
            for _ in 0..<4 where body.frame.minY + 44 > bar.frame.minY { composer.swipeUp(velocity: .slow) }
            body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 22)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5)); body.typeText("Audit paragraph")
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
    func testComposerSelectionFormattingKeepsActionsReachable() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("What I tried")
        // On iPad the keys return after typeText and lift the form sheet; a double tap made meanwhile misses the word.
        waitForSoftwareKeyboard(app, settling: body)
        body.doubleTap()
        let done = app.buttons["composer-selection-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        app.buttons["Bold"].firstMatch.tap()
        XCTAssertTrue(done.isHittable)
        for id in ["composer-insert", "composer-more", "composer-selection-done"] {
            XCTAssertTrue(app.buttons[id].isHittable); XCTAssertTrue(app.frame.contains(app.buttons[id].frame))
        }
        let selection = XCTAttachment(screenshot: app.screenshot()); selection.name = "Polished contextual selection bar"; selection.lifetime = .keepAlways; add(selection)
        done.tap(); tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertTrue((body.value as? String)?.contains("**") == true)
    }
    func testComposerCatalogueQuickQuoteAndSearchRecovery() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("What I tried")
        let writing = XCTAttachment(screenshot: app.screenshot()); writing.name = "Polished composer writing bar"; writing.lifetime = .keepAlways; add(writing)
        dismissComposerKeyboard(app); app.buttons["composer-insert"].tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["Quote"].isHittable)
        let catalogue = XCTAttachment(screenshot: app.screenshot()); catalogue.name = "Polished insertion catalogue"; catalogue.lifetime = .keepAlways; add(catalogue)
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("vote")
        XCTAssertTrue(app.buttons["Poll"].waitForExistence(timeout: 5), "Search includes the block description")
        // On iPhone native searchable replaces the navigation actions while active: cancel search first, then close the
        // sheet. iPad keeps the sheet's Cancel beside a search field that has no Cancel of its own.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(app.buttons["composer-insert-cancel"].isHittable, "Cancel stays reachable while searching")
        } else {
            let searchCancel = app.buttons.matching(NSPredicate(format: "(label == %@ OR label == %@) AND NOT (identifier IN %@)", "Close", "Cancel", ["composer-close", "composer-insert-cancel"])).firstMatch
            XCTAssertTrue(searchCancel.waitForExistence(timeout: 5)); searchCancel.tap()
        }
        XCTAssertTrue(app.buttons["composer-insert-cancel"].waitForExistence(timeout: 5))
        app.buttons["composer-insert-cancel"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5)); XCTAssertEqual(body.value as? String, "What I tried")
        app.buttons["composer-insert"].tap(); app.buttons["Quote"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5)); body.typeText("Two thin coats")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "What I tried\n> Two thin coats")
    }
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    override func tearDown() { MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }
    /// The formatting bar rides the keyboard; right after typing it can still be moving (iOS 27 probe: y 784 → 490 within
    /// ~0.4 s), so a tap computed mid-move lands where the control was. Tap once its frame has settled.
    private func tapSettled(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        waitForRaisedKeyboard(app: XCUIApplication(), above: element)
        var last = element.frame
        let end = Date().addingTimeInterval(timeout)
        repeat { Thread.sleep(forTimeInterval: 0.15); let now = element.frame; if now == last { break }; last = now } while Date() < end
        element.tap()
    }
    /// `typeText` drives a virtual (Recap) hardware keyboard; while UIKit treats it as attached, the software keyboard
    /// is minimized and the bar drops to the bottom. UIKit notices the detach on its own 0.5–6.6 s later (iOS 27
    /// simulator logs, 36 of 38 cases without any touch). A tap computed in that window lands where the bar no longer
    /// is. When a keyboard is present, wait until it is on screen with `element` above it.
    private func waitForRaisedKeyboard(app: XCUIApplication, above element: XCUIElement, timeout: TimeInterval = 10) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let raised = NSPredicate { _, _ in
            keyboard.exists && keyboard.frame.minY < app.frame.maxY - 40 && element.exists && element.frame.maxY <= keyboard.frame.minY + 1
        }
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: raised, object: nil)], timeout: timeout)
    }
    /// Chooses a Turn into option and verifies the strip closed, so a missed tap fails here rather than later.
    private func chooseTurnInto(_ app: XCUIApplication, _ identifier: String) {
        tapSettled(app.buttons[identifier])
        if identifier != "composer-turn-into-close" { XCTAssertTrue(app.buttons["composer-turn-into-close"].waitForNonExistence(timeout: 3), "\(identifier) applied and the strip closed") }
    }
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments.contains("--live") ? arguments : ["--fixture", "--ui-testing"] + arguments; app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString; app.launch()
        if !arguments.contains("--live") {
            let ready = arguments.contains("--store-preview") ? "topic-4188" : arguments.contains("communities") ? "community-1" : "topic-4182"
            XCTAssertTrue(app.buttons[ready].waitForExistence(timeout: 10))
        }
        return app
    }
    /// After `typeText`, the simulator can hide the software keyboard without the editor losing focus
    /// and restore it on the next touch; the bar then jumps between the safe area and the keys. Tap only
    /// once the bar has kept the same frame for a second. A control inside a scrolling strip settles on a
    /// visible `anchor` in the same bar; `tap()` then scrolls the control into view as before.
    private func tapSettled(_ app: XCUIApplication, _ control: XCUIElement, anchor: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let reference = anchor ?? control
        XCTAssertTrue(control.waitForExistence(timeout: 5) && reference.waitForExistence(timeout: 5), file: file, line: line)
        var last = CGRect.null, stableSince = Date(), deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let frame = reference.frame
            if frame != last || !reference.isHittable { last = frame; stableSince = Date() }
            else if Date().timeIntervalSince(stableSince) >= 1 { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(reference.isHittable, "\(reference) did not settle", file: file, line: line)
        control.tap()
    }
    /// The More menu's action, not the iPad keyboard shortcut bar's own Undo/Redo (`assistantUndo`, `assistantRedo`).
    private func menuAction(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", label, "assistant")).firstMatch
    }
    /// While the editor is focused, waits for the software keyboard to come back from XCTest's virtual hardware
    /// keyboard and for `element` to hold still. On iPad only a minimized assistant bar shows meanwhile (no keyboard
    /// element), and the composer's form sheet rises with the keys when they return: a tap made then starts on a
    /// control and ends off it, so the control's action never runs.
    private func waitForSoftwareKeyboard(_ app: XCUIApplication, settling element: XCUIElement) {
        guard app.buttons["composer-keyboard"].label == "Hide keyboard" else { return }
        let keyboard = app.keyboards.firstMatch
        let raised = NSPredicate { _, _ in keyboard.exists && keyboard.frame.minY < app.frame.maxY - 40 }
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: raised, object: nil)], timeout: 10)
        waitForStableFrame(element)
    }
    private func waitForStableFrame(_ element: XCUIElement) {
        var last = element.frame, stableSince = Date()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && Date().timeIntervalSince(stableSince) < 0.6 {
            Thread.sleep(forTimeInterval: 0.15)
            if element.frame != last { last = element.frame; stableSince = Date() }
        }
    }
    private func dismissComposerKeyboard(_ app: XCUIApplication) {
        // The floating bar's own control; a drag on a short reply also pulls the sheet and opens Keep/Discard.
        let toggle = app.buttons["composer-keyboard"]
        // Decide from the editor's focus, not the keyboard: on iPad the software keyboard can still be minimized
        // after typeText, with only the assistant bar showing, and returns by itself while the editor keeps focus.
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if app.keyboards.firstMatch.exists { XCTAssertEqual(toggle.label, "Hide keyboard") }
        guard toggle.label == "Hide keyboard" else { return }
        waitForSoftwareKeyboard(app, settling: toggle)
        // Prefer the software keyboard back (not minimized by XCTest's virtual typing keyboard) with the bar above it.
        // Some simulators keep it minimized for the whole run; the bar then rests above the safe area, so tap it once
        // its frame has held still instead of failing.
        let keyboard = app.keyboards.firstMatch
        let raised = NSPredicate { _, _ in keyboard.exists && keyboard.frame.minY < app.frame.maxY - 40 && toggle.exists && toggle.frame.maxY <= keyboard.frame.minY + 1 }
        if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: raised, object: nil)], timeout: 1) == .completed { tapSettled(toggle) }
        else { tapSettled(app, toggle) }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        // Hiding the keyboard keeps the floating bar reachable above the safe area.
        let docked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND label == %@", "Show keyboard"), object: app.buttons["composer-keyboard"])
        XCTAssertEqual(XCTWaiter.wait(for: [docked], timeout: 5), .completed)
        // The iPad form sheet settles back down once the keys leave; the next tap must not land mid-move.
        waitForStableFrame(toggle)
    }
    func testNativeFormattingCaretTypingSurvivesSourceSwitch() {
        let app = launch(["--preset", "newtopic"])
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-insert"].isHittable); XCTAssertTrue(app.buttons["composer-more"].isHittable)
        let hiddenCapture = XCTAttachment(screenshot: app.screenshot()); hiddenCapture.name = "Composer entry bar without keyboard"; hiddenCapture.lifetime = .keepAlways; add(hiddenCapture)
        body.tap()
        let more = app.buttons["composer-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        waitForSoftwareKeyboard(app, settling: more)
        XCTAssertTrue(more.isHittable)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Composer bar attached to keyboard"; capture.lifetime = .keepAlways; add(capture)
        // XCTest’s keyboard frame excludes the QuickType prediction row.
        XCTAssertLessThanOrEqual(more.frame.maxY, keyboard.frame.minY)
        if keyboard.frame.minY >= app.frame.maxY - 40 {
            // A connected hardware keyboard minimizes the software keys below the window (Device Hub attaches the
            // Mac's keyboard to the Duo: keys at y 722 in a 678 pt window). The bar then rests on the bottom safe area.
            XCTAssertGreaterThanOrEqual(more.frame.maxY, app.frame.maxY - 72, "With the keys minimized the bar sits at the bottom (bar \(more.frame), window \(app.frame))")
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad presents the composer as a form sheet that the system lifts clear of the keyboard; the bar rides
            // the sheet's bottom edge rather than the keys, and the whole sheet stays above the prediction row.
            let sheet = app.scrollViews.containing(.textView, identifier: "composer-body").firstMatch.frame
            XCTAssertLessThanOrEqual(sheet.maxY - more.frame.maxY, 24, "Formatting controls sit on the sheet's bottom edge")
            XCTAssertLessThanOrEqual(sheet.maxY, keyboard.frame.minY - 44, "The sheet stays clear of the keys and prediction row")
        } else {
            XCTAssertLessThanOrEqual(keyboard.frame.minY - more.frame.maxY, 64, "Only the prediction row should separate formatting controls from the keys (bar \(more.frame), keyboard \(keyboard.frame))")
        }
        body.typeText("Before ")
        XCTAssertFalse(app.buttons["composer-keyboard-done"].exists)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: more)], timeout: 5), .completed)
        more.tap(); app.buttons["Format"].tap(); app.buttons["Bold"].firstMatch.tap()
        body.typeText("Bold")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
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
        tapSettled(chip); chooseTurnInto(app, "composer-turn-into-Heading 2")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Turn into: Heading 2"), object: chip)], timeout: 5), .completed)
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Changing the block type keeps the keyboard up")
        app.buttons["composer-insert"].tap()
        XCTAssertTrue(app.staticTexts["composer-insert-placement"].waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Add block sheet names its placement"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["composer-insert-cancel"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        body.typeText(" first")
        tapSettled(app.buttons["composer-more"]); app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, "## What I tried first", "Cancel changes nothing and returns to the captured caret")
        app.buttons["composer-close"].tap(); app.buttons["Discard"].tap()
    }
    func testNativeBlockFormAndMarkdownRoundTrip() {
        let app = launch()
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Writing before code\n")
        tapSettled(app, app.buttons["composer-insert"])
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Code")
        let codeBlock = app.buttons["Code"]; XCTAssertTrue(codeBlock.waitForExistence(timeout: 5)); codeBlock.tap()
        let code = app.textViews["block-body"]; XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("let greeting = 1")
        app.buttons["block-save"].tap()
        XCTAssertTrue(code.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        // After the pushed form closes, the bar must float above the keyboard again rather than behind it.
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["composer-more"].frame.maxY <= keyboardTop }, object: nil)], timeout: 5), .completed,
                       "Bar \(app.buttons["composer-more"].frame) vs keyboard top \(keyboardTop) (keyboard now \(app.keyboards.firstMatch.frame))")
        tapSettled(app.buttons["composer-more"])
        let markdown = app.buttons["Edit in Markdown"]
        if !markdown.waitForExistence(timeout: 2) { tapSettled(app.buttons["composer-more"]) }
        XCTAssertTrue(markdown.waitForExistence(timeout: 5)); markdown.tap()
        XCTAssertTrue((body.value as? String)?.contains("let greeting = 1") == true)
        XCTAssertTrue((body.value as? String)?.contains("```") == true)
        tapSettled(app.buttons["composer-more"]); app.buttons["Rich text"].tap()
        let editBlock = app.buttons["composer-block-edit-code"]
        XCTAssertTrue(editBlock.waitForExistence(timeout: 5), "A rich block must expose its native editing card")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: editBlock)], timeout: 5), .completed)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Native composer with code block"; capture.lifetime = .keepAlways; add(capture)
        editBlock.tap(); XCTAssertTrue(code.waitForExistence(timeout: 5)); XCTAssertEqual(code.value as? String, "let greeting = 1")
        tapBack(app); XCTAssertTrue(code.waitForNonExistence(timeout: 5))
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
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Resume draft: Reply · Finishing")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertEqual((body.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), "A durable native reply")
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Kept native reply reopened"; capture.lifetime = .keepAlways; add(capture)
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
        let create = newDiscussionControl(app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: create)], timeout: 5), .completed)
        create.tap(); app.buttons["composer-destination"].tap(); app.buttons["destination-toggle-1"].tap(); XCTAssertTrue(app.buttons["destination-2"].waitForExistence(timeout: 5)); app.buttons["destination-2"].tap()
        XCTAssertTrue(app.textViews["composer-title"].waitForExistence(timeout: 5)); app.textViews["composer-title"].tap(); app.textViews["composer-title"].typeText("Photo recovery")
        app.textViews["composer-body"].tap(); app.textViews["composer-body"].typeText("Writing stays")
        tapSettled(app.buttons["composer-more"]); let sample = app.buttons["Sample photo"]; XCTAssertTrue(sample.waitForExistence(timeout: 5)); sample.tap()
        XCTAssertTrue(app.buttons["Retry upload"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-post"].isEnabled)
        app.buttons["composer-close"].tap(); XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 5)); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Me").firstMatch.tap(); XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5)); app.buttons["me-drafts"].tap(); let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo recovery")).firstMatch; XCTAssertTrue(draft.waitForExistence(timeout: 5)); draft.tap()
        XCTAssertTrue(app.buttons["Resume upload"].waitForExistence(timeout: 5)); app.buttons["Remove photo"].firstMatch.tap()
        XCTAssertEqual(app.textViews["composer-title"].value as? String, "Photo recovery"); XCTAssertEqual((app.textViews["composer-body"].value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), "Writing stays")
    }
    func testDarkAccessibilityComposerRemainsReachable() {
        let app = launch(["--dark", "--accessibility-text"])
        let create = newDiscussionControl(app)
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
    func testReadingFocusPreferenceSurvivesPhoneRotation() throws {
        try skipOrientationRequestsOnDuo()
        let app = launch()
        app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPhoneWindowShape(app, landscape: true)
        let toggle = app.buttons["toggle-topic-list"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10)); toggle.tap()
        XCTAssertEqual(toggle.label, "Show topic list")
        XCUIDevice.shared.orientation = .portrait
        assertPhoneWindowShape(app, landscape: false)
        XCTAssertTrue(app.buttons["discussion-reply"].isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPhoneWindowShape(app, landscape: true)
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "Show topic list", "Focused reading preference survives temporary collapse")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Focused reading retained after compact width"; capture.lifetime = .keepAlways; add(capture)
        toggle.tap()
        XCTAssertEqual(toggle.label, "Focus on discussion")
        let scope = app.buttons["community-scope"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: scope)], timeout: 8), .completed, "Showing the list restores its header without changing its saved scroll position")
    }
    func testPhoneRotationKeepsHomeAndReplyReachable() throws {
        try skipOrientationRequestsOnDuo()
        let app = launch()
        assertPhoneWindowShape(app, landscape: false)
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPhoneWindowShape(app, landscape: true)
        // The first row remains visible in the short landscape viewport.
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["topic-4190"])], timeout: 8), .completed)
        XCUIDevice.shared.orientation = .portrait
        assertPhoneWindowShape(app, landscape: false)
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        XCTAssertTrue(app.textViews["composer-body"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPhoneWindowShape(app, landscape: true)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["composer-close"])], timeout: 8), .completed)
        XCUIDevice.shared.orientation = .portrait
        assertPhoneWindowShape(app, landscape: false)
    }
    func testArabicHomeRotationKeepsFeedReachable() throws {
        try skipOrientationRequestsOnDuo()
        let app = launch(["-AppleLanguages", "(ar)", "-AppleLocale", "ar_JO", "--rtl"])
        assertPhoneWindowShape(app, landscape: false)
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPhoneWindowShape(app, landscape: true)
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        assertPhoneWindowShape(app, landscape: false)
    }
    /// Back in either bar form: a horizontal navigation bar, or iPhone Duo's vertical system bar,
    /// where it sits in a toolbar. The newest Back (a presented screen's) is last in the tree.
    private func tapBack(_ app: XCUIApplication) {
        let bar = app.navigationBars.buttons.element(boundBy: 0)
        if bar.exists { bar.tap(); return }
        let back = app.buttons.matching(identifier: "BackButton").allElementsBoundByIndex.last
        XCTAssertNotNil(back, "No Back control in either bar form"); back?.tap()
    }
    /// iPhone Duo changes pose through Device Hub (fold, unfold, rotate); an XCUIDevice orientation
    /// request leaves its window unchanged. Its pose transitions are validated through Device Hub instead.
    private func skipOrientationRequestsOnDuo() throws {
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]?.contains("Duo") == true {
            throw XCTSkip("iPhone Duo poses come from Device Hub, not XCUIDevice orientation requests")
        }
    }
    private func assertPhoneWindowShape(_ app: XCUIApplication, landscape: Bool, file: StaticString = #filePath, line: UInt = #line) {
        // Device orientation requests need not resize a windowed iPad scene.
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
        }, object: nil)
        let result = XCTWaiter.wait(for: [resized], timeout: 8)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = landscape ? "Phone landscape geometry" : "Phone portrait geometry"
        capture.lifetime = .keepAlways; add(capture)
        XCTAssertEqual(result, .completed, "The app window must actually rotate", file: file, line: line)
    }
    func testComposerKeepsWritingAndEditingModeAcrossLayoutChanges() throws {
        try skipOrientationRequestsOnDuo()
        let app = launch()
        assertPhoneWindowShape(app, landscape: false)
        app.buttons["topic-4182"].tap()
        app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Keep my writing as the window changes.")
        tapSettled(app, app.buttons["composer-more"])
        let markdown = app.buttons["Edit in Markdown"]
        XCTAssertTrue(markdown.waitForExistence(timeout: 5)); markdown.tap()
        let written = body.value as? String
        XCTAssertTrue(written?.contains("Keep my writing") == true)

        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertPhoneWindowShape(app, landscape: orientation != .portrait)
            let close = app.buttons["composer-close"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)], timeout: 8), .completed)
            XCTAssertEqual(body.value as? String, written)
            XCTAssertTrue(app.buttons["composer-preview"].exists, "Markdown mode survives relayout")
            XCTAssertTrue(app.frame.contains(close.frame))
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Composer layout request \(orientation.rawValue)"
            capture.lifetime = .keepAlways; add(capture)
        }
        body.tap(); body.typeText(" Still editing.")
        XCTAssertTrue((body.value as? String)?.contains("Still editing.") == true)
        // iPad: the keys return after typeText and lift the form sheet; a Cancel tap made meanwhile is lost.
        waitForSoftwareKeyboard(app, settling: app.buttons["composer-close"])
        app.buttons["composer-close"].tap()
        XCTAssertTrue(app.buttons["Keep draft"].waitForExistence(timeout: 5))
        app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
    }
    func testArabicComposerPreservesMixedTextAcrossModesAndRotation() throws {
        try skipOrientationRequestsOnDuo()
        let app = launch(["-AppleLanguages", "(ar)", "-AppleLocale", "ar_JO", "--rtl"])
        app.buttons["topic-4182"].tap(); app.buttons["discussion-reply"].tap()
        let body = app.textViews["composer-body"]; XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("مرحبا Fomio")
        let written = body.value as? String
        tapSettled(app.buttons["composer-more"])
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
        // Topic search is collapsed in the list header; the magnifier reveals its field.
        app.buttons["reveal-topic-search"].tap()
        let query = app.textFields["topic-search-field"]
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("desk\n")
        // The plain feed also lists this topic, so wait for the search results themselves.
        XCTAssertTrue(app.scrollViews["scoped-search-results"].waitForExistence(timeout: 10))
        let topic = app.buttons["topic-4182"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(query.value as? String, "desk")
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5))
        // One pane returns with Back; two panes keep the results beside the discussion.
        let back = app.buttons["back-to-topic-list"]
        if back.exists { back.tap() }
        XCTAssertTrue(app.scrollViews["scoped-search-results"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["topic-search-field"].value as? String, "desk")
    }
    func testLiveDoesNotUseFixtureFallback() {
        let app = launch(["--live", "--unconfigured"])
        XCTAssertTrue(app.staticTexts["Community configuration needed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topic-4190"].exists)
    }
    /// Create sits in the feed header at every width.
    private func newDiscussionControl(_ app: XCUIApplication, title: String = "New discussion") -> XCUIElement {
        let create = app.buttons["feed-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5)); XCTAssertEqual(create.label, title); return create
    }
    func testCommunityFieldSearchesInPlace() {
        let app = launch()
        let create = newDiscussionControl(app)
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
        XCTAssertTrue(app.buttons["community-scope"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["composer-keep-editing"].exists)
    }
    func testKeyboardBarNextAndKeepEditing() {
        let app = launch()
        let create = newDiscussionControl(app)
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
        waitForSoftwareKeyboard(app, settling: app.buttons["composer-close"])
        app.buttons["composer-close"].tap()
        let keepEditing = app.buttons["composer-keep-editing"].firstMatch
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5)); keepEditing.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        body.typeText(" continued")
        let expectedBody = beforeDialog.replacingOccurrences(of: " before", with: " before continued")
        XCTAssertEqual(body.value as? String, expectedBody)
        XCTAssertEqual(title.value as? String, "Keyboard journey")
        waitForSoftwareKeyboard(app, settling: title)
        title.tap(); title.typeText(" before")
        let beforeChooser = title.value as? String ?? ""
        waitForSoftwareKeyboard(app, settling: app.buttons["composer-destination"])
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
