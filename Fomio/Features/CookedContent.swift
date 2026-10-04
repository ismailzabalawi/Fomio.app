import SwiftUI
import Foundation

struct HTMLContent {
    enum Block: Equatable { case text(String), quote(String), code(String), image(String, String), unsupported }
    static func plainText(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")]
        for (entity, value) in entities { result = result.replacingOccurrences(of: entity, with: value) }
        if let regex = try? NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let digits = Range(match.range(at: 1), in: result), let whole = Range(match.range, in: result) else { continue }
                let text = String(result[digits]); let number = text.hasPrefix("x") ? UInt32(text.dropFirst(), radix: 16) : UInt32(text)
                if let number, let scalar = UnicodeScalar(number) { result.replaceSubrange(whole, with: String(scalar)) }
            }
        }
        return result
    }
    static func markdown(_ html: String) -> String {
        var text = html
        let patterns = [("<a[^>]*href=\"([^\"]+)\"[^>]*>([\\s\\S]*?)</a>", "[$2]($1)"), ("<(?:strong|b)[^>]*>([\\s\\S]*?)</(?:strong|b)>", "**$1**"), ("<(?:em|i)[^>]*>([\\s\\S]*?)</(?:em|i)>", "*$1*"), ("<code[^>]*>([\\s\\S]*?)</code>", "`$1`"), ("<br\\s*/?>|</p>|</div>|</li>", "\n\n")]
        for (pattern, replacement) in patterns { text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression) }
        return plainText(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func attribute(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b" + name + "\\s*=\\s*[\"']([^\"']*)[\"']", options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)), let range = Range(match.range(at: 1), in: tag) else { return nil }
        return plainText(String(tag[range]))
    }
    static func blocks(_ html: String) -> [Block] {
        guard let regex = try? NSRegularExpression(pattern: "<pre\\b[^>]*>[\\s\\S]*?</pre>|<blockquote\\b[^>]*>[\\s\\S]*?</blockquote>|<aside\\b[^>]*>[\\s\\S]*?</aside>|<img\\b[^>]*>|<(?:table|iframe|video|audio|script|style)\\b[^>]*>[\\s\\S]*?</(?:table|iframe|video|audio|script|style)>", options: .caseInsensitive) else { return [.unsupported] }
        var blocks: [Block] = [], cursor = html.startIndex
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let preceding = markdown(String(html[cursor..<range.lowerBound])); if !preceding.isEmpty { blocks.append(.text(preceding)) }
            let segment = String(html[range]), lower = segment.lowercased()
            if lower.hasPrefix("<pre") { blocks.append(.code(plainText(segment))) }
            else if lower.hasPrefix("<blockquote") || lower.hasPrefix("<aside") { blocks.append(.quote(markdown(segment))) }
            else if lower.hasPrefix("<img"), let source = attribute("src", in: segment) { blocks.append(.image(source, attribute("alt", in: segment) ?? "Community photo")) }
            else if !lower.hasPrefix("<script") && !lower.hasPrefix("<style") { blocks.append(.unsupported) }
            cursor = range.upperBound
        }
        let rest = markdown(String(html[cursor...])); if !rest.isEmpty { blocks.append(.text(rest)) }
        return blocks
    }
}
struct CookedContent: View {
    @Environment(AppState.self) private var app
    let html: String
    let topic: TopicID
    let number: PostNumber
    var body: some View {
        let blocks = HTMLContent.blocks(html)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case let .text(text): Text(.init(text)).font(.body).textSelection(.enabled)
                case let .quote(text): Text(.init(text)).font(.body).textSelection(.enabled).padding(12).background(Color.fomioHighlight, in: .rect(cornerRadius: 8)).accessibilityLabel("Quote: " + HTMLContent.plainText(text))
                case let .code(text): ScrollView(.horizontal) { Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(12) }.background(Color.fomioHighlight, in: .rect(cornerRadius: 8))
                case let .image(source, alt):
                    if let base = app.configuration?.baseURL, let url = URL(string: source, relativeTo: base)?.absoluteURL, url.scheme == "https" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image): image.resizable().scaledToFit().clipShape(.rect(cornerRadius: 10)).accessibilityLabel(alt)
                            case .failure: Label("Photo unavailable in app", systemImage: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                            default: ProgressView("Loading photo")
                            }
                        }
                    }
                case .unsupported: Label("Additional content is available in the community", systemImage: "arrow.up.right.square").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let url = app.configuration?.topicURL(topic, number: number) { Link("View original post", destination: url).font(.caption).frame(minHeight: 44) }
        }.environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "https" || url.scheme == "http" else { return .discarded }
            if let base = app.configuration?.baseURL, let route = LinkRouter.route(url, baseURL: base) { app.navigate(route); return .handled }
            return .systemAction
        })
    }
}
