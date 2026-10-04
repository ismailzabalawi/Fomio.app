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
    case adopt(String, EditorSelection), select(EditorSelection), bold, italic, quote, list, link(String, String), insert(String), replace(NSRange, String), markdown, undo, redo
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
    static func standaloneURLs(_ raw: String) -> [URL] {
        raw.components(separatedBy: .newlines).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            guard let url = URL(string: text), ["http", "https"].contains(url.scheme ?? ""), url.host != nil, !text.contains(" ") else { return nil }
            return url
        }
    }
}
