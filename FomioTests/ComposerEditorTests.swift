import XCTest
import SwiftUI
@testable import Fomio

final class ComposerEditorTests: XCTestCase {
    func testDuplicateServerReferencesKeepIndependentPhotoIdentity() {
        let server = UploadedPhoto(url: "https://example.com/p.jpg", shortURL: "upload://same.jpg")
        let first = ComposerAttachment(server: server, status: .uploaded), second = ComposerAttachment(server: server, status: .uploaded)
        var draft = Draft(account: .fixture, intent: .newDiscussion, body: first.markup + "\n" + second.markup, attachments: [first, second])
        draft.synchronizeAttachments()
        let original = draft.body
        XCTAssertEqual(draft.activeAttachments.map(\.id), [first.id, second.id])
        draft.body = DiscourseMarkupCodec.replace(draft.body, range: draft.attachmentBindings[0].node.range, with: "")
        draft.synchronizeAttachments(previousBody: original)
        XCTAssertEqual(draft.activeAttachments.map(\.id), [second.id])
        let removed = draft.body; draft.body = original; draft.synchronizeAttachments(previousBody: removed)
        XCTAssertEqual(draft.activeAttachments.map(\.id), [first.id, second.id])
        let beforePrefix = draft.body; draft.body = "Long prefix 😀\n" + draft.body; draft.synchronizeAttachments(previousBody: beforePrefix)
        XCTAssertEqual(draft.activeAttachments.map(\.id), [first.id, second.id])
        XCTAssertEqual(draft.activeAttachments.first?.sourceLocation, ("Long prefix 😀\n" as NSString).length)
    }
    func testPhotoDescriptionsEscapeDelimitersWithoutLosingAttachment() {
        let description = "Photo [Arabic] \\ 😀"
        let photo = ComposerAttachment(description: description)
        var draft = Draft(account: .fixture, intent: .newDiscussion, body: photo.markup, attachments: [photo])
        draft.synchronizeAttachments()
        XCTAssertEqual(draft.activeAttachments.map(\.id), [photo.id])
        XCTAssertEqual(DiscourseMarkupCodec.parse(photo.markup).first?.text, description)
        XCTAssertEqual(DiscourseMarkupCodec.parse(photo.markup).map(\.raw).joined(), photo.markup)
    }
    func testLinkFormEscapesLabelsAndURLDelimiters() {
        let raw = DiscourseMarkupCodec.link(label: "A [link]", url: "https://example.com/a(b)")
        let node = DiscourseMarkupCodec.parse(raw).first
        XCTAssertEqual(node?.link, "https://example.com/a%28b%29")
        XCTAssertEqual(node?.text, "A [link]")
        XCTAssertEqual(DiscourseMarkupCodec.parse(raw).map(\.raw).joined(), raw)
    }
    func testProjectionPreservesEverySourceByte() {
        let fixtures = ["Hello **world** and *you*", "مرحبا 👨‍👩‍👧‍👦 **English**", "[unknown mode=x]untouched[/unknown]", "[quote=\"sam, post:2, topic:42\"]Quoted[/quote]\nReply", "```swift\nlet x = 1\n```\n", "| A | B |\n| --- | --- |\n| 1 | 2 |", "![first](upload://a.jpg)\ntext\n![second](upload://b.jpg)", "[poll]\n* A\n* B\n[/poll]", "**malformed", "[details=Summary]body[/details]"]
        for raw in fixtures {
            XCTAssertEqual(DiscourseMarkupCodec.parse(raw).map(\.raw).joined(), raw)
        }
    }
    func testUnknownBlockIsOpaque() {
        XCTAssertEqual(DiscourseMarkupCodec.parse("[custom]keep me[/custom]").first?.kind, .opaque)
    }
    func testUnsupportedMarkdownBlocksStayOpaqueAndSourcePreserved() {
        for raw in ["# Heading\n", "1. Ordered item\n", "- [x] Task\n", "---\n", "~~~ruby\nliteral\n~~~\n"] {
            let nodes = DiscourseMarkupCodec.parse(raw)
            XCTAssertEqual(nodes.first?.kind, .opaque, raw); XCTAssertEqual(nodes.map(\.raw).joined(), raw)
        }
    }
    func testUnicodeReplacementRejectsSplitSurrogate() {
        XCTAssertEqual(DiscourseMarkupCodec.replace("😀hello", range: NSRange(location: 1, length: 1), with: "x"), "😀hello")
        XCTAssertEqual(DiscourseMarkupCodec.replace("😀hello", range: NSRange(location: 2, length: 5), with: "مرحبا"), "😀مرحبا")
    }
    func testStandalonePreviewURLRequiresItsOwnLine() {
        XCTAssertEqual(DiscourseMarkupCodec.standaloneURLs("https://example.com\nSee https://example.org\n[link](https://example.net)").count, 1)
    }
}

