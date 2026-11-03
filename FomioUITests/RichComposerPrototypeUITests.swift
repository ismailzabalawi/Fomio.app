import XCTest
import UIKit
import UniformTypeIdentifiers

@MainActor final class RichComposerPrototypeUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func launch(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--rich-editor-prototype", "--ui-testing"] + extraArguments
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        return app
    }
    func testKeyboardControlsAtAccessibilitySize() throws {
        let app = launch(["--dark", "--accessibility-text"])
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let original = try XCTUnwrap(rich.value as? String)
        app.buttons["prototype-select-all"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertControlsAboveKeyboard(app)
        app.buttons["prototype-hide-keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(rich.value as? String, original)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        let source = app.textViews["prototype-markdown"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let dismiss = app.buttons["prototype-hide-keyboard"]
        XCTAssertTrue(dismiss.isHittable)
        XCTAssertLessThanOrEqual(dismiss.frame.maxY, app.keyboards.firstMatch.frame.minY + 2)
        dismiss.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
    func testArabicEmojiFormattingAndLosslessModeSwitches() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let plain = try XCTUnwrap(rich.value as? String)
        XCTAssertTrue(plain.contains("مرحبا بالعالم 👋🏽"))
        XCTAssertTrue(plain.contains("👨‍👩‍👧‍👦"))
        let mode = app.segmentedControls["prototype-mode"]
        mode.buttons["Markdown"].tap()
        let source = app.textViews["prototype-markdown"]
        let original = try XCTUnwrap(source.value as? String)
        XCTAssertTrue(original.contains("**بالعالم**"))
        XCTAssertTrue(original.contains("\\*literal\\*"))
        for _ in 0..<3 {
            mode.buttons["Rich text"].tap()
            XCTAssertEqual(rich.value as? String, plain)
            mode.buttons["Markdown"].tap()
            XCTAssertEqual(source.value as? String, original)
        }
        mode.buttons["Rich text"].tap()
        app.buttons["prototype-select-all"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertControlsAboveKeyboard(app)
        let keyboardCapture = XCTAttachment(screenshot: app.screenshot())
        keyboardCapture.name = "Prototype keyboard and formatting controls"; keyboardCapture.lifetime = .keepAlways; add(keyboardCapture)
        app.buttons["prototype-hide-keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(rich.value as? String, plain)
        app.buttons["prototype-select-all"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertControlsAboveKeyboard(app)
        app.buttons["prototype-bold"].tap()
        XCTAssertEqual(app.buttons["prototype-bold"].value as? String, "On")
        app.buttons["prototype-italic"].tap()
        XCTAssertEqual(app.buttons["prototype-italic"].value as? String, "On")
        app.buttons["prototype-strikethrough"].tap()
        XCTAssertEqual(app.buttons["prototype-strikethrough"].value as? String, "On")
        mode.buttons["Markdown"].tap()
        let formatted = try XCTUnwrap(source.value as? String)
        XCTAssertTrue(formatted.contains("[b]"))
        XCTAssertTrue(formatted.contains("[i]"))
        XCTAssertTrue(formatted.contains("[s]"))
        XCTAssertTrue(formatted.contains("مرحبا"))
        XCTAssertTrue(formatted.contains("👨‍👩‍👧‍👦"))
        mode.buttons["Rich text"].tap()
        XCTAssertEqual(rich.value as? String, plain)
        mode.buttons["Markdown"].tap()
        XCTAssertEqual(source.value as? String, formatted)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "SwiftUI prototype Arabic emoji source"; capture.lifetime = .keepAlways; add(capture)
    }
    func testUndoRedoAcrossFormattingModesAndSourceTyping() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let plain = try XCTUnwrap(rich.value as? String)
        let undo = app.buttons["prototype-undo"], redo = app.buttons["prototype-redo"]
        XCTAssertFalse(undo.isEnabled)
        let mode = app.segmentedControls["prototype-mode"]
        mode.buttons["Markdown"].tap()
        let source = app.textViews["prototype-markdown"]
        let original = try XCTUnwrap(source.value as? String)
        undo.tap()
        XCTAssertTrue(rich.waitForExistence(timeout: 5))
        XCTAssertEqual(rich.value as? String, plain)
        redo.tap()
        XCTAssertEqual(source.value as? String, original)
        mode.buttons["Rich text"].tap()
        app.buttons["prototype-select-all"].tap()
        app.buttons["prototype-bold"].tap()
        XCTAssertEqual(app.buttons["prototype-bold"].value as? String, "On")
        undo.tap()
        XCTAssertEqual(app.buttons["prototype-bold"].value as? String, "Off")
        redo.tap()
        XCTAssertEqual(app.buttons["prototype-bold"].value as? String, "On")
        mode.buttons["Markdown"].tap()
        let formatted = try XCTUnwrap(source.value as? String)
        XCTAssertTrue(formatted.contains("[b]"))
        source.tap(); source.typeText("Z")
        let typed = try XCTUnwrap(source.value as? String)
        XCTAssertNotEqual(typed, formatted)
        undo.tap()
        XCTAssertEqual(source.value as? String, formatted)
        undo.tap()
        XCTAssertTrue(rich.waitForExistence(timeout: 5))
        XCTAssertEqual(rich.value as? String, plain)
        XCTAssertEqual(app.buttons["prototype-bold"].value as? String, "On")
        redo.tap(); redo.tap()
        XCTAssertEqual(source.value as? String, typed)
        undo.tap(); source.tap(); source.typeText("Q")
        XCTAssertFalse(redo.isEnabled)
    }
    func testTypingUndoThenRedoRestoresArabicAndEmojiReplacement() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let original = try XCTUnwrap(rich.value as? String)
        app.buttons["prototype-select-all"].tap()
        rich.typeText("مرحبا Fomio")
        XCTAssertEqual(rich.value as? String, "مرحبا Fomio")
        // A native typing burst is a single session action, separate from mode changes.
        app.buttons["prototype-undo"].tap()
        XCTAssertEqual(rich.value as? String, original)
        // Check the editor keeps focus, not keyboard visibility: some simulators keep the software keyboard minimized.
        XCTAssertTrue(rich.hasKeyboardFocus)
        app.buttons["prototype-redo"].tap()
        XCTAssertEqual(rich.value as? String, "مرحبا Fomio")
        XCTAssertTrue(rich.hasKeyboardFocus)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        XCTAssertEqual(app.textViews["prototype-markdown"].value as? String, "مرحبا Fomio")
    }
    func testCheckedPastePreservesRichMarksAndIsOneUndoAction() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let original = try XCTUnwrap(rich.value as? String)
        let literal = "مرحبا 👋🏽 👨‍👩‍👧‍👦"
        let imported = NSAttributedString(string: literal, attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .strikethroughStyle: 1])
        let data = try imported.data(from: NSRange(location: 0, length: imported.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        UIPasteboard.general.setItems([[UTType.rtf.identifier: data, UTType.utf8PlainText.identifier: literal]])
        app.buttons["prototype-select-all"].tap()
        let paste = app.buttons["prototype-paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        XCTAssertTrue(paste.isEnabled)
        paste.tap()
        XCTAssertTrue(rich.waitForValue(literal), app.staticTexts["prototype-paste-notice"].exists ? app.staticTexts["prototype-paste-notice"].label : app.debugDescription)
        app.buttons["prototype-undo"].tap()
        XCTAssertEqual(rich.value as? String, original)
        app.buttons["prototype-redo"].tap()
        XCTAssertEqual(rich.value as? String, literal)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        let source = try XCTUnwrap(app.textViews["prototype-markdown"].value as? String)
        XCTAssertTrue(source.contains("[b][s]مرحبا"), source)
        XCTAssertTrue(source.contains("👨‍👩‍👧‍👦"), source)
    }
    func testNativeEditMenuPastePreservesBasicFormattingOnExport() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let literal = "Native مرحبا 👋🏽"
        let imported = NSAttributedString(string: literal, attributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
        let data = try imported.data(from: NSRange(location: 0, length: imported.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        UIPasteboard.general.setItems([[UTType.rtf.identifier: data, UTType.utf8PlainText.identifier: literal]])
        app.buttons["prototype-select-all"].tap()
        // Tap actual text near the leading Arabic line, rather than the empty
        // center of the scrolling editor. Native selection reveals the edit menu.
        rich.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.08)).doubleTap()
        let nativePaste = app.menuItems["Paste"]
        XCTAssertTrue(nativePaste.waitForExistence(timeout: 5), app.debugDescription)
        nativePaste.tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2), app.alerts.buttons["Allow Paste"].exists {
            app.alerts.buttons["Allow Paste"].tap()
        }
        XCTAssertTrue(rich.waitForContainingValue(literal), app.debugDescription)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        let source = try XCTUnwrap(app.textViews["prototype-markdown"].value as? String)
        XCTAssertTrue(source.contains("[b]Native مرحبا 👋🏽[/b]"), source)
    }
    func testUnsupportedPasteOffersExplicitPlainTextRecovery() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        let original = try XCTUnwrap(rich.value as? String)
        let literal = "**literal** مرحبا 👋🏽"
        UIPasteboard.general.setItems([[UTType.html.identifier: Data("<a href='https://example.com'>hello</a>".utf8), UTType.utf8PlainText.identifier: literal]])
        app.buttons["prototype-select-all"].tap()
        app.buttons["prototype-paste"].tap()
        let plainPaste = app.buttons["prototype-paste-plain"]
        XCTAssertTrue(plainPaste.waitForExistence(timeout: 5))
        XCTAssertEqual(rich.value as? String, original)
        plainPaste.tap()
        XCTAssertTrue(rich.waitForValue(literal), app.staticTexts["prototype-paste-notice"].exists ? app.staticTexts["prototype-paste-notice"].label : app.debugDescription)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        let source = try XCTUnwrap(app.textViews["prototype-markdown"].value as? String)
        XCTAssertTrue(source.contains("\\*\\*literal\\*\\*"), source)
    }

    /// `typeText` of a whole string delivers keys faster than anyone types, while the editor is still adopting shaped text.
    /// This sends one key per call, closer to real typing.
    func testListTypingOneKeyAtATimeStaysExact() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        app.buttons["prototype-samples"].tap(); app.buttons["Plain text"].tap()
        app.buttons["prototype-select-all"].tap()
        for key in "Shopping\n" { rich.typeText(String(key)) }
        app.buttons["prototype-bullet"].tap()
        for key in "Milk\nخبز 🍞\n\nDone\n\n> quoted" { rich.typeText(String(key)) }
        XCTAssertEqual(rich.value as? String, "Shopping\n• Milk\n• خبز 🍞\n\nDone\n\n▎ quoted")
    }

    func testListsQuotesAndLinksTypedNativelyExportToDiscourseSource() throws {
        let app = launch()
        let rich = app.textViews["prototype-rich"]
        XCTAssertTrue(rich.waitForExistence(timeout: 10))
        app.buttons["prototype-samples"].tap(); app.buttons["Plain text"].tap()
        app.buttons["prototype-select-all"].tap()
        rich.typeText("Shopping\n")
        app.buttons["prototype-bullet"].tap()
        XCTAssertEqual(app.buttons["prototype-bullet"].value as? String, "On")
        // Return continues the list; Return on the empty item leaves it.
        rich.typeText("Milk\nخبز 🍞\n\nDone\n\n> quoted")
        XCTAssertEqual(rich.value as? String, "Shopping\n• Milk\n• خبز 🍞\n\nDone\n\n▎ quoted")
        rich.typeText(" ")
        let text = app.textFields["prototype-link-text"], url = app.textFields["prototype-link-url"]
        tap(app.buttons["prototype-link"], until: { text.exists })
        text.tap(); text.typeText("Fomio")
        url.tap(); url.typeText("meta.discourse.org")
        app.buttons["prototype-link-apply"].tap()
        XCTAssertTrue(rich.waitForValue("Shopping\n• Milk\n• خبز 🍞\n\nDone\n\n▎ quoted Fomio"), (rich.value as? String ?? "").debugDescription)
        app.segmentedControls["prototype-mode"].buttons["Markdown"].tap()
        let source = app.textViews["prototype-markdown"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), app.staticTexts["prototype-issue"].exists ? app.staticTexts["prototype-issue"].label : "")
        XCTAssertEqual(source.value as? String, "Shopping\n- Milk\n- خبز 🍞\n\nDone\n\n> quoted [Fomio](https://meta.discourse.org)")
        app.segmentedControls["prototype-mode"].buttons["Rich text"].tap()
        XCTAssertEqual(rich.value as? String, "Shopping\n• Milk\n• خبز 🍞\n\nDone\n\n▎ quoted Fomio")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Prototype lists, quote and link"; capture.lifetime = .keepAlways; add(capture)
    }

    func testRichComposerSwitchSavesDiscourseSourceToTheDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing", "--rich-composer"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)); app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5)); app.buttons["discussion-reply"].tap()
        let rich = app.textViews["composer-rich-body"]
        XCTAssertTrue(rich.waitForExistence(timeout: 5)); rich.tap()
        rich.typeText("Steps\n")
        tapChangingText(app.buttons["prototype-bullet"], in: rich)
        rich.typeText("مرحبا 👋🏽\nTwo")
        XCTAssertEqual(rich.value as? String, "Steps\n• مرحبا 👋🏽\n• Two")
        XCTAssertTrue(app.buttons["composer-post"].isEnabled)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Debug rich composer"; capture.lifetime = .keepAlways; add(capture)
        assertKeptDraftSource("Steps\n- مرحبا 👋🏽\n- Two", in: app)
    }

    func testRichComposerSuggestsMentionsAndSavesThemAsSource() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing", "--rich-composer"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10)); app.buttons["topic-4182"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5)); app.buttons["discussion-reply"].tap()
        let rich = app.textViews["composer-rich-body"]
        XCTAssertTrue(rich.waitForExistence(timeout: 5)); rich.tap()
        rich.typeText("شكرا @pr")
        let suggestion = app.buttons["composer-mention-priya"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Mention suggestions"; capture.lifetime = .keepAlways; add(capture)
        tapChangingText(suggestion, in: rich)
        XCTAssertEqual(rich.value as? String, "شكرا @priya ")
        XCTAssertFalse(suggestion.exists)
        XCTAssertTrue(rich.hasKeyboardFocus)
        rich.typeText("on it")
        XCTAssertEqual(rich.value as? String, "شكرا @priya on it")
        XCTAssertFalse(app.staticTexts["composer-rich-issue"].exists)
        assertKeptDraftSource("شكرا @priya on it", in: app)
    }

    /// Keeps the draft, then reopens it without the switch: the standard composer shows it as Discourse source.
    private func assertKeptDraftSource(_ source: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["composer-close"].tap(); app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5), file: file, line: line)
        app.terminate()
        app.launchArguments = ["--fixture", "--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["topic-4182"].waitForExistence(timeout: 10), file: file, line: line)
        app.buttons.matching(identifier: "Me").firstMatch.tap()
        XCTAssertTrue(app.buttons["me-drafts"].waitForExistence(timeout: 5), file: file, line: line); app.buttons["me-drafts"].tap()
        let draft = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume draft:")).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5), file: file, line: line); draft.tap()
        let body = app.textViews["composer-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.buttons["composer-more"].waitForExistence(timeout: 5), file: file, line: line); app.buttons["composer-more"].tap()
        app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(body.value as? String, source, file: file, line: line)
    }

    /// After `typeText` the simulator can keep its software keyboard minimized; the next touch restores it
    /// and the composer bar moves under the finger, losing that tap. Tap again only while the text is unchanged.
    private func tapChangingText(_ control: XCUIElement, in editor: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let before = editor.value as? String
        tap(control, until: { editor.value as? String != before }, file: file, line: line)
    }
    private func tap(_ control: XCUIElement, until done: @escaping () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            control.tap()
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in done() }, object: nil)
            if XCTWaiter.wait(for: [expectation], timeout: 2) == .completed { return }
        }
        XCTFail("\(control) had no effect", file: file, line: line)
    }
    private func assertControlsAboveKeyboard(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let keyboard = app.keyboards.firstMatch.frame
        for identifier in ["prototype-bold", "prototype-italic", "prototype-strikethrough", "prototype-hide-keyboard"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.isHittable, identifier, file: file, line: line)
            let frame = button.frame
            XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite, identifier, file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, identifier, file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, identifier, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, keyboard.minY + 2, identifier, file: file, line: line)
        }
    }
    func testUnsupportedSourceIsPreservedAndPlainTypingSurvivesSwitching() throws {
        let app = launch()
        XCTAssertTrue(app.textViews["prototype-rich"].waitForExistence(timeout: 10))
        app.buttons["prototype-samples"].tap()
        app.buttons["Preserved Discourse block"].tap()
        let source = app.textViews["prototype-markdown"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        let original = try XCTUnwrap(source.value as? String)
        let mode = app.segmentedControls["prototype-mode"]
        mode.buttons["Rich text"].tap()
        XCTAssertTrue(app.staticTexts["prototype-issue"].exists)
        XCTAssertFalse(app.textViews["prototype-rich"].exists)
        app.buttons["Edit in Markdown"].tap()
        XCTAssertEqual(source.value as? String, original)
        app.buttons["prototype-samples"].tap(); app.buttons["Plain text"].tap()
        let rich = app.textViews["prototype-rich"]
        app.buttons["prototype-select-all"].tap()
        rich.typeText("Native typing works. مرحبا Fomio")
        mode.buttons["Markdown"].tap()
        let typed = try XCTUnwrap(source.value as? String)
        XCTAssertTrue(typed.contains("Native typing works"))
        mode.buttons["Rich text"].tap()
        XCTAssertEqual(rich.value as? String, "Native typing works. مرحبا Fomio")
    }
}

private extension XCUIElement {
    var hasKeyboardFocus: Bool { (value(forKey: "hasKeyboardFocus") as? Bool) == true }
    func waitForContainingValue(_ string: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", string), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    func waitForValue(_ string: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", string), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
