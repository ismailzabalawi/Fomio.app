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
        value.text = text
        if deferShaping { if shapeBase == nil { shapeBase = before.text } } else { shapeBlocks(after: before.text) }
        record(before, name: "Typing", typing: true, now: now)
    }
    /// Applies list continuation, shortcuts and marker repair to the edit recorded by `editRich`.
    mutating func shapePendingEdit() {
        guard let base = shapeBase else { return }
        shapeBase = nil
        let text = value.text
        shapeBlocks(after: base)
        if value.text != text, !past.isEmpty { past[past.count - 1].after = value }
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
        // While the editor is still adopting a marker it can send its own text back, with the next key typed
        // where the marker was. Typing never replaces a marker (Backspace removes it), so put the marker back.
        let removedRange = Self.index(start, in: old)..<Self.index(oldCharacters.count - end, in: old)
        if !inserted.isEmpty, !removedRange.isEmpty, old[removedRange].runs.allSatisfy({ $0[PrototypeBlockAttribute.self] != nil }) {
            let typed = value.text[Self.index(start, in: value.text)..<Self.index(newCharacters.count - end, in: value.text)]
            var restored = AttributedString(old[..<removedRange.upperBound])
            restored += AttributedString(typed)
            restored += AttributedString(old[removedRange.upperBound...])
            value.text = restored
            value.selection = AttributedTextSelection(insertionPoint: Self.index(oldCharacters.count - end + inserted.count, in: value.text))
            return shapeBlocks(after: old)
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
        revision += 1; breakTyping(); shapeBase = nil
    }
    private mutating func record(_ before: Snapshot, name: String, typing: Bool = false, now: Date = .now) {
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
