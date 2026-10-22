#if DEBUG
import XCTest
import SwiftUI
@testable import Fomio

final class PrototypeRichDocumentTests: XCTestCase {
    func testModeSwitchWithoutEditsPreservesUTF8IncludingBlankLinesAndSpellings() throws {
        for source in ["", "\n\n", "مرحبا **بالعالم** 👋🏽\n\n*English* 👨‍👩‍👧‍👦\n", "__bold__ and _italic_ and ~~old~~", "\\*literal\\* \\[brackets\\] \\\\", "[b]one [i]اثنان 😀[/i][/b]"] {
            var document = PrototypeRichDocument(source: source)
            for _ in 0..<5 {
                let projection = try XCTUnwrap(document.projection, source)
                document.commit(projection)
                XCTAssertEqual(Array(document.source.utf8), Array(source.utf8))
            }
        }
    }

    func testEditedFormattingRoundTripsUnicodeAndLiteralMarkup() throws {
        let literal = "مرحبا 👋🏽 👨‍👩‍👧‍👦 e\u{301} **literal** [poll] _x_ `code` \\ <html> # ! &"
        for marks: PrototypeMarks in [[], .bold, .italic, .strike, [.bold, .italic], [.bold, .italic, .strike]] {
            var document = PrototypeRichDocument(source: "")
            var edited = AttributedString(literal)
            var attributes = AttributeContainer()
            PrototypeRichDocument.apply(marks, to: &attributes); edited.setAttributes(attributes)
            document.commit(edited)
            let restored = try XCTUnwrap(document.projection, document.source)
            XCTAssertEqual(String(restored.characters), literal)
            XCTAssertEqual(restored, PrototypeRichDocument.normalized(edited))
            let serialized = document.source
            document.commit(restored)
            XCTAssertEqual(document.source, serialized)
        }
    }

    func testOnlyEditedLineChangesWhileOtherSourceSpellingsSurvive() throws {
        let source = "__مرحبا__ 👋🏽\n\nKeep _this_ spelling\n\nLast **line**\n"
        var document = PrototypeRichDocument(source: source)
        var edited = try XCTUnwrap(document.projection)
        let range = try XCTUnwrap(edited.range(of: "this"))
        var attributes = edited[range].runs.first!.attributes
        PrototypeRichDocument.apply([.italic, .strike], to: &attributes)
        edited[range].setAttributes(attributes)
        document.commit(edited)
        XCTAssertTrue(document.source.hasPrefix("__مرحبا__ 👋🏽\n\n"))
        XCTAssertTrue(document.source.hasSuffix("\n\nLast **line**\n"))
        XCTAssertTrue(document.source.contains("[i][s]this[/s][/i]"))
        XCTAssertEqual(document.projection, PrototypeRichDocument.normalized(edited))
    }

    func testNewParagraphPreservesUnchangedSourceBeforeAndAfterInsertion() throws {
        var document = PrototypeRichDocument(source: "__first__\n_last_\n")
        var edited = try XCTUnwrap(document.projection)
        let boundary = try XCTUnwrap(edited.range(of: "last")).lowerBound
        var inserted = AttributedString("جديد 😀\n")
        var attributes = AttributeContainer(); PrototypeRichDocument.apply([], to: &attributes); inserted.setAttributes(attributes)
        edited.replaceSubrange(boundary..<boundary, with: inserted)
        document.commit(edited)
        XCTAssertEqual(document.source, "__first__\nجديد 😀\n_last_\n")
    }

    func testUnsupportedAndMalformedSourceCannotBeRewrittenByRichCommit() {
        for source in ["[poll]\n* نعم\n* No\n[/poll]", "[quote=\"sam, post:2, topic:42\"]hi[/quote]", "![photo](upload://a.jpg)", "# Heading", "- list", "1. item", "    code", "[link](https://example.com)", "**unclosed", "x ** space**", "a_b_c", "```code```", "a\r\nb", "[unknown]x[/unknown]", "| A | B |"] {
            var document = PrototypeRichDocument(source: source)
            XCTAssertNil(document.projection, source)
            XCTAssertNotNil(document.issue, source)
            document.commit(AttributedString("Should never replace source"))
            XCTAssertEqual(Array(document.source.utf8), Array(source.utf8))
        }
    }

    func testClearingTextAndDeletingParagraphsIsNotReplacedByCachedSource() throws {
        var document = PrototypeRichDocument(source: "**first**\n\n_last_")
        document.commit(AttributedString())
        XCTAssertEqual(document.source, "")
        XCTAssertEqual(String(try XCTUnwrap(document.projection).characters), "")
    }

    func testUnsupportedSourceCanBeEditedIntoSupportedProse() {
        let blocked = PrototypeRichDocument(source: "[poll]x[/poll]")
        XCTAssertNil(blocked.projection)
        let revised = PrototypeRichDocument(source: "مرحبا **Fomio** 😀")
        XCTAssertNotNil(revised.projection)
        XCTAssertNil(revised.issue)
    }

    func testUnrepresentableEditKeepsTheRichBufferAndOriginalSource() throws {
        var document = PrototypeRichDocument(source: "original")
        let edited = AttributedString("    indented text")
        XCTAssertFalse(document.commit(edited))
        XCTAssertEqual(document.source, "original")
        XCTAssertNotNil(document.issue)
        // The caller retains the rich buffer on failed conversion instead of changing modes.
        XCTAssertEqual(String(edited.characters), "    indented text")
        XCTAssertTrue(document.commit(AttributedString("fixed")))
        XCTAssertNil(document.issue)
        XCTAssertEqual(document.source, "fixed")
        XCTAssertNil(PrototypeRichDocument(source: "&amp;").projection)
        for source in ["Title\n===", "Hello @sam", ":smile:", "https://example.com"] {
            XCTAssertNil(PrototypeRichDocument(source: source).projection, source)
        }
    }

    func testAppearanceOnlyAttributesDoNotInventPostFormatting() throws {
        var document = PrototypeRichDocument(source: "unchanged")
        var edited = try XCTUnwrap(document.projection)
        edited.foregroundColor = .red
        edited.font = .largeTitle.bold()
        document.commit(edited)
        XCTAssertEqual(document.source, "unchanged")
    }

    func testSelectionFormattingAndCaretTypingRetainSemanticMarks() throws {
        var document = PrototypeRichDocument(source: "مرحبا 👨‍👩‍👧‍👦 English")
        var text = try XCTUnwrap(document.projection)
        let range = try XCTUnwrap(text.range(of: "👨‍👩‍👧‍👦"))
        var selection = AttributedTextSelection(range: range)
        text.transformAttributes(in: &selection) { attributes in
            PrototypeRichDocument.apply([.bold, .italic], to: &attributes)
        }
        XCTAssertEqual(String(text[selection].characters), "👨‍👩‍👧‍👦")
        document.commit(text)
        XCTAssertTrue(document.source.contains("[b][i]👨‍👩‍👧‍👦[/i][/b]"))
        text = try XCTUnwrap(document.projection)
        selection = AttributedTextSelection(insertionPoint: text.endIndex)
        text.transformAttributes(in: &selection) { attributes in PrototypeRichDocument.apply(.strike, to: &attributes) }
        text.replaceSelection(&selection, withCharacters: " جديد 👋🏽")
        document.commit(text)
        XCTAssertTrue(document.source.contains("[s] جديد 👋🏽[/s]"), document.source)
    }
}
#endif