@MainActor final class NativeEditorTests: XCTestCase {
    func testEscapedLinkProjectionMapsArabicAndEmojiSelectionToSource() {
        var raw = DiscourseMarkupCodec.link(label: "A [مرحبا] 😀", url: "https://example.com")
        let controller = EditorController()
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: .init(location: 0, length: 0))
        XCTAssertEqual(view.text, "A [مرحبا] 😀")
        let displayed = (view.text as NSString).range(of: "مرحبا")
        let source = coordinator.sourceRange(displayed)
        XCTAssertEqual((raw as NSString).substring(with: source), "مرحبا")
        XCTAssertEqual(coordinator.displayRange(source), displayed)
        let emoji = (view.text as NSString).range(of: "😀")
        XCTAssertEqual((raw as NSString).substring(with: coordinator.sourceRange(emoji)), "😀")
    }
    func testPartialStyledSelectionChangesOnlySelectedText() {
        var raw = "**Hello مرحبا world**"
        let controller = EditorController()
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: (raw as NSString).range(of: "مرحبا"))
        coordinator.command(.italic)
        XCTAssertEqual(raw, "**Hello** ***مرحبا*** **world**")
        coordinator.command(.undo); XCTAssertEqual(raw, "**Hello مرحبا world**")
        coordinator.render(raw, selection: (raw as NSString).range(of: "مرحبا"))
        coordinator.command(.bold)
        XCTAssertEqual(raw, "**Hello** مرحبا **world**")
        XCTAssertEqual(DiscourseMarkupCodec.parse(raw).map(\.text).joined(), "Hello مرحبا world")
    }
    func testUnsupportedBlockSourceActionSelectsOriginalMarkupWithoutUndoStep() {
        var raw = "Before\n[unknown]مرحبا 😀[/unknown]\nAfter"
        let original = raw, controller = EditorController()
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: .init(location: 0, length: 0))
        let node = DiscourseMarkupCodec.parse(raw).first { $0.kind == .opaque }!
        coordinator.command(.select(EditorSelection(node.range))); coordinator.command(.markdown)
        XCTAssertEqual(view.selectedRange, node.range); XCTAssertEqual(raw, original)
        XCTAssertFalse(coordinator.history.canUndo)
    }
    func testReturnOnEmptyListItemExitsTheList() {
        var raw = "- One\n- "
        let controller = EditorController()
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: .init(location: (raw as NSString).length, length: 0))
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: view.selectedRange, replacementText: "\n"))
        XCTAssertEqual(raw, "- One\n")
        raw = "- One"; coordinator.render(raw, selection: .init(location: (raw as NSString).length, length: 0))
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: view.selectedRange, replacementText: "\n"))
        XCTAssertEqual(raw, "- One\n- ")
    }
    func testTypingBeforeAttachmentUpdatesItsActionRange() throws {
        var raw = "Text\n```swift\nlet x = 1\n```"
        let controller = EditorController()
        var removed: NSRange?
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller, onRemove: { removed = $0.range }))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: .init(location: 0, length: 0))
        let span = try XCTUnwrap(coordinator.spans.first { $0.node.kind == .code })
        let attachment = try XCTUnwrap(view.textStorage.attribute(.attachment, at: span.display.location, effectiveRange: nil) as? ComposerTextAttachment)
        let prefix = "مرحبا "
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: .init(location: 0, length: 0), replacementText: prefix))
        view.textStorage.insert(NSAttributedString(string: prefix), at: 0); view.selectedRange = .init(location: (prefix as NSString).length, length: 0)
        coordinator.textViewDidChange(view); attachment.remove?()
        XCTAssertEqual(attachment.node.range.location, span.node.range.location + (prefix as NSString).length)
        XCTAssertEqual(removed, attachment.node.range)
    }
    func testTurningOffCaretStyleKeepsSubsequentTypingPlain() {
        var raw = "**Hello**"
        let controller = EditorController(); controller.boldTyping = true
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: .init(location: 7, length: 0))
        coordinator.command(.bold)
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: view.selectedRange, replacementText: " plain"))
        view.text = "Hello plain"; view.selectedRange = .init(location: 11, length: 0)
        coordinator.textViewDidChange(view)
        XCTAssertEqual(raw, "**Hello** plain")
    }
    func testCaretFormattingTypingUndoAndExternalInsertion() {
        var raw = ""
        let controller = EditorController()
        let coordinator = NativeComposerEditor.Coordinator(NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller))
        let view = ComposerTextView(usingTextLayoutManager: true)
        coordinator.view = view; controller.coordinator = coordinator; view.documentUndoManager = coordinator.history
        coordinator.render(raw, selection: .init(location: 0, length: 0))
        coordinator.command(.bold); coordinator.command(.italic)
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: view.selectedRange, replacementText: "مرحبا 😀"))
        view.text = "مرحبا 😀"; view.selectedRange = .init(location: (view.text as NSString).length, length: 0)
        coordinator.textViewDidChange(view)
        XCTAssertEqual(raw, "***مرحبا 😀***")
        if coordinator.history.groupingLevel > 0 { coordinator.history.endUndoGrouping() }
        coordinator.command(.undo); XCTAssertEqual(raw, "")
        coordinator.command(.redo); XCTAssertEqual(raw, "***مرحبا 😀***")
        if coordinator.history.groupingLevel > 0 { coordinator.history.endUndoGrouping() }
        let previous = raw
        raw += "\n![photo](fomio-attachment://test)"
        coordinator.command(.adopt(previous, EditorSelection(.init(location: (previous as NSString).length, length: 0))))
        if coordinator.history.groupingLevel > 0 { coordinator.history.endUndoGrouping() }
        coordinator.command(.undo); XCTAssertEqual(raw, previous)
        coordinator.command(.redo); XCTAssertTrue(raw.contains("fomio-attachment://test"))
    }
    func testFormattingModeSwitchAndUndoPreserveRaw() {
        var raw = "مرحبا 😀 world"
        let controller = EditorController()
        let parent = NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller)
        let coordinator = NativeComposerEditor.Coordinator(parent)
        let view = ComposerTextView(usingTextLayoutManager: true)
        coordinator.view = view; controller.coordinator = coordinator
        coordinator.render(raw, selection: NSRange(location: 9, length: 5))
        coordinator.command(.bold)
        XCTAssertEqual(raw, "مرحبا 😀 **world**")
        coordinator.command(.markdown)
        XCTAssertEqual(view.text, raw)
        coordinator.command(.markdown)
        XCTAssertEqual(view.text, "مرحبا 😀 world")
        if coordinator.history.groupingLevel > 0 { coordinator.history.endUndoGrouping() }
        coordinator.command(.undo)
        XCTAssertEqual(raw, "مرحبا 😀 world")
        coordinator.command(.redo)
        XCTAssertEqual(raw, "مرحبا 😀 **world**")
    }
    func testWrappingTitlePasteRemovesLineBreaksAndReturnMovesNext() {
        var raw = ""
        var next = false
        let controller = EditorController()
        let parent = NativeComposerEditor(raw: .init(get: { raw }, set: { raw = $0 }), controller: controller, isTitle: true, onNext: { next = true })
        let coordinator = NativeComposerEditor.Coordinator(parent)
        let view = ComposerTextView(usingTextLayoutManager: true); coordinator.view = view
        coordinator.render(raw, selection: NSRange(location: 0, length: 0))
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: .init(location: 0, length: 0), replacementText: "Long\ntitle"))
        XCTAssertEqual(raw, "Long title")
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: .init(location: 10, length: 0), replacementText: "\n"))
        XCTAssertTrue(next)
    }
}

