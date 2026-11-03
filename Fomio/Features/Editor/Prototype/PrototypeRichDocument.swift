#if DEBUG
import SwiftUI

/// A deliberately small, fail-closed prose codec. The production codec is independent.
struct PrototypeMarks: OptionSet, Hashable, Codable, Sendable {
    let rawValue: Int
    static let bold = Self(rawValue: 1)
    static let italic = Self(rawValue: 2)
    static let strike = Self(rawValue: 4)
}
/// A line's block. Only its visible marker ("• ", "2. ", "▎ ") carries the attribute.
enum PrototypeBlock: Hashable, Codable, Sendable {
    case bullet, ordered(Int), quote
    var marker: String {
        switch self {
        case .bullet: "• "
        case let .ordered(number): "\(number). "
        case .quote: "▎ "
        }
    }
    var isList: Bool { self != .quote }
    func isKind(of other: PrototypeBlock) -> Bool {
        switch (self, other) {
        case (.bullet, .bullet), (.ordered, .ordered), (.quote, .quote): true
        default: false
        }
    }
}
enum PrototypeMarksAttribute: AttributedStringKey {
    typealias Value = PrototypeMarks
    static let name = "fomio.prototype.marks"
}
enum PrototypeLinkAttribute: AttributedStringKey {
    typealias Value = URL
    static let name = "fomio.prototype.link"
}
enum PrototypeBlockAttribute: AttributedStringKey {
    typealias Value = PrototypeBlock
    static let name = "fomio.prototype.block"
}
struct PrototypeAttributeScope: AttributeScope {
    let marks: PrototypeMarksAttribute
    let link: PrototypeLinkAttribute
    let block: PrototypeBlockAttribute
    let mention: PrototypeMentionAttribute
    let swiftUI: AttributeScopes.SwiftUIAttributes
}

struct PrototypeRichDocument {
    private(set) var source: String
    private(set) var projection: AttributedString?
    private(set) var issue: String?
    private var lines: [(source: String, text: AttributedString)] = []

    init(source: String) {
        self.source = source
        do {
            guard !source.unicodeScalars.contains(where: { $0.value == 13 }) else { throw ParseError.unsupported }
            var previous = LineKind.blank
            var counter: (number: Int, delimiter: Character)?
            for line in source.components(separatedBy: "\n") {
                guard !line.isEmpty else { previous = .blank; lines.append((line, AttributedString())); continue }
                let (block, delimiter, content) = Self.block(of: line)
                // Structured syntax is never passed through a generic prose converter.
                try Self.guardProse(content, inBlock: block != nil)
                // Reject lines Markdown would read differently from the rich projection:
                // lazy continuation of a list or quote, and lists that cannot interrupt a paragraph.
                switch (previous, block) {
                case (.list, nil), (.quote, nil): throw ParseError.unsupported
                case let (.paragraph, .ordered(number)?) where number != 1: throw ParseError.unsupported
                case let (.paragraph, block?) where block.isList && content.isEmpty: throw ParseError.unsupported
                default: break
                }
                var display = block
                if case let .ordered(number)? = block, let delimiter {
                    if let counter { guard counter.delimiter == delimiter else { throw ParseError.unsupported } }
                    let next = counter.map { $0.number + 1 } ?? number
                    display = .ordered(next); counter = (next, delimiter)
                } else {
                    counter = nil
                }
                var parser = InlineParser(String(content))
                var text = (display.map(Self.marker) ?? AttributedString()) + (try parser.parse())
                // A mention whose meaning depends on `unicode_usernames` stays in source.
                guard !PrototypeMentions.style(&text) else { throw ParseError.unsupported }
                lines.append((line, text))
                previous = block.map { $0.isList ? .list : .quote } ?? .paragraph
            }
            projection = Self.join(lines.map(\.text))
        } catch {
            lines = []
            issue = "This sample contains syntax outside the prose prototype. Edit it in Markdown; its source is preserved."
        }
    }

