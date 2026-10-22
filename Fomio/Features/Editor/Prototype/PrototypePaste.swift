#if DEBUG
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Import only formatting the prose model can represent. Never parse plain text as Markdown.
@MainActor enum PrototypePaste {
    struct Content {
        var text: AttributedString
        var notice: String?
    }
    enum Failure: LocalizedError {
        case unsupported, tooLarge, unreadable
        var errorDescription: String? {
            switch self {
            case .unsupported: "This paste contains links, images, or formatting outside the prose prototype. Nothing was inserted. You can paste its plain text instead."
            case .tooLarge: "This paste is too large for the prototype. Nothing was inserted. Paste a smaller section."
            case .unreadable: "This clipboard content could not be read. Nothing was inserted."
            }
        }
    }
    static let supportedTypes: [UTType] = [.rtf, .rtfd, .html, .text, .image, .url]
    static let limit = 100_000

    static func plain(_ string: String) throws -> Content {
        guard string.count <= limit else { throw Failure.tooLarge }
        var text = AttributedString(string)
        var attributes = AttributeContainer()
        PrototypeRichDocument.apply([], to: &attributes)
        text.setAttributes(attributes)
        return Content(text: text)
    }
    static func rich(_ attributed: NSAttributedString) throws -> Content {
        guard attributed.length <= limit else { throw Failure.tooLarge }
        var text = AttributedString()
        var unsupported = false
        var simplified = false
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, range, _ in
            let allowed: Set<NSAttributedString.Key> = [.font, .strikethroughStyle, .strikethroughColor, .foregroundColor, .backgroundColor, .paragraphStyle]
            if attributes.keys.contains(where: { !allowed.contains($0) }) { unsupported = true }
            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
               paragraph.headIndent != 0 || paragraph.firstLineHeadIndent != 0 || !paragraph.textLists.isEmpty {
                unsupported = true
            }
            var marks: PrototypeMarks = []
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { marks.insert(.bold) }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { marks.insert(.italic) }
            }
            if let strike = attributes[.strikethroughStyle] as? NSNumber, strike.intValue != 0 { marks.insert(.strike) }
            var piece = AttributedString(attributed.attributedSubstring(from: range).string)
            var semantic = AttributeContainer(); PrototypeRichDocument.apply(marks, to: &semantic)
            piece.setAttributes(semantic); text += piece
            simplified = simplified || attributes[.font] != nil || attributes[.foregroundColor] != nil || attributes[.backgroundColor] != nil || attributes[.paragraphStyle] != nil
        }
        guard !unsupported, !attributed.string.contains("\u{FFFC}") else { throw Failure.unsupported }
        return Content(text: text, notice: simplified ? "Pasted bold, italic and strikethrough. Font, size, color and paragraph appearance use the editor’s style." : nil)
    }
    /// Native edit-menu paste reaches TextEditor's binding without an interceptor.
    /// Map imported font traits to our semantic marks; retain unsupported attributes
    /// so the codec can refuse export rather than silently flatten them.
    static func native(_ incoming: AttributedString, context: Font.Context) -> AttributedString {
        var result = incoming
        for run in incoming.runs {
            var marks = run[PrototypeMarksAttribute.self] ?? []
            if run[PrototypeMarksAttribute.self] == nil {
                if let font = run.font {
                    let resolved = font.resolve(in: context)
                    if resolved.isBold { marks.insert(.bold) }
                    if resolved.isItalic { marks.insert(.italic) }
                }
                if let intent = run.inlinePresentationIntent {
                    if intent.contains(.stronglyEmphasized) { marks.insert(.bold) }
                    if intent.contains(.emphasized) { marks.insert(.italic) }
                    if intent.contains(.strikethrough) { marks.insert(.strike) }
                }
                if run.strikethroughStyle != nil { marks.insert(.strike) }
            }
            var attributes = run.attributes
            PrototypeRichDocument.apply(marks, to: &attributes)
            result[run.range].setAttributes(attributes)
        }
        return result
    }
    static func read(_ providers: [NSItemProvider], plainText: Bool) async throws -> Content {
        guard !providers.isEmpty else { throw Failure.unreadable }
        var result = AttributedString()
        var notice: String?
        for (index, provider) in providers.enumerated() {
            try Task.checkCancellation()
            let content: Content
            if plainText {
                content = try plain(try await string(provider))
            } else if provider.hasItemConformingToTypeIdentifier(UTType.rtfd.identifier) {
                // RTFD may contain attachments; never silently prefer its text fallback.
                throw Failure.unsupported
            } else if provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier) {
                let data = try await data(provider, type: .rtf)
                guard data.count <= 1_000_000 else { throw Failure.tooLarge }
                let attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                content = try rich(attributed)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier)
                        || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                        || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                throw Failure.unsupported
            } else {
                content = try plain(try await string(provider))
            }
            if index > 0 { result += AttributedString("\n") }
            result += content.text
            guard result.characters.count <= limit else { throw Failure.tooLarge }
            if let message = content.notice { notice = message }
        }
        return Content(text: result, notice: notice)
    }
    private static func data(_ provider: NSItemProvider, type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? Failure.unreadable) }
            }
        }
    }
    private static func string(_ provider: NSItemProvider) async throws -> String {
        guard provider.canLoadObject(ofClass: NSString.self) else { throw Failure.unsupported }
        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: NSString.self) { object, error in
                if let string = object as? String { continuation.resume(returning: string) }
                else { continuation.resume(throwing: error ?? Failure.unreadable) }
            }
        }
    }
}
#endif