@MainActor final class DraftAttachmentTests: XCTestCase {
    func testVersionOneMigrationKeepsIdentityQuotePhotoAndLock() throws {
        let legacy = Draft(version: 1, account: .fixture, intent: .reply(topic: .init(42), parent: .init(2)), body: "Reply", uploadedPhoto: UploadedPhoto(url: "https://example.com/p.jpg", shortURL: "upload://p.jpg"), submission: .unconfirmed, quote: QuoteExcerpt(author: "Sam", number: .init(2), text: "Quoted"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]); json.removeValue(forKey: "attachments")
        let restored = try JSONDecoder().decode(Draft.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.version, 2); XCTAssertEqual(restored.id, legacy.id); XCTAssertEqual(restored.account, legacy.account); XCTAssertEqual(restored.updatedAt, legacy.updatedAt)
        XCTAssertEqual(restored.submission, .unconfirmed); XCTAssertNil(restored.quote); XCTAssertNil(restored.uploadedPhoto)
        XCTAssertEqual(restored.activeAttachments.count, 1)
        XCTAssertTrue(restored.body.contains("topic:42")); XCTAssertEqual(restored.body.components(separatedBy: "upload://p.jpg").count, 2)
    }
    func testStartupReconcilesInterruptedRetentionWithinCurrentAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftStore(directory: directory)
        var draft = Draft(account: .fixture, intent: .newDiscussion)
        var kept = ComposerAttachment(), orphan = ComposerAttachment(), guest = ComposerAttachment()
        kept.localFileName = try store.retain(Data([1]), draft: draft, attachment: kept.id)
        orphan.localFileName = try store.retain(Data([2]), draft: draft, attachment: orphan.id)
        draft.attachments = [kept]; draft.body = kept.markup; try store.save(draft)
        let interruptedDraft = Draft(account: .fixture, intent: .newDiscussion)
        var interrupted = ComposerAttachment()
        interrupted.localFileName = try store.retain(Data([4]), draft: interruptedDraft, attachment: interrupted.id)
        let guestDraft = Draft(account: .guest, intent: .newDiscussion)
        guest.localFileName = try store.retain(Data([3]), draft: guestDraft, attachment: guest.id)
        let service = FixtureService(); let app = AppState(service: service, fixture: service, configuration: nil, store: store)
        XCTAssertNil(app.banner)
        XCTAssertEqual(try store.photo(draft: draft, attachment: kept), Data([1]))
        XCTAssertThrowsError(try store.photo(draft: draft, attachment: orphan))
        XCTAssertThrowsError(try store.photo(draft: interruptedDraft, attachment: interrupted))
        XCTAssertEqual(try store.photo(draft: guestDraft, attachment: guest), Data([3]))
        XCTAssertEqual(try store.list(account: .fixture).first?.id, draft.id)
    }
    func testRetainedFilesSurviveNewStoreAndDeleteWithDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftStore(directory: directory)
        var draft = Draft(account: .fixture, intent: .newDiscussion, body: "Writing")
        for value in [UInt8(1), 2] {
            var attachment = ComposerAttachment()
            attachment.localFileName = try store.retain(Data([value]), draft: draft, attachment: attachment.id)
            draft.attachments.append(attachment); draft.body += "\n" + attachment.markup
        }
        try store.save(draft)
        let newStore = DraftStore(directory: directory); let restored = try XCTUnwrap(newStore.list(account: .fixture).first)
        XCTAssertEqual(restored.activeAttachments.count, 2)
        XCTAssertEqual(try newStore.photo(draft: restored, attachment: restored.attachments[1]), Data([2]))
        XCTAssertTrue(try newStore.list(account: .guest).isEmpty)
        try newStore.delete(restored.id)
        XCTAssertThrowsError(try newStore.photo(draft: restored, attachment: restored.attachments[0]))
    }
}

