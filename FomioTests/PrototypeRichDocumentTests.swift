#if DEBUG
import XCTest
import SwiftUI
@testable import Fomio

final class PrototypeRichDocumentTests: XCTestCase {
    func testModeSwitchWithoutEditsPreservesUTF8IncludingBlankLinesAndSpellings() throws {
        for source in ["", "\n\n", "مرحبا **بالعالم** 👋🏽\n\n*English* 👨‍👩‍👧‍👦\n", "* star\n+ plus\n\n3) three\n5) five\n\n>quote\n>\n> مرحبا", "See [**the** guide](https://meta.discourse.org/t/1?a=b#c) or [mail](mailto:a@example.com)", "__bold__ and _italic_ and ~~old~~", "\\*literal\\* \\[brackets\\] \\\\", "[b]one [i]اثنان 😀[/i][/b]"] {
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
        for source in ["[poll]\n* نعم\n* No\n[/poll]", "[quote=\"sam, post:2, topic:42\"]hi[/quote]", "![photo](upload://a.jpg)", "# Heading", "- list\nlazy continuation", "> quote\nlazy", "text\n2. item", "text\n- ", "- > nested", "> > nested", "- - nested", "1. a\n2) b", "-  two spaces", "-", "text\n--", "![image](https://example.com/a.png)", "[reference][1]", "[script](javascript:alert(1))", "[spaced](https://example.com/a b)", "[nested [link](https://a.com)](https://b.com)", "    code", "**unclosed", "x ** space**", "a_b_c", "```code```", "a\r\nb", "[unknown]x[/unknown]", "| A | B |"] {
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
        for source in ["Title\n===", ":smile:", "https://example.com"] {
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
    func testListsQuotesAndLinksProjectAsRenderedAndRoundTrip() throws {
        let source = "Intro [guide](https://meta.discourse.org) here.\n\n- مرحبا 👋🏽\n- **Two**\n\n3. Three\n9. Next\n\n> Quoted *words*\n>\n> More"
        var document = PrototypeRichDocument(source: source)
        let projection = try XCTUnwrap(document.projection, document.issue ?? "")
        // Ordered markers show the rendered numbers, not the source digits.
        XCTAssertEqual(String(projection.characters), "Intro guide here.\n\n• مرحبا 👋🏽\n• Two\n\n3. Three\n4. Next\n\n▎ Quoted words\n▎ \n▎ More")
        let guide = try XCTUnwrap(projection.range(of: "guide"))
        XCTAssertEqual(projection[guide].runs.first?[PrototypeLinkAttribute.self], URL(string: "https://meta.discourse.org"))
        XCTAssertTrue(document.commit(projection))
        XCTAssertEqual(document.source, source)
    }

    func testEditedBlockLinesSerializeAndKeepNeighbourSpelling() throws {
        var document = PrototypeRichDocument(source: "* one\n* two\n\n1) a\n2) b")
        var lines = PrototypeRichDocument.split(try XCTUnwrap(document.projection))
        // A new bullet and a new ordered item between existing ones.
        lines.insert(PrototypeRichDocument.marker(.bullet) + plain("نعم 😀"), at: 1)
        lines.insert(PrototypeRichDocument.marker(.ordered(2)) + plain("new"), at: 5)
        let renumbered = PrototypeRichDocument.normalizeBlocks(join(lines)).text
        XCTAssertTrue(document.commit(renumbered), document.issue ?? "")
        XCTAssertEqual(document.source, "* one\n* نعم 😀\n* two\n\n1) a\n2) new\n3) b")
    }

    func testLinkSerializationEscapesLabelAndRejectsUnsafeAddresses() throws {
        var document = PrototypeRichDocument(source: "")
        var text = plain("A [b] مرحبا 😀")
        text[try XCTUnwrap(text.range(of: "[b] مرحبا"))][PrototypeLinkAttribute.self] = URL(string: "https://example.com/x?y=1")
        XCTAssertTrue(document.commit(PrototypeRichDocument.normalized(text)), document.issue ?? "")
        XCTAssertEqual(document.source, "A [\\[b\\] مرحبا](https://example.com/x?y=1) 😀")
        XCTAssertEqual(document.projection, PrototypeRichDocument.normalized(text))
        for address in ["javascript:alert(1)", "https://example.com/a(b)", "ftp://example.com", "https://", "mailto:"] {
            XCTAssertFalse(URL(string: address).map(PrototypeRichDocument.isLinkable) ?? false, address)
        }
    }

    func testParagraphDirectlyAfterListIsRefusedWithoutLosingText() throws {
        var document = PrototypeRichDocument(source: "- item")
        var text = try XCTUnwrap(document.projection)
        text += plain("\nlazy")
        XCTAssertFalse(document.commit(text))
        XCTAssertEqual(document.source, "- item")
        XCTAssertTrue(document.issue?.contains("empty line") == true)
    }

    func testBrokenMarkerIsRemovedAndInheritedMarkerAttributesBecomeContent() throws {
        let document = PrototypeRichDocument(source: "- one\n- two")
        var text = try XCTUnwrap(document.projection)
        // Delete the space of the second marker, as Backspace at the start of its text would.
        let second = try XCTUnwrap(text.range(of: "• two"))
        let space = text.characters.index(after: second.lowerBound)
        text.removeSubrange(space..<text.characters.index(after: space))
        // Typing after the first marker inherits its attributes.
        let firstMarker = try XCTUnwrap(text.range(of: "• "))
        var typed = AttributedString("x"); typed.setAttributes(text[firstMarker].runs.first!.attributes)
        text.insert(typed, at: firstMarker.upperBound)
        let repaired = PrototypeRichDocument.normalizeBlocks(text).text
        XCTAssertEqual(String(repaired.characters), "• xone\ntwo")
        XCTAssertEqual(PrototypeRichDocument.markerInfo(PrototypeRichDocument.split(repaired)[0])?.length, 2)
        XCTAssertNil(PrototypeRichDocument.markerInfo(PrototypeRichDocument.split(repaired)[1]))
    }

    func testMentionsFollowDiscoursesRule() throws {
        // Expectations from Discourse's pretty-text tests and text-post-process boundaries.
        let cases: [(String, [String])] = [
            ("Hello @sam", ["sam"]), ("@sam yo", ["sam"]), ("(@sam)", ["sam"]), ("@foo/@bar", ["foo", "bar"]),
            ("@bob.", ["bob"]), ("@bob\\_", ["bob"]), ("@b", ["b"]),
            ("@\\_sam @1sam @ab-cd.123\\_ABC-xYz @sam1", ["_sam", "1sam", "ab-cd.123_ABC-xYz", "sam1"]),
            // Escaping does not stop a mention: the pass runs on joined text.
            ("\\@bob", ["bob"]),
            // A formatting or link edge ends the text token, so it counts as a boundary.
            ("**x**@bob", ["bob"]), ("x**@bob**", ["bob"]), ("- @bob", ["bob"]), ("> @bob", ["bob"]),
            // Letters and astral characters are not boundaries; link labels are skipped.
            ("a@bob", []), ("a@b.com", []), ("@bob👋", []), ("👋@bob", []), ("@ alone", []), ("[@bob](https://example.com)", [])
        ]
        for (source, expected) in cases {
            let projection = try XCTUnwrap(PrototypeRichDocument(source: source).projection, source)
            XCTAssertEqual(PrototypeMentions.find(in: projection).mentions.map(\.username), expected, source)
            XCTAssertEqual(projection.runs.compactMap { $0[PrototypeMentionAttribute.self] }, expected, source)
        }
        // These depend on the `unicode_usernames` site setting, which is unknown here, so they stay in source.
        for source in ["@مرحبا", "@bobé", "@bob\u{301}"] { XCTAssertNil(PrototypeRichDocument(source: source).projection, source) }
    }
    func testMentionsRoundTripAndSerializeReadably() throws {
        for source in ["Hello @sam and \\@sam", "@foo/@bar", "**hi @bob ok**"] {
            var document = PrototypeRichDocument(source: source)
            XCTAssertTrue(document.commit(try XCTUnwrap(document.projection)))
            XCTAssertEqual(document.source, source)
        }
        var document = PrototypeRichDocument(source: "old")
        XCTAssertTrue(document.commit(plain("hi @bob.smith-x and a@b.com @a_b")), document.issue ?? "")
        XCTAssertEqual(document.source, "hi @bob.smith-x and a\\@b\\.com @a\\_b")
        // Mention styling must not split a formatting tag.
        XCTAssertTrue(document.commit(try XCTUnwrap(PrototypeRichDocument(source: "**hi @bob ok**").projection)))
        XCTAssertEqual(document.source, "[b]hi @bob ok[/b]")
    }
    func testAmbiguousMentionIsRefusedWithoutLosingText() throws {
        var document = PrototypeRichDocument(source: "keep")
        XCTAssertFalse(document.commit(plain("@bobé")))
        XCTAssertEqual(document.source, "keep")
        XCTAssertNotNil(document.issue)
        XCTAssertTrue(document.commit(plain("@bob é")), document.issue ?? "")
        XCTAssertEqual(document.source, "@bob é")
        XCTAssertNil(document.issue)
    }

    private func plain(_ string: String) -> AttributedString {
        var text = AttributedString(string)
        var attributes = AttributeContainer(); PrototypeRichDocument.apply([], to: &attributes); text.setAttributes(attributes)
        return text
    }
    private func join(_ lines: [AttributedString]) -> AttributedString {
        var result = AttributedString()
        for (index, line) in lines.enumerated() { if index > 0 { result += plain("\n") }; result += line }
        return result
    }
}
#endif
