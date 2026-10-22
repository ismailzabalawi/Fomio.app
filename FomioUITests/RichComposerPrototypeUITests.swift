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
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.buttons["prototype-redo"].tap()
        XCTAssertEqual(rich.value as? String, "مرحبا Fomio")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
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
    func waitForContainingValue(_ string: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", string), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    func waitForValue(_ string: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", string), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
