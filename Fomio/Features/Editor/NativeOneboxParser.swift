import Foundation

/// Only text inside the preview's heading and paragraphs is allowed into native UI.
/// URLs remain the original source URL; remote scripts, styles and embeds are never rendered.
struct NativeOneboxParser {
    static func parse(_ html: String, url: URL) -> OneboxMetadata? {
        let safe = html.replacingOccurrences(of: "<(script|style|iframe|object)\\b[^>]*>[\\s\\S]*?</\\1>", with: "", options: [.regularExpression, .caseInsensitive])
        func contents(_ pattern: String) -> [String] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
            return regex.matches(in: safe, range: NSRange(safe.startIndex..., in: safe)).compactMap { match in
                guard let range = Range(match.range(at: 1), in: safe) else { return nil }
                return HTMLContent.plainText(String(safe[range])).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard let title = contents("<h[1-6]\\b[^>]*>([\\s\\S]*?)</h[1-6]>").first, !title.isEmpty else { return nil }
        return OneboxMetadata(url: url, title: String(title.prefix(300)), summary: String(contents("<p\\b[^>]*>([\\s\\S]*?)</p>").joined(separator: " ").prefix(1000)))
    }
}
