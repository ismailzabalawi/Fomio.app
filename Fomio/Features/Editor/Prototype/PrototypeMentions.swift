#if DEBUG
import SwiftUI

/// The username a mention's characters refer to. Derived from the text on every change, never stored by the user.
enum PrototypeMentionAttribute: AttributedStringKey {
    typealias Value = String
    static let name = "fomio.prototype.mention"
}

/// Discourse turns `@name` into a mention wherever a text token matches, escaped or not: its mention pass
/// (`pretty-text/mentions.js` through `text-post-process.js`) runs after markdown-it's `text_join`.
/// So mentions are a property of the text. This mirrors that pass on the rich projection: one text token per
/// run of equal marks and link on a line, never inside links, with the same boundary rule.
enum PrototypeMentions {
    struct Found: Equatable {
        var range: Range<AttributedString.Index>
        var username: String
    }

    /// Mentions as Discourse would cook them, and whether the answer depends on the `unicode_usernames`
    /// site setting, which Fomio cannot read yet.
    static func find(in text: AttributedString) -> (mentions: [Found], ambiguous: Bool) {
        guard text.characters.contains("@") else { return ([], false) }
        var mentions: [Found] = []
        var ambiguous = false
        var segment: [(index: AttributedString.Index, scalar: Unicode.Scalar)] = []
        func flush() {
            defer { segment = [] }
            guard segment.contains(where: { $0.scalar == "@" }) else { return }
            let scalars = segment.map(\.scalar)
            let ascii = scan(scalars, unicode: false)
            if ascii != scan(scalars, unicode: true) { ambiguous = true }
            for range in ascii {
                let end = range.upperBound < segment.count ? segment[range.upperBound].index : text.unicodeScalars.index(after: segment[range.upperBound - 1].index)
                mentions.append(Found(range: segment[range.lowerBound].index..<end, username: String(String.UnicodeScalarView(scalars[(range.lowerBound + 1)..<range.upperBound]))))
            }
        }
        var key: (PrototypeMarks, URL?)?
        for run in text.runs {
            let runKey = (run[PrototypeMarksAttribute.self] ?? [], run[PrototypeLinkAttribute.self])
            if let key, key.0 != runKey.0 || key.1 != runKey.1 { flush() }
            key = runKey
            // Link labels are skipped by Discourse; markers are block syntax, not text.
            guard runKey.1 == nil, run[PrototypeBlockAttribute.self] == nil else { flush(); continue }
            var index = run.range.lowerBound
            while index < run.range.upperBound {
                let scalar = text.unicodeScalars[index]
                if scalar == "\n" { flush() } else { segment.append((index, scalar)) }
                index = text.unicodeScalars.index(after: index)
            }
        }
        flush()
        return (mentions, ambiguous)
    }

    /// Marks every mention and clears marks the text no longer supports. Returns whether any mention is ambiguous.
    @discardableResult static func style(_ text: inout AttributedString) -> Bool {
        let stale = text.runs.filter { $0[PrototypeMentionAttribute.self] != nil }.map { ($0.range, $0[PrototypeLinkAttribute.self] != nil) }
        let (mentions, ambiguous) = find(in: text)
        for (range, linked) in stale {
            text[range][PrototypeMentionAttribute.self] = nil
            if !linked { text[range].foregroundColor = nil }
        }
        for mention in mentions {
            text[mention.range][PrototypeMentionAttribute.self] = mention.username
            text[mention.range].foregroundColor = .accentColor
        }
        return ambiguous
    }

    /// `@` positions that start a mention in one text token, mirroring the matcher's global search:
    /// the greedy match is taken, and a match that fails its boundaries is skipped whole.
    static func scan(_ scalars: [Unicode.Scalar], unicode: Bool) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "@" else { index += 1; continue }
            let length = matchLength(scalars, from: index + 1, unicode: unicode)
            guard length > 0 else { index += 1; continue }
            let end = index + 1 + length
            if (index == 0 || isBoundary(scalars[index - 1])) && (end == scalars.count || isBoundary(scalars[end])) {
                result.append(index..<end)
            }
            index = end
        }
        return result
    }

    /// `\w[\w.-]{0,58}[^\W_]|\w`, or with `unicode_usernames` the same shape over letters, marks and digits.
    private static func matchLength(_ scalars: [Unicode.Scalar], from start: Int, unicode: Bool) -> Int {
        func alphanumeric(_ scalar: Unicode.Scalar) -> Bool {
            guard unicode else { return scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar)) }
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber: return true
            default: return scalar.properties.isAlphabetic
            }
        }
        func first(_ scalar: Unicode.Scalar) -> Bool { alphanumeric(scalar) || scalar == "_" }
        func middle(_ scalar: Unicode.Scalar) -> Bool { first(scalar) || scalar == "." || scalar == "-" }
        guard start < scalars.count, first(scalars[start]) else { return 0 }
        var run = 1
        while run < 60, start + run < scalars.count, middle(scalars[start + run]) { run += 1 }
        for length in stride(from: run, through: 2, by: -1) where alphanumeric(scalars[start + length - 1]) { return length }
        return 1
    }

    /// markdown-it `isWhiteSpace` or `isPunctChar` (Unicode P or S) of the neighbouring UTF-16 unit.
    /// Outside the Basic Multilingual Plane that unit is a surrogate, which is neither.
    private static func isBoundary(_ scalar: Unicode.Scalar) -> Bool {
        guard scalar.value <= 0xFFFF else { return false }
        if (0x09...0x0D).contains(scalar.value) || (0x2000...0x200A).contains(scalar.value)
            || [0x20, 0xA0, 0x1680, 0x202F, 0x205F, 0x3000].contains(scalar.value) { return true }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
             .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol: return true
        default: return false
        }
    }
}
#endif
