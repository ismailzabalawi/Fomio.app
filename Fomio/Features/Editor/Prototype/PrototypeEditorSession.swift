#if DEBUG
import SwiftUI

/// History belongs to the document, not either of the disposable native editors.
struct PrototypeEditorSession {
    struct Snapshot {
        var document: PrototypeRichDocument
        var text: AttributedString
        var selection = AttributedTextSelection()
        var sourceSelection: TextSelection?
        var source: String
        var markdown: Bool

        init(source: String) {
            document = PrototypeRichDocument(source: source)
            text = document.projection ?? AttributedString()
            self.source = source
            markdown = document.projection == nil
        }
    }
    struct Entry {
        var before: Snapshot
        var after: Snapshot
        var name: String
    }
    struct PasteTarget: Equatable {
        var revision: Int
        var richSelection: AttributedTextSelection.Indices
        var sourceSelection: TextSelection.Indices?
        var markdown: Bool
    }
    var pasteTarget: PasteTarget {
        PasteTarget(revision: revision, richSelection: value.selection.indices(in: value.text),
                    sourceSelection: value.sourceSelection?.indices, markdown: value.markdown)
    }
    @discardableResult mutating func paste(_ text: AttributedString, at target: PasteTarget) -> Bool {
        guard target == pasteTarget else { return false }
        paste(text)
        return true
    }
    private(set) var value: Snapshot
    private var past: [Entry] = []
    private var future: [Entry] = []
    private var typingMode: Bool?
    private var shapeBase: AttributedString?
    private var editorText: AttributedString?
    private var lastEdit: Date?
    private(set) var revision = 0
    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    var undoName: String { past.last?.name ?? "" }
    var redoName: String { future.last?.name ?? "" }

    init(source: String) { value = Snapshot(source: source) }

    mutating func select(_ selection: AttributedTextSelection) { value.selection = selection }
    mutating func selectSource(_ selection: TextSelection?) { value.sourceSelection = selection }
    mutating func breakTyping() { typingMode = nil; lastEdit = nil }

