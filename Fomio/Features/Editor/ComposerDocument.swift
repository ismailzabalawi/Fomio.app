import Foundation

/// Raw Discourse markup is authoritative. Parsing is a projection, never a rewrite.
struct ComposerDocument: Equatable, Sendable {
    var raw: String
    var nodes: [MarkupNode] { DiscourseMarkupCodec.parse(raw) }
}
struct EditorSelection: Equatable, Sendable {
    var location = 0
    var length = 0
    var range: NSRange { NSRange(location: location, length: length) }
    init(_ range: NSRange = NSRange(location: 0, length: 0)) { location = range.location; length = range.length }
}
enum EditorCommand {
    case adopt(String, EditorSelection), select(EditorSelection), bold, italic, style(ComposerTextStyle), link(String, String), insert(String), replace(NSRange, String), markdown, undo, redo
}
/// The line-level type of a text block. The composer bar's type chip changes it in place; raw keeps the Markdown prefix.
enum ComposerTextStyle: Hashable, Sendable {
    case paragraph, heading(Int), quote, list
    /// Types offered by Turn into and the inserter. Other heading levels are still recognised.
    static let offered: [ComposerTextStyle] = [.paragraph, .heading(2), .heading(3), .quote, .list]
    var title: String {
        switch self {
        case .paragraph: String(localized: "Paragraph")
        case let .heading(level): String(localized: "Heading \(level)")
        case .quote: String(localized: "Quote")
        case .list: String(localized: "Bulleted list")
        }
    }
    var symbol: String {
        switch self {
        case .paragraph: "text.alignleft"
        case .heading: "textformat.size"
        case .quote: "text.quote"
        case .list: "list.bullet"
        }
    }
    var prefix: String {
        switch self {
        case .paragraph: ""
        case let .heading(level): String(repeating: "#", count: min(6, max(1, level))) + " "
        case .quote: "> "
        case .list: "- "
        }
    }
}
enum ComposerBlockKind: String, CaseIterable, Codable, Sendable {
    case poll, table, details, spoiler, date, code, quote, photo, opaque
    var title: String {
        switch self {
        case .poll: "Poll"
        case .table: "Table"
        case .details: "Hidden details"
        case .spoiler: "Spoiler"
        case .date: "Date and time"
        case .code: "Code"
        case .quote: "Quote"
        case .photo: "Photo"
        case .opaque: "Unsupported markup"
        }
    }
}
struct MarkupNode: Equatable, Identifiable, Sendable {
    var range: NSRange
    var raw: String
    var text: String
    var kind: ComposerBlockKind?
    var bold = false
    var italic = false
    var link: String?
    var contentRange: NSRange?
    var sourceOffsets: [Int]?
    var id: Int { range.location }
}
struct DiscourseMarkupCodec {
    /// Deliberately bounded grammar. Anything outside it stays byte-for-byte in raw.
    static func parse(_ raw: String) -> [MarkupNode] {
        let source = raw as NSString
        var pattern = #"(?m)^(`{3,})[^\n]*\n[\s\S]*?^\1[^\n]*(?:\n|$)|\[(poll|details|spoiler|quote)(?:[ =][^\]\n]*)?\][\s\S]*?\[/\2\]|\[date[ =][^\]\n]+\]|!\[(?:\\.|[^\\\]\n])*\]\([^\)\n]+\)|(?m)^\|[^\n]+\|\n\|[ :|\-]+\|(?:\n\|[^\n]*\|)+|\[([a-zA-Z][\w-]*)(?:[ =][^\]\n]*)?\][\s\S]*?\[/\3\]|\*\*\*[^*\n]+\*\*\*|\*\*[^*\n]+\*\*|(?<!\*)\*(?!\s)[^*\n]+\*(?!\*)|\[(?:\\.|[^\\\]\n])+\]\([^\)\n]+\)"#
        pattern += #"|(?m)^~{3,}[^\n]*\n[\s\S]*?^~{3,}[ \t]*(?:\n|$)|(?m)^(?:#{1,6}[ \t]+|[0-9]+[.)][ \t]+|[-*][ \t]+\[[ xX]\][ \t]+)[^\n]*(?:\n|$)|(?m)^[ \t]{0,3}(?:[-*_][ \t]*){3,}(?:\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [MarkupNode(range: NSRange(location: 0, length: source.length), raw: raw, text: raw)] }
        var nodes: [MarkupNode] = [], cursor = 0
        for match in regex.matches(in: raw, range: NSRange(location: 0, length: source.length)) {
            if match.range.location > cursor {
                let range = NSRange(location: cursor, length: match.range.location - cursor)
                nodes.append(MarkupNode(range: range, raw: source.substring(with: range), text: source.substring(with: range)))
            }
            let value = source.substring(with: match.range)
            var node = MarkupNode(range: match.range, raw: value, text: value)
            if value.hasPrefix("```") {
                node.kind = .code
                var lines = value.components(separatedBy: "\n"); if lines.last == "" { lines.removeLast() }
                node.text = lines.dropFirst().dropLast().joined(separator: "\n")
            }
            else if value.hasPrefix("![") { node.kind = .photo; if let close = value.range(of: "](", options: .backwards) { node.text = unescapeInline(String(value[value.index(value.startIndex, offsetBy: 2)..<close.lowerBound])) } }
            else if value.hasPrefix("|") { node.kind = .table; node.text = value }
            // ATX headings stay editable text; the marker remains visible so display and raw offsets coincide.
            else if value.hasPrefix("#") { node.text = value }
            else if value.hasPrefix("[date ") || value.hasPrefix("[date=") { node.kind = .date; node.text = value }
            else if value.hasPrefix("***") { node.bold = true; node.italic = true; node.text = String(value.dropFirst(3).dropLast(3)); node.contentRange = NSRange(location: match.range.location + 3, length: (node.text as NSString).length) }
            else if value.hasPrefix("**") { node.bold = true; node.text = String(value.dropFirst(2).dropLast(2)); node.contentRange = NSRange(location: match.range.location + 2, length: (node.text as NSString).length) }
            else if value.hasPrefix("*") { node.italic = true; node.text = String(value.dropFirst().dropLast()); node.contentRange = NSRange(location: match.range.location + 1, length: (node.text as NSString).length) }
            else if let close = value.range(of: "](", options: .backwards), value.hasSuffix(")") {
                let label = String(value[value.index(after: value.startIndex)..<close.lowerBound])
                let projection = inlineProjection(label)
                node.text = projection.text
                node.sourceOffsets = projection.offsets.map { match.range.location + 1 + $0 }
                node.link = String(value[close.upperBound..<value.index(before: value.endIndex)])
                node.contentRange = NSRange(location: match.range.location + 1, length: (label as NSString).length)
            } else {
                let tag = String(value.dropFirst().prefix { $0.isLetter }).lowercased()
                node.kind = ComposerBlockKind(rawValue: tag) ?? .opaque
                if let start = value.firstIndex(of: "]"), let end = value.range(of: "[/", options: .backwards), start < end.lowerBound {
                    node.text = String(value[value.index(after: start)..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            nodes.append(node); cursor = NSMaxRange(match.range)
        }
        if cursor < source.length { let range = NSRange(location: cursor, length: source.length - cursor); nodes.append(MarkupNode(range: range, raw: source.substring(with: range), text: source.substring(with: range))) }
        return nodes
    }
    static func replace(_ raw: String, range: NSRange, with replacement: String) -> String {
        let source = raw as NSString
        guard range.location >= 0, range.length >= 0, NSMaxRange(range) <= source.length, Range(range, in: raw) != nil else { return raw }
        let units = Array(raw.utf16)
        for boundary in [range.location, NSMaxRange(range)] where boundary > 0 && boundary < units.count {
            if (0xD800...0xDBFF).contains(units[boundary - 1]) && (0xDC00...0xDFFF).contains(units[boundary]) { return raw }
        }
        return source.replacingCharacters(in: range, with: replacement)
    }
    static func escapeInline(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\\", with: "\\\\")
        for character in ["*", "[", "]", "`"] { result = result.replacingOccurrences(of: character, with: "\\" + character) }
        return result
    }
    static func inlineProjection(_ text: String) -> (text: String, offsets: [Int]) {
        let source = Array(text.utf16)
        var units: [UInt16] = [], offsets: [Int] = [], index = 0
        while index < source.count {
            let start = index
            if source[index] == 92, index + 1 < source.count {
                let next = source[index + 1]
                if (33...47).contains(next) || (58...64).contains(next) || (91...96).contains(next) || (123...126).contains(next) { index += 1 }
            }
            offsets.append(start); units.append(source[index]); index += 1
        }
        offsets.append(source.count)
        return (String(decoding: units, as: UTF16.self), offsets)
    }
    static func unescapeInline(_ text: String) -> String { inlineProjection(text).text }
    static func link(label: String, url: String) -> String {
        let destination = (URL(string: url)?.absoluteString ?? url).replacingOccurrences(of: "(", with: "%28").replacingOccurrences(of: ")", with: "%29")
        return "[\(escapeInline(label.replacingOccurrences(of: "\n", with: " ")))](\(destination))"
    }
    static func image(description: String, url: String) -> String { "![\(escapeInline(description.replacingOccurrences(of: "\n", with: " ")))](\(url))" }
    private static let stylePrefix = try! NSRegularExpression(pattern: #"^(?:(#{1,6})[ \t]+|>[ \t]?|[-*][ \t]+)"#)
    static func style(ofLine line: String) -> (style: ComposerTextStyle, prefix: Int) {
        let text = line as NSString
        guard let match = stylePrefix.firstMatch(in: line, range: NSRange(location: 0, length: text.length)) else { return (.paragraph, 0) }
        if match.range(at: 1).location != NSNotFound { return (.heading(match.range(at: 1).length), match.range.length) }
        return (text.hasPrefix(">") ? .quote : .list, match.range.length)
    }
    /// Lines touched by a range, or nil when they belong to a structured block (code, table, poll…) that text styles must not rewrite.
    static func textLines(_ raw: String, range: NSRange) -> NSRange? {
        let source = raw as NSString
        let clamped = NSRange(location: min(max(0, range.location), source.length), length: max(0, min(range.length, source.length - min(max(0, range.location), source.length))))
        let lines = source.paragraphRange(for: clamped)
        let structured = parse(raw).contains { node in
            node.kind != nil && NSIntersectionRange(node.range, lines).length > 0
        }
        return structured ? nil : lines
    }
    /// The style of the block holding the caret, or nil inside a structured block.
    static func textStyle(_ raw: String, at range: NSRange) -> ComposerTextStyle? {
        guard let lines = textLines(raw, range: NSRange(location: range.location, length: 0)) else { return nil }
        return style(ofLine: (raw as NSString).substring(with: lines)).style
    }
    /// Heading projections keep inline markup literal; do not offer commands that imply rich formatting there.
    static func supportsInlineFormatting(_ raw: String, range: NSRange) -> Bool {
        guard let lines = textLines(raw, range: range) else { return false }
        return !(raw as NSString).substring(with: lines).components(separatedBy: .newlines).contains {
            if case .heading = style(ofLine: $0).style { return true }
            return false
        }
    }
    /// Rewrites the line prefixes of every line the range touches, keeping each line's text and the selection relative to it.
    static func restyle(_ raw: String, range: NSRange, to style: ComposerTextStyle) -> (raw: String, selection: NSRange)? {
        guard let lines = textLines(raw, range: range) else { return nil }
        let source = raw as NSString
        let block = source.substring(with: lines)
        let trailing = block.hasSuffix("\n") ? "\n" : ""
        var output = "", shifts: [(start: Int, oldPrefix: Int, newPrefix: Int, length: Int)] = []
        var cursor = lines.location
        for line in String(block.dropLast(trailing.count)).components(separatedBy: "\n") {
            let length = (line as NSString).length
            let old = Self.style(ofLine: line).prefix
            let content = (line as NSString).substring(from: old)
            shifts.append((cursor, old, (style.prefix as NSString).length, length))
            output += (shifts.count == 1 ? "" : "\n") + style.prefix + content
            cursor += length + 1
        }
        output += trailing
        func map(_ position: Int) -> Int {
            var delta = 0
            for shift in shifts {
                if position <= shift.start + shift.length {
                    let offset = max(0, position - shift.start - shift.oldPrefix)
                    return shift.start + delta + shift.newPrefix + offset
                }
                delta += shift.newPrefix - shift.oldPrefix
            }
            return position + delta
        }
        let start = map(range.location), end = map(NSMaxRange(range))
        return (source.replacingCharacters(in: lines, with: output), NSRange(location: start, length: max(0, end - start)))
    }
    /// Where + inserts a new block: an empty line is reused, otherwise the block goes after the line holding the caret.
    static func blockInsertion(_ raw: String, at range: NSRange) -> (location: Int, leading: String) {
        let source = raw as NSString
        let location = min(max(0, NSMaxRange(range)), source.length)
        if let node = parse(raw).first(where: { $0.kind != nil && location > $0.range.location && location < NSMaxRange($0.range) }) {
            let end = NSMaxRange(node.range)
            return (end, end > 0 && source.character(at: end - 1) != 10 ? "\n" : "")
        }
        let line = source.paragraphRange(for: NSRange(location: location, length: 0))
        if source.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return (line.location, "") }
        let end = NSMaxRange(line)
        return (end, source.character(at: end - 1) == 10 ? "" : "\n")
    }
    static func standaloneURLs(_ raw: String) -> [URL] {
        raw.components(separatedBy: .newlines).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            guard let url = URL(string: text), ["http", "https"].contains(url.scheme ?? ""), url.host != nil, !text.contains(" ") else { return nil }
            return url
        }
    }
}
