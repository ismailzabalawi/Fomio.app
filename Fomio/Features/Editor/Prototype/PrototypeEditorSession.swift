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

    mutating func editRich(_ text: AttributedString, now: Date = .now) {
        guard text != value.text else { return }
        let before = value
        value.text = text
        record(before, name: "Typing", typing: true, now: now)
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
        revision += 1; breakTyping()
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