    /// The native editor ignores text it is handed back from its own update, so it passes
    /// `deferShaping` and calls `shapePendingEdit()` once that update has finished.
    mutating func editRich(_ text: AttributedString, now: Date = .now, deferShaping: Bool = false) {
        guard text != value.text else { return }
        let before = value
        value.text = deferShaping ? replayingStaleEdit(text) : text
        if deferShaping { if shapeBase == nil { shapeBase = before.text } } else { shapeBlocks(after: before.text) }
        record(before, name: "Typing", typing: true, now: now)
    }
    /// The native editor adopts shaped text late, and until then keeps sending edits of its own older text.
    /// When an edit only adds to what the editor last sent, but would undo shaping since, apply just the added keys.
    private mutating func replayingStaleEdit(_ text: AttributedString) -> AttributedString {
        defer { editorText = text }
        guard let editorText, !editorText.characters.elementsEqual(value.text.characters) else { return text }
        func difference(from old: AttributedString) -> (removed: Int, inserted: Range<Int>) {
            let old = Array(old.characters), new = Array(text.characters)
            var start = 0
            while start < min(old.count, new.count), old[start] == new[start] { start += 1 }
            var end = 0
            while end < min(old.count, new.count) - start, old[old.count - end - 1] == new[new.count - end - 1] { end += 1 }
            return (old.count - end - start, start..<(new.count - end))
        }
        let edit = difference(from: editorText)
        // A stale edit swaps shaped text for keys. Removing alone is a real Backspace.
        let current = difference(from: value.text)
        guard edit.removed == 0, !edit.inserted.isEmpty, current.removed > 0, !current.inserted.isEmpty else { return text }
        // Keys land the same distance from the end: shaping only changes text before the caret.
        let count = text.characters.count
        let at = Self.index(value.text.characters.count - (count - edit.inserted.upperBound), in: value.text)
        var replayed = value.text
        replayed.insert(AttributedString(text[Self.index(edit.inserted.lowerBound, in: text)..<Self.index(edit.inserted.upperBound, in: text)]), at: at)
        let caret = value.text.characters.distance(from: value.text.startIndex, to: at) + edit.inserted.count
        value.selection = AttributedTextSelection(insertionPoint: Self.index(caret, in: replayed))
        return replayed
    }
    /// Applies list continuation, shortcuts and marker repair to the edit recorded by `editRich`.
    mutating func shapePendingEdit() {
        guard let base = shapeBase else { return }
        shapeBase = nil
        let text = value.text
        shapeBlocks(after: base)
        styleMentions()
        if value.text != text, !past.isEmpty { past[past.count - 1].after = value }
    }
    /// Mentions are derived from the text, so every change restyles them.
    private mutating func styleMentions() {
        guard !value.markdown else { return }
        var text = value.text
        PrototypeMentions.style(&text)
        if text != value.text { value.text = text }
    }
    /// Continues lists and quotes on Return, turns typed `- `, `1. ` and `> ` into blocks,
    /// and repairs markers the edit broke. Moves the caret only when it rewrites the text.
    private mutating func shapeBlocks(after old: AttributedString) {
        let oldCharacters = Array(old.characters), newCharacters = Array(value.text.characters)
        let hasBlocks = value.text.runs.contains { $0[PrototypeBlockAttribute.self] != nil }
        var start = 0
        while start < min(oldCharacters.count, newCharacters.count), oldCharacters[start] == newCharacters[start] { start += 1 }
        var end = 0
        while end < min(oldCharacters.count, newCharacters.count) - start,
              oldCharacters[oldCharacters.count - end - 1] == newCharacters[newCharacters.count - end - 1] { end += 1 }
        let inserted = Array(newCharacters[start..<(newCharacters.count - end)])
        // While the editor is still adopting a marker it can keep sending its own text back, with the keys typed since
        // where the marker was. Typing never replaces a marker (Backspace removes it), so put the marker back.
        let removedRange = Self.index(start, in: old)..<Self.index(oldCharacters.count - end, in: old)
        if !inserted.isEmpty, let first = old[removedRange].runs.first, first[PrototypeBlockAttribute.self] != nil {
            let markerEnd = old[removedRange].runs.first { $0[PrototypeBlockAttribute.self] == nil }?.range.lowerBound ?? removedRange.upperBound
            let markerLength = old.characters.distance(from: removedRange.lowerBound, to: markerEnd)
            // Text typed after the marker in an earlier pass comes back too, at the start of what was inserted.
            let kept = oldCharacters[(start + markerLength)..<(oldCharacters.count - end)]
            if inserted.starts(with: kept), kept.isEmpty || inserted.count > kept.count {
                let typed = value.text[Self.index(start, in: value.text)..<Self.index(newCharacters.count - end, in: value.text)]
                var restored = AttributedString(old[..<markerEnd])
                restored += AttributedString(typed)
                restored += AttributedString(old[removedRange.upperBound...])
                value.text = restored
                value.selection = AttributedTextSelection(insertionPoint: Self.index(start + markerLength + inserted.count, in: value.text))
                return shapeBlocks(after: old)
            }
        }
        // Composed input such as an emoji modifier replaces the character before it, so allow removals without a line break.
        let removedBreak = oldCharacters[start..<(oldCharacters.count - end)].contains("\n")
        // Fast typing can reach a deferred shape with more than the Return or space that triggers it.
        let newlines = inserted.indices.filter { inserted[$0] == "\n" }
        let returned = !removedBreak && newlines.count == 1
        let spaced = !removedBreak && inserted.contains(" ") && !inserted.contains("\n")
        guard hasBlocks || spaced else { return }
        let caret = start + inserted.count
        let lines = PrototypeRichDocument.split(value.text)
        // The line holding the Return, or else the edit's start, and where it begins.
        let anchor = returned ? start + newlines[0] : start
        var line = 0, lineStart = 0
        for (index, text) in lines.enumerated() {
            let count = text.characters.count
            if anchor <= lineStart + count { line = index; break }
            lineStart += count + 1
        }
        var changes: [Int: PrototypeRichDocument.LineChange] = [:]
        if returned, let info = PrototypeRichDocument.markerInfo(lines[line]), let length = info.length {
            if lines[line].characters.count == length {
                // Return on an empty item leaves the list, keeping a blank line as Markdown needs.
                changes[line] = .init(block: nil)
            } else {
                changes[line + 1] = .init(block: info.block, dropping: 0)
            }
        } else if spaced, PrototypeRichDocument.markerInfo(lines[line]) == nil {
            // A shortcut counts only when this edit typed its space.
            let text = String(lines[line].characters)
            let typed = text.firstMatch(of: #/^(?:[-*+>]|\d{1,9}\.) /#).map { String(text[$0.range]) } ?? ""
            let shortcut: PrototypeBlock? = switch typed {
            case "": nil
            case "- ", "* ", "+ ": .bullet
            case "> ": .quote
            default: .ordered(Int(typed.dropLast(2)) ?? 1)
            }
            if let shortcut, lineStart + typed.count - 1 >= start { changes[line] = .init(block: shortcut, dropping: typed.count) }
        }
        guard hasBlocks || !changes.isEmpty else { return }
        let shaped = PrototypeRichDocument.normalizeBlocks(value.text, offsets: [caret], changes: changes)
        guard shaped.text != value.text else { return }
        let moved = !shaped.text.characters.elementsEqual(value.text.characters)
        value.text = shaped.text
        // Only a change to the characters needs a new caret; attribute repairs keep the editor's own.
        if moved { value.selection = AttributedTextSelection(insertionPoint: Self.index(shaped.offsets[0], in: value.text)) }
    }
    mutating func editSource(_ source: String, now: Date = .now) {
        guard Array(source.utf8) != Array(value.source.utf8) else { return }
        let before = value
        value.source = source
        record(before, name: "Typing", typing: true, now: now)
    }
    mutating func format(_ mark: PrototypeMarks) {
        let before = value
        let attributes = Array(value.selection.attributes(in: value.text))
        let remove = !attributes.isEmpty && attributes.allSatisfy { ($0[PrototypeMarksAttribute.self] ?? []).contains(mark) }
        value.text.transformAttributes(in: &value.selection) { attributes in
            var marks = attributes[PrototypeMarksAttribute.self] ?? []
            if remove { marks.remove(mark) } else { marks.insert(mark) }
            PrototypeRichDocument.apply(marks, to: &attributes)
        }
        guard value.text != before.text || value.selection != before.selection else { return }
        record(before, name: "Formatting")
    }
    /// The lines the selection touches, and their blocks.
    var selectedBlocks: [PrototypeBlock?] {
        let (lines, range) = selectedLines
        return range.map { PrototypeRichDocument.markerInfo(lines[$0]).flatMap { $0.length == nil ? nil : $0.block } }
    }
    private var selectedLines: ([AttributedString], ClosedRange<Int>) {
        let lines = PrototypeRichDocument.split(value.text)
        let (lower, upper) = Self.offsets(value.selection, in: value.text)
        var first = 0, last = 0, lineStart = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = lineStart + line.characters.count
            if lower >= lineStart && lower <= lineEnd { first = index }
            if upper >= lineStart && upper <= lineEnd { last = index; break }
            lineStart = lineEnd + 1
        }
        return (lines, first...max(first, last))
    }
    /// Turns the selected lines into `kind`, or back into paragraphs when they all are already.
    mutating func toggleBlock(_ kind: PrototypeBlock) {
        let before = value
        let (_, range) = selectedLines
        let remove = selectedBlocks.allSatisfy { $0?.isKind(of: kind) == true }
        var changes: [Int: PrototypeRichDocument.LineChange] = [:]
        for line in range { changes[line] = .init(block: remove ? nil : kind) }
        let (lower, upper) = Self.offsets(value.selection, in: value.text)
        let shaped = PrototypeRichDocument.normalizeBlocks(value.text, offsets: [lower, upper], changes: changes)
        guard shaped.text != value.text else { return }
        value.text = shaped.text
        let start = Self.index(shaped.offsets[0], in: value.text), end = Self.index(shaped.offsets[1], in: value.text)
        value.selection = start == end ? AttributedTextSelection(insertionPoint: start) : AttributedTextSelection(range: start..<end)
        record(before, name: kind == .quote ? "Quote" : "List")
    }
    /// The link on every selected character, if they share one.
    var selectedLink: URL? {
        let links = Set(value.selection.attributes(in: value.text).map { $0[PrototypeLinkAttribute.self] })
        return links.count == 1 ? links.first ?? nil : nil
    }
    /// Links the selection, or inserts `label` at the caret. A nil URL removes links from the selection.
    mutating func link(_ url: URL?, label: String? = nil) {
        let before = value
        if let url, let label, !label.isEmpty {
            var piece = AttributedString(label)
            var attributes = AttributeContainer()
            attributes[PrototypeLinkAttribute.self] = url
            PrototypeRichDocument.apply([], to: &attributes)
            piece.setAttributes(attributes)
            value.text.replaceSelection(&value.selection, with: piece)
        } else {
            value.text.transformAttributes(in: &value.selection) { attributes in
                guard attributes[PrototypeBlockAttribute.self] == nil else { return }
                attributes[PrototypeLinkAttribute.self] = url
                if url == nil { attributes.underlineStyle = nil; attributes.foregroundColor = nil }
                PrototypeRichDocument.apply(attributes[PrototypeMarksAttribute.self] ?? [], to: &attributes)
            }
        }
        guard value.text != before.text else { return }
        record(before, name: url == nil ? "Remove Link" : "Link")
    }
    /// The `@` word ending at the caret, for mention suggestions: its character offsets and the text after `@`.
    var mentionQuery: (range: Range<Int>, term: String)? {
        guard !value.markdown, case let .insertionPoint(caret) = value.selection.indices(in: value.text) else { return nil }
        let characters = value.text.characters
        var index = caret, term = ""
        while index > characters.startIndex, term.count <= 60 {
            let previous = characters.index(before: index)
            let character = characters[previous]
            if character == "@" {
                if previous > characters.startIndex {
                    let before = characters[characters.index(before: previous)]
                    guard before.isWhitespace || before.isPunctuation || before.isSymbol else { return nil }
                }
                let run = value.text.runs[previous]
                guard run[PrototypeLinkAttribute.self] == nil, run[PrototypeBlockAttribute.self] == nil else { return nil }
                let start = characters.distance(from: characters.startIndex, to: previous)
                return (start..<(start + 1 + term.count), term)
            }
            guard character.isLetter || character.isNumber || "._-".contains(character) else { return nil }
            term = String(character) + term
            index = previous
        }
        return nil
    }
    /// Replaces the `@` word at the caret with a mention of `username`, then a space unless punctuation follows.
    mutating func mention(_ username: String) {
        guard let query = mentionQuery else { return }
        let before = value
        let lower = Self.index(query.range.lowerBound, in: value.text), upper = Self.index(query.range.upperBound, in: value.text)
        let next = upper < value.text.endIndex ? value.text.characters[upper] : nil
        let inserted = "@" + username + (next.map { $0.isWhitespace || $0.isPunctuation } == true ? "" : " ")
        var piece = AttributedString(inserted)
        var attributes = AttributeContainer()
        PrototypeRichDocument.apply(value.text.runs[lower][PrototypeMarksAttribute.self] ?? [], to: &attributes)
        piece.setAttributes(attributes)
        value.text.replaceSubrange(lower..<upper, with: piece)
        value.selection = AttributedTextSelection(insertionPoint: Self.index(query.range.lowerBound + inserted.count, in: value.text))
        breakTyping()
        record(before, name: "Mention")
    }
    static func offsets(_ selection: AttributedTextSelection, in text: AttributedString) -> (Int, Int) {
        func offset(_ index: AttributedString.Index) -> Int { text.characters.distance(from: text.startIndex, to: index) }
        switch selection.indices(in: text) {
        case let .insertionPoint(index): return (offset(index), offset(index))
        case let .ranges(ranges):
            guard let first = ranges.ranges.first, let last = ranges.ranges.last else { return (0, 0) }
            return (offset(first.lowerBound), offset(last.upperBound))
        }
    }
    static func index(_ offset: Int, in text: AttributedString) -> AttributedString.Index {
        text.characters.index(text.startIndex, offsetBy: min(max(0, offset), text.characters.count))
    }
    /// Exports rich text to Discourse source without leaving rich mode or adding history.
    @discardableResult mutating func syncSource() -> Bool {
        guard !value.markdown, value.document.commit(value.text) else { return false }
        value.source = value.document.source
        return true
    }
    @discardableResult mutating func changeMode(_ markdown: Bool) -> Bool {
        guard markdown != value.markdown else { return true }
        let before = value
        if markdown {
            guard value.document.commit(value.text) else { breakTyping(); return false }
            value.source = value.document.source
            value.sourceSelection = nil
        } else {
            value.document = PrototypeRichDocument(source: value.source)
            value.text = value.document.projection ?? AttributedString()
            value.selection = AttributedTextSelection()
        }
        value.markdown = markdown
        record(before, name: "Mode Change")
        return true
    }
    mutating func load(_ source: String) {
        let before = value
        value = Snapshot(source: source)
        record(before, name: "Load Sample")
    }
    mutating func paste(_ text: AttributedString) {
        let before = value
        if value.markdown {
            let inserted = String(text.characters)
            let ranges: [Range<String.Index>]
            switch value.sourceSelection?.indices {
            case let .selection(range): ranges = [range]
            case let .multiSelection(set): ranges = Array(set.ranges)
            case nil: ranges = []
            @unknown default: return
            }
            let offsets = ranges.map { range in
                value.source.distance(from: value.source.startIndex, to: range.lowerBound)..<value.source.distance(from: value.source.startIndex, to: range.upperBound)
            }
            if let first = offsets.first {
                // Replace a natural/discontiguous selection once, at its first range.
                // Recreate indices after each mutation; never reuse indices into old storage.
                for (index, offset) in offsets.enumerated().reversed() {
                    let lower = value.source.index(value.source.startIndex, offsetBy: offset.lowerBound)
                    let upper = value.source.index(value.source.startIndex, offsetBy: offset.upperBound)
                    value.source.replaceSubrange(lower..<upper, with: index == 0 ? inserted : "")
                }
                let caret = value.source.index(value.source.startIndex, offsetBy: first.lowerBound + inserted.count)
                value.sourceSelection = TextSelection(insertionPoint: caret)
            } else {
                value.source += inserted
                value.sourceSelection = TextSelection(insertionPoint: value.source.endIndex)
            }
        } else {
            value.text.replaceSelection(&value.selection, with: text)
        }
        record(before, name: "Paste")
    }
    mutating func undo() {
        guard let entry = past.popLast() else { return }
        // Capture the latest native selection as well as the text in the redo state.
        var saved = entry; saved.after = value
        future.append(saved)
        value = entry.before
        restored()
    }
    mutating func redo() {
        guard let entry = future.popLast() else { return }
        past.append(entry)
        value = entry.after
        restored()
    }
    private mutating func restored() {
        revision += 1; breakTyping(); shapeBase = nil; editorText = nil
    }
    private mutating func record(_ before: Snapshot, name: String, typing: Bool = false, now: Date = .now) {
        // A deferred edit is restyled with its shaping, after the native editor's update.
        if shapeBase == nil { styleMentions() }
        if typing, typingMode == value.markdown, let lastEdit, now.timeIntervalSince(lastEdit) < 1,
           !past.isEmpty, future.isEmpty {
            past[past.count - 1].after = value
        } else {
            past.append(Entry(before: before, after: value, name: name))
            // Keep the memory-only experiment bounded. Retain the latest 100 actions.
            if past.count > 100 { past.removeFirst() }
        }
        future.removeAll()
        typingMode = typing ? value.markdown : nil
        lastEdit = typing ? now : nil
        revision += 1
    }
}
#endif
