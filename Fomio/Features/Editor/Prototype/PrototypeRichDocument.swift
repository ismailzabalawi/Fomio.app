#if DEBUG
import SwiftUI

/// A deliberately small, fail-closed prose codec. The production codec is independent.
struct PrototypeMarks: OptionSet, Hashable, Codable, Sendable {
    let rawValue: Int
    static let bold = Self(rawValue: 1)
    static let italic = Self(rawValue: 2)
    static let strike = Self(rawValue: 4)
}
enum PrototypeMarksAttribute: AttributedStringKey {
    typealias Value = PrototypeMarks
    static let name = "fomio.prototype.marks"
}
struct PrototypeAttributeScope: AttributeScope {
    let marks: PrototypeMarksAttribute
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
            for line in source.components(separatedBy: "\n") {
                // Structured syntax is never passed through a generic prose converter.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix(">"),
                      !trimmed.hasPrefix("- "), !trimmed.hasPrefix("+ "),
                      !trimmed.hasPrefix("* "),
                      line.range(of: #"^\s*(?:\d+[.)]\s|[-*_]{3,}\s*$|=+\s*$|\t| {4})"#, options: .regularExpression) == nil,
                      !line.hasSuffix("  ") else { throw ParseError.unsupported }
                var parser = InlineParser(line)
                let text = try parser.parse()
                lines.append((line, text))
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
        guard !edited.runs.contains(where: { $0.link != nil || $0.underlineStyle != nil || $0.presentationIntent != nil || $0.inlinePresentationIntent?.contains(.code) == true }) else {
            issue = "This rich text contains links, underlining or structured formatting that the prose prototype cannot export. Your writing is still here. Undo the paste, then use Paste and its plain-text option if needed."
            return false
        }
        let editedLines = Self.split(Self.normalized(edited))
        let old = lines
        var prefix = 0
        while prefix < min(old.count, editedLines.count), old[prefix].text == editedLines[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(old.count, editedLines.count) - prefix,
              old[old.count - suffix - 1].text == editedLines[editedLines.count - suffix - 1] { suffix += 1 }
        let output = editedLines.enumerated().map { index, line in
            if index < prefix { return old[index].source }
            if index >= editedLines.count - suffix { return old[old.count - (editedLines.count - index)].source }
            // Preserve unchanged lines in the edited middle when their position still matches.
            if old.count == editedLines.count, old[index].text == line { return old[index].source }
            return Self.serialize(line)
        }
        let candidate = Self(source: output.joined(separator: "\n"))
        guard let projected = candidate.projection, Self.split(projected) == editedLines else {
            issue = "This edit cannot be converted losslessly by the prose prototype. Your rich text is still here; remove unsupported indentation or whitespace before switching."
            return false
        }
        self = candidate
        return true
    }

    static func apply(_ marks: PrototypeMarks, to attributes: inout AttributeContainer) {
        attributes[PrototypeMarksAttribute.self] = marks.isEmpty ? nil : marks
        var font = Font.body
        if marks.contains(.bold) { font = font.bold() }
        if marks.contains(.italic) { font = font.italic() }
        attributes.font = font
        attributes.strikethroughStyle = marks.contains(.strike) ? .single : nil
    }

    static func normalized(_ text: AttributedString) -> AttributedString {
        var result = AttributedString()
        for run in text.runs {
            var piece = AttributedString(String(text[run.range].characters))
            var attributes = AttributeContainer()
            apply(run[PrototypeMarksAttribute.self] ?? [], to: &attributes)
            piece.setAttributes(attributes)
            result += piece
        }
        return result
    }

    private static func split(_ text: AttributedString) -> [AttributedString] {
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
    private static func serialize(_ text: AttributedString) -> String {
        // BBCode avoids ambiguous adjacent Markdown emphasis delimiters and handles
        // leading/trailing whitespace. It is Discourse source, never HTML or RTF.
        var output = ""
        for run in text.runs {
            let marks = run[PrototypeMarksAttribute.self] ?? []
            let tags = [(PrototypeMarks.bold, "b"), (.italic, "i"), (.strike, "s")].filter { marks.contains($0.0) }.map(\.1)
            for tag in tags { output += "[\(tag)]" }
            for character in text[run.range].characters {
                if character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
                   scalar.isASCII, CharacterSet.punctuationCharacters.union(.symbols).contains(scalar) {
                    output += "\\"
                }
                output.append(character)
            }
            for tag in tags.reversed() { output += "[/\(tag)]" }
        }
        return output
    }

    private enum ParseError: Error { case unsupported }
    private struct InlineParser {
        let characters: [Character]
        var position = 0
        init(_ source: String) { characters = Array(source) }
        private func has(_ token: String) -> Bool { characters[position...].starts(with: Array(token)) }
        mutating func parse(until closing: String? = nil, marks: PrototypeMarks = [], depth: Int = 0) throws -> AttributedString {
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
                // Preserve mentions, emoji shortcodes and autolinks as source until
                // their semantics are part of this prototype's document model.
                if characters[position] == "@" { throw ParseError.unsupported }
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
                    let nested = try parse(until: token.1, marks: marks.union(token.2), depth: depth + 1)
                    guard !nested.characters.isEmpty else { throw ParseError.unsupported }
                    if !token.0.hasPrefix("[") {
                        guard let last = nested.characters.last, !last.isWhitespace,
                              !(token.0.contains("_") && position < characters.count && characters[position].isLetter) else { throw ParseError.unsupported }
                    }
                    output += nested; continue
                }
                // Links, code, HTML, plugins and unfamiliar syntax stay in source mode.
                guard !"[]`<>|~".contains(characters[position]) else { throw ParseError.unsupported }
                append(String(characters[position])); position += 1
            }
            guard closing == nil else { throw ParseError.unsupported }
            return output
        }
    }
}
#endif