final class ComposerBlockTests: XCTestCase {
    func testCodeEditorExcludesClosingFenceWithTrailingParagraphNewline() throws {
        let raw = "```swift\nlet greeting = 1\n```\n"
        let node = try XCTUnwrap(DiscourseMarkupCodec.parse(raw).first { $0.kind == .code })
        XCTAssertEqual(node.text, "let greeting = 1")
        XCTAssertEqual(ComposerBlockValue.editing(node)?.body, "let greeting = 1")
    }
    func testEscapedBlocksCanBeReopenedWithoutChangingContent() throws {
        var table = ComposerBlockValue(kind: .table); table.cells = [["A|B", "C\\D"], ["line\nnext", "text"]]
        let tableRaw = try table.markup(maximumOptions: 20)
        let tableNode = try XCTUnwrap(DiscourseMarkupCodec.parse(tableRaw).first { $0.kind == .table })
        XCTAssertEqual(try XCTUnwrap(ComposerBlockValue.editing(tableNode)).cells, table.cells)
        var details = ComposerBlockValue(kind: .details); details.heading = "A [summary] \"quoted\""; details.body = "literal [/details] content"
        let raw = try details.markup(maximumOptions: 20)
        let node = try XCTUnwrap(DiscourseMarkupCodec.parse(raw).first { $0.kind == .details })
        let reopened = try XCTUnwrap(ComposerBlockValue.editing(node))
        XCTAssertEqual(reopened.heading, details.heading)
        XCTAssertEqual(try reopened.markup(maximumOptions: 20), raw)
    }
    func testEveryAuthoredBlockHasReadableProjectionAndEditableForm() throws {
        for kind in [ComposerBlockKind.poll, .table, .details, .spoiler, .date, .code] {
            var value = ComposerBlockValue(kind: kind); value.heading = "Question"; value.body = "مرحبا 😀"; value.options = ["One", "Two"]
            let raw = try value.markup(maximumOptions: 20)
            let node = try XCTUnwrap(DiscourseMarkupCodec.parse(raw).first(where: { $0.kind == kind }), raw)
            XCTAssertNotNil(ComposerBlockValue.editing(node), raw)
            XCTAssertEqual(DiscourseMarkupCodec.parse(raw).map(\.raw).joined(), raw)
        }
    }
    func testPollLimitsDuplicatesAndCodeFenceEscaping() throws {
        var poll = ComposerBlockValue(kind: .poll); poll.heading = "Question"; poll.options = ["Same", "Same"]
        XCTAssertThrowsError(try poll.markup(maximumOptions: 20))
        poll.options = ["A", "B"]; poll.multiple = true; poll.minimum = 2; poll.maximum = 1
        XCTAssertThrowsError(try poll.markup(maximumOptions: 20))
        var code = ComposerBlockValue(kind: .code); code.body = "```\nlet x = 1"; code.language = "swift"
        XCTAssertTrue(try code.markup(maximumOptions: 20).hasPrefix("````swift"))
    }
    func testNativePreviewNeverIncludesExecutableContent() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let value = NativeOneboxParser.parse("<script><h1>Injected</h1></script><h3><a href='javascript:alert(1)'>Title</a></h3><p>Summary</p><iframe>Other</iframe>", url: url)
        XCTAssertEqual(value?.title, "Title"); XCTAssertEqual(value?.summary, "Summary"); XCTAssertEqual(value?.url, url)
    }
    func testUnknownLiveCapabilitiesHidePluginsAndPreviewCalls() {
        let capabilities = ComposerCapabilities()
        XCTAssertFalse(capabilities.blocks.contains(.poll)); XCTAssertFalse(capabilities.blocks.contains(.details)); XCTAssertFalse(capabilities.similarDiscussions); XCTAssertFalse(capabilities.onebox)
    }
}
