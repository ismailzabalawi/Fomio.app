#if DEBUG
import XCTest
import SwiftUI
import UIKit
import UniformTypeIdentifiers
@testable import Fomio

@MainActor final class PrototypeEditorSessionTests: XCTestCase {
    func testUndoRedoFormattingAndModesRestoreExactSourceAndSelection() throws {
        let original = "__مرحبا__ 👋🏽\n\n_family_ 👨‍👩‍👧‍👦\n"
        var session = PrototypeEditorSession(source: original)
        let range = try XCTUnwrap(session.value.text.range(of: "👋🏽"))
        session.select(AttributedTextSelection(range: range))
        let selected = session.value.selection
        session.format(.strike)
        let formatted = session.value.text
        XCTAssertTrue(session.changeMode(true))
        let exported = session.value.source
        XCTAssertTrue(exported.contains("[s]👋🏽[/s]"))
        XCTAssertTrue(exported.hasSuffix("\n\n_family_ 👨‍👩‍👧‍👦\n"))
        session.undo()
        XCTAssertFalse(session.value.markdown)
        XCTAssertEqual(session.value.text, formatted)
        XCTAssertEqual(session.value.selection, selected)
        session.undo()
        XCTAssertEqual(session.value.document.source, original)
        XCTAssertEqual(session.value.text, PrototypeRichDocument(source: original).projection)
        XCTAssertEqual(session.value.selection, selected)
        session.redo(); session.redo()
        XCTAssertTrue(session.value.markdown)
        XCTAssertEqual(Array(session.value.source.utf8), Array(exported.utf8))
        XCTAssertFalse(session.canRedo)
    }
    func testTypingGroupsStopAtFormattingModeChangesAndNewBranches() throws {
        var session = PrototypeEditorSession(source: "")
        let date = Date(timeIntervalSince1970: 100)
        session.editRich(AttributedString("ا"), now: date)
        session.editRich(AttributedString("اب"), now: date.addingTimeInterval(0.1))
        session.select(AttributedTextSelection(range: session.value.text.startIndex..<session.value.text.endIndex))
        session.format(.bold)
        session.changeMode(true)
        session.editSource("**new**", now: date.addingTimeInterval(0.2))
        session.undo()
        XCTAssertTrue(session.value.source.contains("[b]اب[/b]"))
        session.undo(); session.undo()
        XCTAssertEqual(String(session.value.text.characters), "اب")
        session.undo()
        XCTAssertEqual(String(session.value.text.characters), "")
        session.redo()
        XCTAssertEqual(String(session.value.text.characters), "اب")
        session.editRich(AttributedString("new branch"))
        XCTAssertFalse(session.canRedo)
        session.undo()
        XCTAssertEqual(String(session.value.text.characters), "اب")
    }
    func testCaretFormattingIsUndoableAndControlsSubsequentTyping() throws {
        var session = PrototypeEditorSession(source: "مرحبا")
        session.select(AttributedTextSelection(insertionPoint: session.value.text.endIndex))
        session.format(.italic)
        XCTAssertTrue(session.canUndo)
        XCTAssertTrue(session.value.selection.typingAttributes(in: session.value.text)[PrototypeMarksAttribute.self]?.contains(.italic) == true)
        session.undo()
        XCTAssertFalse(session.value.selection.typingAttributes(in: session.value.text)[PrototypeMarksAttribute.self]?.contains(.italic) == true)
        session.redo()
        var text = session.value.text, selection = session.value.selection
        text.replaceSelection(&selection, withCharacters: " 😀")
        session.editRich(text); session.select(selection)
        session.changeMode(true)
        XCTAssertTrue(session.value.source.contains("[i] 😀[/i]"))
    }
    func testFailedSwitchDoesNotCreateHistoryOrLoseRichEdit() {
        var session = PrototypeEditorSession(source: "original")
        session.editRich(AttributedString("    cannot export"))
        XCTAssertFalse(session.changeMode(true))
        XCTAssertFalse(session.value.markdown)
        XCTAssertEqual(String(session.value.text.characters), "    cannot export")
        session.undo()
        XCTAssertEqual(String(session.value.text.characters), "original")
        XCTAssertNil(session.value.document.issue)
        session.redo()
        XCTAssertEqual(String(session.value.text.characters), "    cannot export")
    }
    func testUnsupportedSourceAndSampleLoadAreUndoable() {
        let source = "[poll]\n* نعم 😀\n* No\n[/poll]"
        var session = PrototypeEditorSession(source: source)
        session.changeMode(false)
        XCTAssertNil(session.value.document.projection)
        session.undo()
        XCTAssertTrue(session.value.markdown)
        XCTAssertEqual(session.value.source, source)
        session.load("plain")
        session.undo()
        XCTAssertEqual(session.value.source, source)
        session.redo()
        XCTAssertEqual(String(session.value.text.characters), "plain")
    }
    func testPasteReplacesSelectionAtomicallyAndUndoRestoresEmojiAndSource() throws {
        var session = PrototypeEditorSession(source: "__keep__ مرحبا 👨‍👩‍👧‍👦 end")
        let range = try XCTUnwrap(session.value.text.range(of: "مرحبا 👨‍👩‍👧‍👦"))
        session.select(AttributedTextSelection(range: range))
        let original = session.value
        let pasted = try PrototypePaste.plain("👋🏽 **literal**\nالعربية e\u{301}").text
        session.paste(pasted)
        XCTAssertEqual(String(session.value.text.characters), "keep 👋🏽 **literal**\nالعربية e\u{301} end")
        session.undo()
        XCTAssertEqual(session.value.text, original.text)
        XCTAssertEqual(session.value.selection, original.selection)
        session.redo(); session.changeMode(true)
        XCTAssertTrue(session.value.source.contains("\\*\\*literal\\*\\*"))
    }
    func testMarkdownPasteKeepsLiteralBytesAndRestoresSelection() throws {
        var session = PrototypeEditorSession(source: "__مرحبا__ 👋🏽")
        session.changeMode(true)
        let original = session.value.source
        let range = try XCTUnwrap(original.range(of: "👋🏽"))
        session.selectSource(TextSelection(range: range))
        session.paste(try PrototypePaste.plain("[poll]\r\n* 😀\r\n[/poll]").text)
        XCTAssertEqual(session.value.source, "__مرحبا__ [poll]\r\n* 😀\r\n[/poll]")
        session.undo()
        XCTAssertEqual(session.value.source, original)
        XCTAssertEqual(session.value.sourceSelection?.indices, TextSelection(range: range).indices)
        session.redo(); session.changeMode(false)
        XCTAssertNil(session.value.document.projection)
    }
    func testDelayedPasteCannotOverwriteAfterEditingSelectionModeOrUndo() throws {
        let clipboard = try PrototypePaste.plain("clipboard 😀").text
        var session = PrototypeEditorSession(source: "original 👋🏽")
        var target = session.pasteTarget
        session.editRich(AttributedString("new writing"))
        XCTAssertFalse(session.paste(clipboard, at: target))
        XCTAssertEqual(String(session.value.text.characters), "new writing")
        target = session.pasteTarget
        session.undo()
        XCTAssertFalse(session.paste(clipboard, at: target))
        target = session.pasteTarget
        session.select(AttributedTextSelection(range: session.value.text.startIndex..<session.value.text.endIndex))
        XCTAssertFalse(session.paste(clipboard, at: target))
        target = session.pasteTarget
        session.changeMode(true)
        XCTAssertFalse(session.paste(clipboard, at: target))
        target = session.pasteTarget
        XCTAssertTrue(session.paste(clipboard, at: target))
        XCTAssertFalse(session.paste(clipboard, at: target))
        XCTAssertEqual(session.value.source, "original 👋🏽clipboard 😀")
    }
    func testDiscontiguousMarkdownPasteReplacesOnceAndIsUndoable() throws {
        var session = PrototypeEditorSession(source: "one مرحبا two 👋🏽 end")
        session.changeMode(true)
        let source = session.value.source
        let ranges = RangeSet([try XCTUnwrap(source.range(of: "one")), try XCTUnwrap(source.range(of: "two"))])
        session.selectSource(TextSelection(ranges: ranges))
        session.paste(try PrototypePaste.plain("😀").text)
        XCTAssertEqual(session.value.source, "😀 مرحبا  👋🏽 end")
        session.undo()
        XCTAssertEqual(session.value.source, source)
        XCTAssertEqual(session.value.sourceSelection?.indices, TextSelection(ranges: ranges).indices)
    }
    func testRichPasteMapsOnlySupportedMarksAndNormalizesAppearance() throws {
        let string = "مرحبا 👋🏽 👨‍👩‍👧‍👦"
        let font = UIFont.systemFont(ofSize: 30, weight: .bold)
        let descriptor = try XCTUnwrap(font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]))
        let imported = NSAttributedString(string: string, attributes: [.font: UIFont(descriptor: descriptor, size: 30), .strikethroughStyle: 1, .foregroundColor: UIColor.red])
        let content = try PrototypePaste.rich(imported)
        XCTAssertEqual(String(content.text.characters), string)
        XCTAssertEqual(content.text.runs.first?[PrototypeMarksAttribute.self], [.bold, .italic, .strike])
        XCTAssertNotNil(content.notice)
        var session = PrototypeEditorSession(source: "")
        session.paste(content.text)
        XCTAssertTrue(session.changeMode(true))
        XCTAssertTrue(session.value.source.contains("[b][i][s]مرحبا"))
        session.undo(); session.undo()
        XCTAssertTrue(session.value.text.characters.isEmpty)
    }
    func testUnsupportedRichPasteNeverSilentlyDropsLinksAttachmentsOrUnderline() {
        for attributes: [NSAttributedString.Key: Any] in [
            [.link: URL(string: "https://example.com")!],
            [.underlineStyle: 1], [.attachment: NSTextAttachment()],
            [.baselineOffset: 4]
        ] {
            XCTAssertThrowsError(try PrototypePaste.rich(NSAttributedString(string: "العربية 😀", attributes: attributes)))
        }
        XCTAssertThrowsError(try PrototypePaste.rich(NSAttributedString(string: "\u{FFFC}")))
        XCTAssertThrowsError(try PrototypePaste.plain(String(repeating: "a", count: PrototypePaste.limit + 1)))
    }
    func testAsyncProvidersPreserveOrderAndRejectWholeMixedPaste() async throws {
        let a = NSItemProvider(object: "مرحبا 👋🏽" as NSString)
        let b = NSItemProvider(object: "**literal** 👨‍👩‍👧‍👦" as NSString)
        let imported = try await PrototypePaste.read([a, b], plainText: false)
        XCTAssertEqual(String(imported.text.characters), "مرحبا 👋🏽\n**literal** 👨‍👩‍👧‍👦")
        let html = NSItemProvider()
        html.registerDataRepresentation(forTypeIdentifier: UTType.html.identifier, visibility: .all) { completion in
            completion(Data("<b>hello</b>".utf8), nil); return nil
        }
        do {
            _ = try await PrototypePaste.read([a, html], plainText: false)
            XCTFail("Mixed unsupported paste must fail as one transaction")
        } catch {}
    }
    func testNativePasteMapsFontTraitsAndBlocksUnsupportedExportWithoutLosingBuffer() throws {
        var text = AttributedString("مرحبا 👋🏽")
        text.font = .body.bold().italic()
        text.strikethroughStyle = .single
        let mapped = PrototypePaste.native(text, context: EnvironmentValues().fontResolutionContext)
        XCTAssertEqual(mapped.runs.first?[PrototypeMarksAttribute.self], [.bold, .italic, .strike])
        var session = PrototypeEditorSession(source: "original")
        var linked = mapped
        linked.link = URL(string: "https://example.com")
        session.editRich(linked)
        XCTAssertFalse(session.changeMode(true))
        XCTAssertEqual(session.value.text, linked)
        XCTAssertEqual(session.value.document.source, "original")
        XCTAssertNotNil(session.value.document.issue)
        session.undo()
        XCTAssertEqual(String(session.value.text.characters), "original")
        session.redo()
        XCTAssertEqual(session.value.text, linked)
    }
    func testRTFProviderUsesRichRepresentationBeforePlainFallback() async throws {
        let original = NSAttributedString(string: "مرحبا 👋🏽 👨‍👩‍👧‍👦", attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .strikethroughStyle: 1])
        let data = try original.data(from: NSRange(location: 0, length: original.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let provider = NSItemProvider(object: "WRONG FALLBACK" as NSString)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
            completion(data, nil); return nil
        }
        let content = try await PrototypePaste.read([provider], plainText: false)
        XCTAssertEqual(String(content.text.characters), original.string)
        XCTAssertEqual(content.text.runs.first?[PrototypeMarksAttribute.self], [.bold, .strike])
        let plain = try await PrototypePaste.read([provider], plainText: true)
        XCTAssertEqual(String(plain.text.characters), "WRONG FALLBACK")
    }
}
#endif