    /// Only changed lines are serialized. Merely switching modes preserves every UTF-8 byte.
    @discardableResult mutating func commit(_ edited: AttributedString) -> Bool {
        guard projection != nil else { return true }
        guard !edited.runs.contains(where: { $0.adaptiveImageGlyph != nil }) else {
            issue = "This prototype supports text emoji, but cannot export Genmoji. Remove the image glyph before switching to Markdown."
            return false
        }
        guard !edited.runs.contains(where: { $0.link != nil || ($0.underlineStyle != nil && $0[PrototypeLinkAttribute.self] == nil) || $0.presentationIntent != nil || $0.inlinePresentationIntent?.contains(.code) == true }) else {
            issue = "This rich text contains links, underlining or structured formatting that the prose prototype cannot export. Your writing is still here. Undo the paste, then use Paste and its plain-text option if needed."
            return false
        }
        var normalizedText = Self.normalized(edited)
        guard !PrototypeMentions.style(&normalizedText) else {
            issue = "Fomio can’t tell yet whether this community allows usernames in other alphabets, so it can’t tell if this @ is a mention. Put a space between the username and other letters, or choose a username from the suggestions. Your rich text is still here."
            return false
        }
        let editedLines = Self.split(normalizedText)
        if let structure = Self.structureIssue(editedLines) { issue = structure; return false }
        let old = lines
        var prefix = 0
        while prefix < min(old.count, editedLines.count), old[prefix].text == editedLines[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(old.count, editedLines.count) - prefix,
              old[old.count - suffix - 1].text == editedLines[editedLines.count - suffix - 1] { suffix += 1 }
        var output: [String] = []
        // Unchanged lines in the edited middle keep their source, in order.
        var reusable = prefix
        for (index, line) in editedLines.enumerated() {
            if index < prefix { output.append(old[index].source) }
            else if index >= editedLines.count - suffix { output.append(old[old.count - (editedLines.count - index)].source) }
            else if let match = old[reusable..<(old.count - suffix)].firstIndex(where: { $0.text == line }) {
                output.append(old[match].source); reusable = match + 1
            } else { output.append(Self.serialize(line, after: output.last)) }
        }
        let candidate = Self(source: output.joined(separator: "\n"))
        guard let projected = candidate.projection, Self.split(projected) == editedLines else {
            issue = "This edit cannot be converted losslessly by the prose prototype. Your rich text is still here; remove unsupported indentation or whitespace before switching."
            return false
        }
        self = candidate
        return true
    }

    /// Derives appearance from the semantic attributes already in the container.
    static func apply(_ marks: PrototypeMarks, to attributes: inout AttributeContainer) {
        if attributes[PrototypeBlockAttribute.self] != nil {
            // Markers are structure, never formatted text.
            attributes[PrototypeMarksAttribute.self] = nil
            attributes[PrototypeLinkAttribute.self] = nil
            attributes.font = .body
            attributes.strikethroughStyle = nil
            attributes.underlineStyle = nil
            attributes.foregroundColor = .secondary
            return
        }
        attributes[PrototypeMarksAttribute.self] = marks.isEmpty ? nil : marks
        var font = Font.body
        if marks.contains(.bold) { font = font.bold() }
        if marks.contains(.italic) { font = font.italic() }
        attributes.font = font
        attributes.strikethroughStyle = marks.contains(.strike) ? .single : nil
        if attributes[PrototypeLinkAttribute.self] != nil {
            attributes.foregroundColor = .accentColor
            attributes.underlineStyle = .single
        }
    }

    static func normalized(_ text: AttributedString) -> AttributedString {
        var result = AttributedString()
        for run in text.runs {
            var piece = AttributedString(String(text[run.range].characters))
            var attributes = AttributeContainer()
            attributes[PrototypeLinkAttribute.self] = run[PrototypeLinkAttribute.self]
            attributes[PrototypeBlockAttribute.self] = run[PrototypeBlockAttribute.self]
            apply(run[PrototypeMarksAttribute.self] ?? [], to: &attributes)
            piece.setAttributes(attributes)
            result += piece
        }
        return result
    }

    /// Only http(s) and mail links, written so `[label](url)` cannot be misread.
    static func isLinkable(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "mailto" { return url.absoluteString.count > 7 }
        guard ["http", "https"].contains(scheme), url.host?.isEmpty == false else { return false }
        return !url.absoluteString.contains { $0.isWhitespace || "()<>\\".contains($0) }
    }

    // MARK: Blocks

    static func marker(_ block: PrototypeBlock) -> AttributedString {
        var marker = AttributedString(block.marker)
        var attributes = AttributeContainer()
        attributes[PrototypeBlockAttribute.self] = block
        apply([], to: &attributes)
        marker.setAttributes(attributes)
        return marker
    }
    /// The leading run of marker characters. `length` is nil when the user has broken the marker;
    /// `fragment` counts what is left of a partly deleted marker, which is removed rather than kept as text.
    static func markerInfo(_ line: AttributedString) -> (block: PrototypeBlock, length: Int?, fragment: Int)? {
        var block: PrototypeBlock?
        var leading = ""
        for run in line.runs {
            guard let value = run[PrototypeBlockAttribute.self], block == nil || block == value else { break }
            block = value
            leading += String(line[run.range].characters)
        }
        guard let block else { return nil }
        var length: Int?, fragment = 0
        switch block {
        case .bullet, .quote:
            if leading.hasPrefix(block.marker) { length = block.marker.count }
            else { fragment = block.marker.commonPrefix(with: leading).count }
        case .ordered:
            if let match = leading.firstMatch(of: #/^\d{1,9}\. /#) { length = leading[match.range].count }
            else if let match = leading.firstMatch(of: #/^\d{1,9}\.?/#) { fragment = leading[match.range].count }
        }
        return (block, length, fragment)
    }
    struct LineChange {
        var block: PrototypeBlock?
        /// Leading characters to replace; defaults to the line's current marker.
        var dropping: Int?
    }
    /// Repairs markers, applies line changes and renumbers ordered lists, mapping character offsets.
    static func normalizeBlocks(_ text: AttributedString, offsets: [Int] = [], changes: [Int: LineChange] = [:]) -> (text: AttributedString, offsets: [Int]) {
        // Unchanged lines and every newline are copied as they are, so ordinary typing is left alone.
        var output = AttributedString()
        var mapped = offsets
        var done = Array(repeating: false, count: offsets.count)
        var counter: Int?
        var oldStart = 0, newStart = 0
        var lineStart = text.startIndex
        for (index, line) in split(text).enumerated() {
            let lineEnd = text.characters.index(lineStart, offsetBy: line.characters.count)
            if index > 0 {
                let newline = text.characters.index(before: lineStart)
                var copy = AttributedString(text[newline..<lineStart])
                // A Return typed after a marker carries its attributes into the next line's typing.
                if copy.runs.first?[PrototypeBlockAttribute.self] != nil {
                    var attributes = AttributeContainer(); apply([], to: &attributes); copy.setAttributes(attributes)
                }
                output += copy
            }
            defer { if lineEnd < text.endIndex { lineStart = text.characters.index(after: lineEnd) } }
            let info = markerInfo(line)
            var block: PrototypeBlock?
            var dropping = 0
            if let change = changes[index] {
                block = change.block
                dropping = change.dropping ?? info.map { $0.length ?? $0.fragment } ?? 0
            } else if let info {
                // A partly deleted marker removes the block, like deleting a bullet.
                if let length = info.length { block = info.block; dropping = length } else { dropping = info.fragment }
            }
            var body = AttributedString(line[line.characters.index(line.startIndex, offsetBy: dropping)...])
            var stray = false
            for run in body.runs where run[PrototypeBlockAttribute.self] != nil {
                // Typing after a marker inherits its attributes; that text is content.
                body[run.range][PrototypeBlockAttribute.self] = nil
                body[run.range].foregroundColor = nil
                stray = true
            }
            if case let .ordered(number)? = block {
                let next = counter.map { $0 + 1 } ?? number
                block = .ordered(next); counter = next
            } else if block != nil || !body.characters.isEmpty {
                counter = nil
            }
            let prefix = block.map(marker) ?? AttributedString()
            let count = line.characters.count, prefixCount = prefix.characters.count
            for (slot, offset) in offsets.enumerated() where !done[slot] && offset <= oldStart + count {
                let column = max(0, offset - oldStart)
                mapped[slot] = newStart + prefixCount + max(0, column - dropping)
                done[slot] = true
            }
            let current = info.flatMap { $0.length == nil ? nil : $0.block }
            let unchanged = !stray && changes[index] == nil && current == block && dropping == (block == nil ? 0 : info?.length ?? -1)
            let rebuilt = unchanged ? line : prefix + body
            output += rebuilt
            oldStart += count + 1; newStart += rebuilt.characters.count + 1
        }
        return (output, mapped)
    }

    static func split(_ text: AttributedString) -> [AttributedString] {
        var result: [AttributedString] = [], start = text.startIndex
        for index in text.characters.indices where text.characters[index] == "\n" {
            result.append(AttributedString(text[start..<index]))
            start = text.characters.index(after: index)
        }
        result.append(AttributedString(text[start..<text.endIndex]))
        return result
    }
    private static func join(_ lines: [AttributedString]) -> AttributedString {
        var result = AttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 {
                var newline = AttributedString("\n")
                var attributes = AttributeContainer(); apply([], to: &attributes); newline.setAttributes(attributes)
                result += newline
            }
            result += line
        }
        return result
    }
    private static func structureIssue(_ lines: [AttributedString]) -> String? {
        var previous: PrototypeBlock??
        for line in lines {
            let block = markerInfo(line).flatMap { $0.length == nil ? nil : $0.block }
            if block == nil, !line.characters.isEmpty, case .some(.some) = previous {
                return "Leave an empty line between a list or quote and the text after it. Your rich text is still here."
            }
            previous = line.characters.isEmpty ? nil : .some(block)
        }
        return nil
    }
    private static func serialize(_ line: AttributedString, after previous: String?) -> String {
        guard let info = markerInfo(line), let length = info.length else { return serializeInline(line) }
        let body = serializeInline(AttributedString(line[line.characters.index(line.startIndex, offsetBy: length)...]))
        switch info.block {
        case .bullet:
            // Match the neighbouring item's marker so an insertion does not split the list.
            let bullet = previous.flatMap { $0.firstMatch(of: #/^([-*+]) /#).map { String($0.1) } } ?? "-"
            return "\(bullet) " + body
        case let .ordered(number):
            let delimiter = previous.flatMap { $0.firstMatch(of: #/^\d{1,9}([.)]) /#).map { String($0.1) } } ?? "."
            return "\(number)\(delimiter) " + body
        case .quote:
            return body.isEmpty ? ">" : "> " + body
        }
    }
    private static func serializeInline(_ text: AttributedString) -> String {
        // BBCode avoids ambiguous adjacent Markdown emphasis delimiters and handles
        // leading/trailing whitespace. It is Discourse source, never HTML or RTF.
        var output = ""
        var link: URL?
        var tags: [String] = []
        var marks: PrototypeMarks?
        for run in text.runs {
            // Mention styling splits runs; tags follow only the marks and link.
            let runMarks = run[PrototypeMarksAttribute.self] ?? []
            if runMarks != marks || run[PrototypeLinkAttribute.self] != link {
                for tag in tags.reversed() { output += "[/\(tag)]" }
                if run[PrototypeLinkAttribute.self] != link {
                    if let link { output += "](\(link.absoluteString))" }
                    link = run[PrototypeLinkAttribute.self]
                    if link != nil { output += "[" }
                }
                marks = runMarks
                tags = [(PrototypeMarks.bold, "b"), (.italic, "i"), (.strike, "s")].filter { runMarks.contains($0.0) }.map(\.1)
                for tag in tags { output += "[\(tag)]" }
            }
            // A mention reads the same escaped or not, so keep it readable. `_` stays escaped so it cannot open emphasis.
            let mention = run[PrototypeMentionAttribute.self] != nil
            for character in text[run.range].characters {
                if character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
                   scalar.isASCII, CharacterSet.punctuationCharacters.union(.symbols).contains(scalar),
                   !mention || scalar == "_" {
                    output += "\\"
                }
                output.append(character)
            }
        }
        for tag in tags.reversed() { output += "[/\(tag)]" }
        if let link { output += "](\(link.absoluteString))" }
        return output
    }

    private enum LineKind { case blank, paragraph, list, quote }
    private static func block(of line: String) -> (PrototypeBlock?, Character?, Substring) {
        if let match = line.firstMatch(of: #/^([-*+]) /#) { return (.bullet, match.1.first, line[match.range.upperBound...]) }
        if let match = line.firstMatch(of: #/^(\d{1,9})([.)]) /#), let number = Int(match.1) {
            return (.ordered(number), match.2.first, line[match.range.upperBound...])
        }
        if line.hasPrefix(">") {
            let content = line.dropFirst()
            return (.quote, nil, content.hasPrefix(" ") ? content.dropFirst() : content)
        }
        return (nil, nil, line[...])
    }
    private static func guardProse(_ content: Substring, inBlock: Bool) throws {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix(">"),
              !trimmed.hasPrefix("- "), !trimmed.hasPrefix("+ "), !trimmed.hasPrefix("* "),
              String(content).range(of: #"^\s*(?:\d+[.)](?:\s|$)|[-*_]{3,}\s*$|-+\s*$|=+\s*$|[+*]\s*$|\t| {4})"#, options: .regularExpression) == nil,
              !content.hasSuffix("  "),
              !(inBlock && content.first?.isWhitespace == true) else { throw ParseError.unsupported }
    }

    private enum ParseError: Error { case unsupported }
    private struct InlineParser {
        let characters: [Character]
        var position = 0
        init(_ source: String) { characters = Array(source) }
        private func has(_ token: String) -> Bool { characters[position...].starts(with: Array(token)) }
        mutating func parse(until closing: String? = nil, marks: PrototypeMarks = [], depth: Int = 0, inLink: Bool = false) throws -> AttributedString {
            guard depth < 16 else { throw ParseError.unsupported }
            var output = AttributedString()
            func append(_ value: String) {
                var piece = AttributedString(value)
                var attributes = AttributeContainer(); PrototypeRichDocument.apply(marks, to: &attributes)
                piece.setAttributes(attributes); output += piece
            }
            while position < characters.count {
                if let closing, has(closing) { position += closing.count; return output }
                if characters[position] == "\\" {
                    position += 1
                    guard position < characters.count, characters[position].unicodeScalars.count == 1,
                          let scalar = characters[position].unicodeScalars.first, scalar.isASCII,
                          CharacterSet.punctuationCharacters.union(.symbols).contains(scalar) else { throw ParseError.unsupported }
                    append(String(characters[position])); position += 1; continue
                }
                if characters[position] == "&" {
                    let remainder = String(characters[position...])
                    guard remainder.range(of: #"^&(?:#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]+);"#, options: .regularExpression) == nil else { throw ParseError.unsupported }
                }
                // Preserve emoji shortcodes and autolinks as source until their semantics are
                // part of this prototype's document model. Mentions are derived from the text afterwards.
                if characters[position] == ":" {
                    let remainder = String(characters[position...])
                    guard !remainder.hasPrefix("://"),
                          remainder.range(of: #"^:[a-zA-Z0-9_+\-]+:"#, options: .regularExpression) == nil else { throw ParseError.unsupported }
                }
                let tokens: [(String, String, PrototypeMarks)] = [
                    ("[b]", "[/b]", .bold), ("[i]", "[/i]", .italic), ("[s]", "[/s]", .strike),
                    ("***", "***", [.bold, .italic]), ("___", "___", [.bold, .italic]),
                    ("**", "**", .bold), ("__", "__", .bold), ("~~", "~~", .strike),
                    ("*", "*", .italic), ("_", "_", .italic)
                ]
                if let token = tokens.first(where: { has($0.0) }) {
                    let start = position; position += token.0.count
                    if !token.0.hasPrefix("[") {
                        guard position < characters.count, !characters[position].isWhitespace,
                              !(token.0.contains("_") && start > 0 && characters[start - 1].isLetter) else { throw ParseError.unsupported }
                    }
                    let nested = try parse(until: token.1, marks: marks.union(token.2), depth: depth + 1, inLink: inLink)
                    guard !nested.characters.isEmpty else { throw ParseError.unsupported }
                    if !token.0.hasPrefix("[") {
                        guard let last = nested.characters.last, !last.isWhitespace,
                              !(token.0.contains("_") && position < characters.count && characters[position].isLetter) else { throw ParseError.unsupported }
                    }
                    output += nested; continue
                }
                // An inline link `[label](url)`. Images, reference links and nested links stay in source.
                if characters[position] == "[", !inLink, position == 0 || characters[position - 1] != "!" {
                    position += 1
                    var label = try parse(until: "]", marks: marks, depth: depth + 1, inLink: true)
                    guard !label.characters.isEmpty, position < characters.count, characters[position] == "(" else { throw ParseError.unsupported }
                    position += 1
                    var address = ""
                    while position < characters.count, characters[position] != ")" {
                        guard !characters[position].isWhitespace, !"(<>\\".contains(characters[position]) else { throw ParseError.unsupported }
                        address.append(characters[position]); position += 1
                    }
                    guard position < characters.count, let url = URL(string: address), PrototypeRichDocument.isLinkable(url) else { throw ParseError.unsupported }
                    position += 1
                    for run in label.runs {
                        var attributes = run.attributes
                        attributes[PrototypeLinkAttribute.self] = url
                        PrototypeRichDocument.apply(run[PrototypeMarksAttribute.self] ?? [], to: &attributes)
                        label[run.range].setAttributes(attributes)
                    }
                    output += label; continue
                }
                // Code, HTML, plugins and unfamiliar syntax stay in source mode.
                guard !"[]`<>|~".contains(characters[position]) else { throw ParseError.unsupported }
                append(String(characters[position])); position += 1
            }
            guard closing == nil else { throw ParseError.unsupported }
            return output
        }
    }
}
#endif
