import SwiftUI
import UIKit
import ImageIO
import Observation

@MainActor @Observable final class EditorController {
    var selection = EditorSelection()
    var focused = false
    var markdown = false
    var boldTyping = false
    var italicTyping = false
    var canUndo = false
    var canRedo = false
    /// Type of the block holding the caret; nil inside a structured block or the title.
    var textStyle: ComposerTextStyle? = .paragraph
    @ObservationIgnored weak var coordinator: NativeComposerEditor.Coordinator?
    func send(_ command: EditorCommand) { coordinator?.command(command) }
    func focus() { focused = true; coordinator?.view?.becomeFirstResponder() }
    func blur() { focused = false; coordinator?.view?.resignFirstResponder() }
}

/// Native text input and selection remain inside TextKit. Only committed edits reach raw.
struct NativeComposerEditor: UIViewRepresentable {
    @Binding var raw: String
    var controller: EditorController
    var isTitle = false
    var locked = false
    var preview = false
    var allowChecklists = true
    var attachmentData: (MarkupNode) -> Data? = { _ in nil }
    var attachmentCaption: (MarkupNode) -> String? = { _ in nil }
    var onBlock: (MarkupNode) -> Void = { _ in }
    var onRemove: (MarkupNode) -> Void = { _ in }
    var onNext: () -> Void = {}
    var onFocus: () -> Void = {}
    var identifier = "composer-body"
    var label = "Reply text"
    var placeholder = "Write your reply"
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ComposerTextView {
        let view = ComposerTextView(usingTextLayoutManager: true)
        view.backgroundColor = .clear; view.isScrollEnabled = false
        view.allowsEditingTextAttributes = false // Formatting is routed through raw-preserving EditorCommand.
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.keyboardDismissMode = .interactive
        view.returnKeyType = isTitle ? .next : .default
        view.delegate = context.coordinator
        view.toggleTask = { [weak coordinator = context.coordinator] offset in coordinator?.toggleTask(at: offset) }
        view.deleteAtDocumentStart = { [weak coordinator = context.coordinator] in coordinator?.removeInitialBlockPrefix() ?? false }
        // The formatting bar follows the local keyboard geometry. A separate
        // UIKit accessory would add an extra row between the bar and the keys.
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = String(localized: String.LocalizationValue(label))
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.view = view
        view.documentUndoManager = context.coordinator.history
        context.coordinator.render(raw, selection: controller.selection.range)
        return view
    }
    func updateUIView(_ view: ComposerTextView, context: Context) {
        context.coordinator.parent = self; controller.coordinator = context.coordinator
        if view.isEditable != !locked { view.isEditable = !locked }
        view.allowsTaskEditing = !locked && !preview && allowChecklists
        if view.markedTextRange == nil, context.coordinator.lastRaw != raw || context.coordinator.lastMarkdown != controller.markdown {
            context.coordinator.render(raw, selection: context.coordinator.remapExternal(controller.selection.range, to: raw))
        } else if view.markedTextRange == nil { context.coordinator.refreshAppearance() }
        let wantsFocus = !locked && controller.focused
        if view.isFirstResponder != wantsFocus {
            // UIKit responder changes can query hosting-controller preferences. Defer
            // them until SwiftUI finishes its trait/layout transaction (including rotation).
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, let coordinator, view.window != nil else { return }
                let wantsFocus = !coordinator.parent.locked && coordinator.controller.focused
                if wantsFocus && !view.isFirstResponder { view.becomeFirstResponder() }
                else if !wantsFocus && view.isFirstResponder { view.resignFirstResponder() }
            }
        }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ComposerTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        assert(uiView.textLayoutManager != nil, "The composer requires TextKit 2")
        var resized = false
        uiView.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: uiView.textStorage.length)) { value, _, _ in
            guard let attachment = value as? ComposerTextAttachment, abs(attachment.bounds.width - width) > 1 else { return }
            attachment.bounds.size.width = width
            attachment.card?.frame.size.width = width
            resized = true
        }
        if resized, let manager = uiView.textLayoutManager, let content = manager.textContentManager { manager.invalidateLayout(for: content.documentRange) }
        let measured = uiView.attributedText.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: width, height: max(isTitle ? 44 : 200, ceil(measured.height) + uiView.textContainerInset.top + uiView.textContainerInset.bottom))
    }
    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        struct Span { var display: NSRange; var node: MarkupNode }
        var parent: NativeComposerEditor
        weak var view: ComposerTextView?
        let history = UndoManager()
        var spans: [Span] = []
        var lastRaw = ""
        var lastMarkdown = false
        var lastDisplay = ""
        var rendering = false
        var nativeUndoSuspended = false
        init(_ parent: NativeComposerEditor) { self.parent = parent; history.groupsByEvent = false }
        var controller: EditorController { parent.controller }
        func font(bold: Bool = false, italic: Bool = false) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: parent.isTitle ? .title3 : .body)
            var traits: UIFontDescriptor.SymbolicTraits = parent.isTitle || bold ? [.traitBold] : []
            if italic { traits.insert(.traitItalic) }
            return base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        func headingFont(_ level: Int) -> UIFont {
            let style: UIFont.TextStyle = level <= 1 ? .title2 : level == 2 ? .title3 : .headline
            let base = UIFont.preferredFont(forTextStyle: style)
            return base.fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        func reportStyle() {
            let range = controller.selection.range
            controller.textStyle = parent.isTitle ? nil : DiscourseMarkupCodec.textStyle(lastRaw, at: range)
            // A range reports the marks of the styled run that holds it; a caret keeps its typing attributes.
            guard range.length > 0, !controller.markdown, !parent.isTitle else { return }
            let display = displayRange(range)
            let selected = spans.flatMap { span -> [VisualMark] in
                guard span.node.kind == nil else { return [] }
                let overlap = NSIntersectionRange(display, span.display)
                guard overlap.length > 0 else { return [] }
                let all = marks(for: span.node)
                return Array(all[(overlap.location - span.display.location)..<(NSMaxRange(overlap) - span.display.location)])
            }
            controller.boldTyping = !selected.isEmpty && selected.allSatisfy(\.bold)
            controller.italicTyping = !selected.isEmpty && selected.allSatisfy(\.italic)
        }
        func render(_ raw: String, selection: NSRange) {
            guard let view, view.markedTextRange == nil else { return }
            rendering = true
            let suspend = history.isUndoRegistrationEnabled
            if suspend { history.disableUndoRegistration() }
            defer { if suspend { history.enableUndoRegistration() }; rendering = false }
            var retainedAttachments: [ComposerTextAttachment] = []
            view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, _, _ in
                if let attachment = value as? ComposerTextAttachment { retainedAttachments.append(attachment) }
            }
            lastRaw = raw; lastMarkdown = controller.markdown; spans = []
            let result = NSMutableAttributedString(string: "")
            let paragraph = NSMutableParagraphStyle(); paragraph.baseWritingDirection = .natural; paragraph.alignment = .natural; paragraph.paragraphSpacing = 6
            let base: [NSAttributedString.Key: Any] = [.font: font(), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
            if controller.markdown || parent.isTitle {
                var attributes = base
                if controller.markdown { attributes[.font] = UIFont.monospacedSystemFont(ofSize: font().pointSize, weight: .regular) }
                result.append(NSAttributedString(string: raw, attributes: attributes))
            }
            else {
                for node in DiscourseMarkupCodec.parse(raw) {
                    let start = result.length
                    if node.kind != nil {
                        let attachment: ComposerTextAttachment
                        if let index = retainedAttachments.firstIndex(where: { $0.node.raw == node.raw && $0.preview == parent.preview }) {
                            attachment = retainedAttachments.remove(at: index); attachment.node = node
                            attachment.caption = parent.attachmentCaption(node)
                        } else {
                            attachment = ComposerTextAttachment(node: node, data: parent.attachmentData(node), caption: parent.attachmentCaption(node), width: max(180, view.bounds.width), preview: parent.preview)
                        }
                        attachment.edit = { [weak self, weak attachment] in if let attachment { self?.parent.onBlock(attachment.node) } }
                        attachment.remove = { [weak self, weak attachment] in if let attachment { self?.parent.onRemove(attachment.node) } }
                        result.append(NSAttributedString(attachment: attachment))
                    } else {
                        var attributes = base; attributes[.font] = font(bold: node.bold, italic: node.italic)
                        if let link = node.link, let url = URL(string: link), ["http", "https"].contains(url.scheme ?? "") { attributes[.link] = url }
                        if node.inlineCode { attributes[.font] = UIFont.monospacedSystemFont(ofSize: font().pointSize, weight: .regular); attributes[.backgroundColor] = UIColor.secondarySystemBackground }
                        if node.strike { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                        result.append(NSAttributedString(string: node.text, attributes: attributes))
                        for mark in node.inlineMarks {
                            let range = NSRange(location: start + mark.range.location, length: mark.range.length)
                            result.addAttribute(.font, value: mark.code ? UIFont.monospacedSystemFont(ofSize: font().pointSize, weight: .regular) : font(bold: mark.bold, italic: mark.italic), range: range)
                            if let link = mark.link, let url = URL(string: link), ["http", "https"].contains(url.scheme ?? "") { result.addAttribute(.link, value: url, range: range) }
                            if mark.strike { result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
                        }
                    }
                    spans.append(Span(display: NSRange(location: start, length: result.length - start), node: node))
                }
            }
            if !controller.markdown && !parent.isTitle {
                view.blockDecorations = []
                let source = raw as NSString
                var decorated = Set<Int>()
                for span in spans where span.node.kind == nil {
                    let line = source.paragraphRange(for: NSRange(location: span.node.range.location, length: 0))
                    let block = DiscourseMarkupCodec.style(ofLine: source.substring(with: line)).style
                    if case let .heading(level) = block {
                        var heading = headingFont(level)
                        if span.node.italic, let descriptor = heading.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) { heading = UIFont(descriptor: descriptor, size: 0) }
                        result.addAttribute(.font, value: heading, range: span.display)
                        for mark in span.node.inlineMarks where mark.italic {
                            if let descriptor = heading.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                                result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: 0), range: NSRange(location: span.display.location + mark.range.location, length: mark.range.length))
                            }
                        }
                    }
                    guard span.display.length > 0, block == .quote || block.isList else { continue }
                    let style = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    style.headIndent = block == .quote ? 18 : block == .checklist ? 44 : 28; style.firstLineHeadIndent = style.headIndent
                    result.addAttribute(.paragraphStyle, value: style, range: span.display)
                    if block == .quote { result.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: span.display) }
                    if decorated.insert(line.location).inserted {
                        let prefix = source.substring(with: line).prefix(DiscourseMarkupCodec.style(ofLine: source.substring(with: line)).prefix)
                        let marker = block == .checklist ? (prefix.contains("[x]") || prefix.contains("[X]") ? "☑" : "☐") : block == .numberedList ? String(prefix.prefix { $0.isNumber }) + "." : "•"
                        view.blockDecorations.append(.init(offset: span.display.location, marker: marker, quote: block == .quote))
                    }
                }
            } else { view.blockDecorations = [] }
            view.attributedText = result
            var typing = base; typing[.font] = font(bold: controller.boldTyping, italic: controller.italicTyping)
            view.typingAttributes = typing
            view.placeholder = raw.isEmpty ? String(localized: String.LocalizationValue(parent.placeholder)) : nil
            view.selectedRange = displayRange(selection)
            lastDisplay = view.text ?? ""
            controller.selection = EditorSelection(clamp(selection, in: raw))
            reportStyle()
            controller.canUndo = history.canUndo; controller.canRedo = history.canRedo
            view.invalidateIntrinsicContentSize()
        }
        func refreshAppearance() {
            guard let view else { return }
            // Repaint attachment previews only; never replace the document for upload progress.
            view.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: view.textStorage.length)) { value, _, _ in
                guard let attachment = value as? ComposerTextAttachment else { return }
                attachment.caption = parent.attachmentCaption(attachment.node)
            }
        }
        func remapExternal(_ selection: NSRange, to raw: String) -> NSRange {
            let before = Array(lastRaw.utf16), after = Array(raw.utf16)
            var prefix = 0, suffix = 0
            while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
            while suffix < min(before.count, after.count) - prefix, before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
            let oldEnd = before.count - suffix, newEnd = after.count - suffix
            func map(_ position: Int) -> Int {
                if position < prefix { return position }
                if position >= oldEnd { return position + newEnd - oldEnd }
                return prefix
            }
            let start = map(selection.location), end = map(NSMaxRange(selection))
            return clamp(NSRange(location: max(0, start), length: max(0, end - start)), in: raw)
        }
        func clamp(_ range: NSRange, in raw: String) -> NSRange {
            let length = (raw as NSString).length
            let start = max(0, min(range.location, length))
            return NSRange(location: start, length: max(0, min(range.length, length - start)))
        }
        func sourceOffset(_ offset: Int, end: Bool = false) -> Int {
            if controller.markdown || parent.isTitle { return max(0, min(offset, (lastRaw as NSString).length)) }
            if !end, let prefix = spans.last(where: { $0.display.length == 0 && $0.display.location == offset }) {
                return NSMaxRange(prefix.node.range)
            }
            for span in spans where span.display.length > 0 && offset >= span.display.location && offset <= NSMaxRange(span.display) {
                if span.node.kind != nil { return end || offset == NSMaxRange(span.display) ? NSMaxRange(span.node.range) : span.node.range.location }
                let content = span.node.contentRange ?? span.node.range
                if offset == span.display.location { return end ? content.location : span.node.range.location }
                if offset == NSMaxRange(span.display) { return end ? NSMaxRange(span.node.range) : NSMaxRange(content) }
                if let offsets = span.node.sourceOffsets { return offsets[min(offsets.count - 1, max(0, offset - span.display.location))] }
                return content.location + offset - span.display.location
            }
            return (lastRaw as NSString).length
        }
        func sourceRange(_ range: NSRange) -> NSRange {
            let start = sourceOffset(range.location)
            if range.length == 0 { return NSRange(location: start, length: 0) }
            if let span = spans.first(where: { $0.display.length > 0 && $0.node.kind == nil && range.location >= $0.display.location && NSMaxRange(range) <= NSMaxRange($0.display) }), let content = span.node.contentRange {
                if range == span.display { return span.node.range }
                func boundary(_ offset: Int) -> Int {
                    let local = max(0, min(offset - span.display.location, span.display.length))
                    return span.node.sourceOffsets?[local] ?? (content.location + local)
                }
                let lower = boundary(range.location)
                let upper = span.node.sourceEndOffsets?[max(0, min(NSMaxRange(range) - span.display.location - 1, span.display.length - 1))] ?? boundary(NSMaxRange(range))
                return NSRange(location: lower, length: upper - lower)
            }
            return NSRange(location: start, length: max(0, sourceOffset(NSMaxRange(range), end: true) - start))
        }
        func displayOffset(_ offset: Int) -> Int {
            if controller.markdown || parent.isTitle { return min(offset, (lastRaw as NSString).length) }
            for span in spans where offset >= span.node.range.location && offset <= NSMaxRange(span.node.range) {
                if span.node.kind != nil { return offset == NSMaxRange(span.node.range) ? NSMaxRange(span.display) : span.display.location }
                let content = span.node.contentRange ?? span.node.range
                if let ends = span.node.sourceEndOffsets { return span.display.location + ends.prefix { $0 <= offset }.count }
                if let offsets = span.node.sourceOffsets { return span.display.location + (offsets.lastIndex(where: { $0 <= offset }) ?? 0) }
                return span.display.location + max(0, min(offset - content.location, span.display.length))
            }
            return (lastDisplay as NSString).length
        }
        func displayRange(_ range: NSRange) -> NSRange {
            let start = displayOffset(range.location), end = displayOffset(NSMaxRange(range))
            return NSRange(location: start, length: max(0, end - start))
        }
        func commit(_ raw: String, selection: NSRange, action: String = "Edit") {
            guard !parent.locked, raw != lastRaw else { return }
            let previous = lastRaw, previousSelection = controller.selection.range
            registerUndo(action: action) { target in target.commit(previous, selection: previousSelection, action: action) }
            parent.raw = raw
            render(raw, selection: selection)
        }
        func registerUndo(action name: String = "Edit", _ action: @escaping (Coordinator) -> Void) {
            let needsGroup = history.groupingLevel == 0
            if needsGroup { history.beginUndoGrouping() }
            history.registerUndo(withTarget: self, handler: action)
            history.setActionName(String(localized: String.LocalizationValue(name)))
            if needsGroup { history.endUndoGrouping() }
        }
        func command(_ command: EditorCommand) {
            guard let view, view.markedTextRange == nil, !parent.locked else { return }
            let range = controller.selection.range
            switch command {
            case let .adopt(previous, selection):
                guard previous != parent.raw else { return }
                registerUndo(action: "Insert photo") { target in target.commit(previous, selection: selection.range, action: "Insert photo") }
                render(parent.raw, selection: remapExternal(selection.range, to: parent.raw))
            case let .select(selection): render(lastRaw, selection: selection.range)
            case .undo: history.undo()
            case .redo: history.redo()
            case .markdown:
                controller.markdown.toggle(); render(lastRaw, selection: range)
            case .bold, .italic:
                guard DiscourseMarkupCodec.supportsInlineFormatting(lastRaw, range: range) else { break }
                if range.length == 0 {
                    if case .bold = command { controller.boldTyping.toggle() } else { controller.italicTyping.toggle() }
                    view.typingAttributes[.font] = font(bold: controller.boldTyping, italic: controller.italicTyping)
                } else {
                    if controller.markdown {
                        let marker = { if case .bold = command { return "**" }; return "*" }()
                        let text = (lastRaw as NSString).substring(with: range)
                        commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: marker + text + marker), selection: NSRange(location: range.location, length: range.length + marker.count * 2), action: "Format")
                        break
                    }
                    formatSelection(bold: { if case .bold = command { return true }; return false }())
                }
            case let .style(style):
                guard !parent.isTitle, let result = DiscourseMarkupCodec.restyle(lastRaw, range: clamp(range, in: lastRaw), to: style) else { break }
                if result.raw == lastRaw { render(lastRaw, selection: result.selection) }
                else { commit(result.raw, selection: result.selection, action: "Change block type") }
            case let .link(label, url):
                guard DiscourseMarkupCodec.supportsInlineFormatting(lastRaw, range: range) else { break }
                let text = DiscourseMarkupCodec.link(label: label, url: url)
                commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: text), selection: NSRange(location: range.location + (text as NSString).length, length: 0), action: "Insert link")
            case let .insert(text):
                commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: text), selection: NSRange(location: range.location + (text as NSString).length, length: 0), action: "Insert")
            case let .replace(target, text):
                commit(DiscourseMarkupCodec.replace(lastRaw, range: target, with: text), selection: NSRange(location: target.location + (text as NSString).length, length: 0), action: "Edit block")
            }
            controller.canUndo = history.canUndo; controller.canRedo = history.canRedo
        }
        private struct VisualMark: Equatable {
            var bold: Bool; var italic: Bool; var code: Bool; var strike: Bool; var link: String?
        }
        private func marks(for node: MarkupNode) -> [VisualMark] {
            var result = Array(repeating: VisualMark(bold: node.bold, italic: node.italic, code: node.inlineCode, strike: node.strike, link: node.link), count: (node.text as NSString).length)
            for mark in node.inlineMarks {
                for index in mark.range.location..<min(result.count, NSMaxRange(mark.range)) {
                    result[index] = VisualMark(bold: mark.bold, italic: mark.italic, code: mark.code, strike: mark.strike, link: mark.link ?? node.link)
                }
            }
            return result
        }
        /// Serialize only edited runs. Block prefixes, opaque blocks and unrelated
        /// source remain untouched; selection mapping uses the visible UTF-16 range.
        private func formatSelection(bold: Bool) {
            guard let view else { return }
            let selection = view.selectedRange
            let runs = spans.filter { $0.node.kind == nil && NSIntersectionRange($0.display, selection).length > 0 }
            let selectedMarks = runs.flatMap { span -> [VisualMark] in
                let intersection = NSIntersectionRange(span.display, selection)
                let local = NSRange(location: intersection.location - span.display.location, length: intersection.length)
                return Array(marks(for: span.node)[local.location..<NSMaxRange(local)])
            }
            let enabled = !selectedMarks.allSatisfy { bold ? $0.bold : $0.italic }
            var raw = lastRaw
            for span in runs.reversed() {
                let intersection = NSIntersectionRange(span.display, selection)
                var styles = marks(for: span.node)
                for index in (intersection.location - span.display.location)..<(NSMaxRange(intersection) - span.display.location) {
                    if bold { styles[index].bold = enabled } else { styles[index].italic = enabled }
                }
                let replacement = serialize(span.node.text, styles: styles)
                raw = DiscourseMarkupCodec.replace(raw, range: span.node.range, with: replacement)
            }
            commit(raw, selection: controller.selection.range, action: "Format")
            let restored = sourceRange(selection)
            render(raw, selection: restored)
        }
        private func serialize(_ value: String, styles: [VisualMark]) -> String {
            let text = value as NSString
            var replacement = "", cursor = 0
                while cursor < styles.count {
                    var end = cursor + 1
                    while end < styles.count, styles[end] == styles[cursor] { end += 1 }
                    let value = text.substring(with: NSRange(location: cursor, length: end - cursor))
                    let leading = String(value.prefix { $0.isWhitespace })
                    let trailing = String(value.dropFirst(leading.count).reversed().prefix { $0.isWhitespace }.reversed())
                    let body = String(value.dropFirst(leading.count).dropLast(trailing.count))
                    let style = styles[cursor]
                    var content = DiscourseMarkupCodec.escapeInline(body)
                    if style.code { content = "`" + body + "`" }
                    if let link = style.link { content = DiscourseMarkupCodec.link(label: body, url: link) }
                    if style.strike, !body.isEmpty { content = "~~" + content + "~~" }
                    let marker = style.bold && style.italic ? "***" : style.bold ? "**" : style.italic ? "*" : ""
                    replacement += leading + (body.isEmpty ? "" : marker + content + marker) + trailing
                    cursor = end
                }
            return replacement
        }
        func textViewDidBeginEditing(_ textView: UITextView) { controller.focused = true; parent.onFocus() }
        func textViewDidEndEditing(_ textView: UITextView) { controller.focused = false }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !rendering, textView.markedTextRange == nil else { return }
            controller.selection = EditorSelection(sourceRange(textView.selectedRange))
            reportStyle()
            if controller.selection.length > 0 { return }
            if case .heading = controller.textStyle {
                // A heading's weight comes from its level, not from bold markup.
                let run = spans.first { $0.display.length > 0 && $0.node.contentRange.map { NSLocationInRange(controller.selection.location, $0) } == true }
                controller.boldTyping = run?.node.bold ?? false; controller.italicTyping = run?.node.italic ?? false
            } else if let font = textView.typingAttributes[.font] as? UIFont {
                controller.boldTyping = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                controller.italicTyping = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            }
        }
        private func insertVisualNewline(_ range: NSRange, prefix: String) {
            let source = sourceRange(range), replacement = "\n" + prefix
            if range.length == 0, let span = spans.first(where: { $0.node.contentRange != nil && $0.display.length > 0 && range.location >= $0.display.location && range.location <= NSMaxRange($0.display) }) {
                let local = range.location - span.display.location, styles = marks(for: span.node), text = span.node.text as NSString
                let before = serialize(text.substring(to: local), styles: Array(styles.prefix(local)))
                let after = serialize(text.substring(from: local), styles: Array(styles.dropFirst(local)))
                let value = before + replacement + after
                commit(DiscourseMarkupCodec.replace(lastRaw, range: span.node.range, with: value), selection: NSRange(location: span.node.range.location + (before as NSString).length + (replacement as NSString).length, length: 0))
            } else {
                commit(DiscourseMarkupCodec.replace(lastRaw, range: source, with: replacement), selection: NSRange(location: source.location + (replacement as NSString).length, length: 0))
            }
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !parent.locked else { return false }
            if textView.markedTextRange != nil { suspendNativeUndo(); return true }
            if parent.isTitle && text == "\n" { parent.onNext(); return false }
            if !controller.markdown && !parent.isTitle {
                let caret = sourceOffset(textView.selectedRange.location)
                let lineRange = (lastRaw as NSString).paragraphRange(for: NSRange(location: caret, length: 0))
                let line = (lastRaw as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
                let block = DiscourseMarkupCodec.style(ofLine: line)
                if text.isEmpty, range.length == 1, textView.selectedRange.length == 0,
                   block.prefix > 0, caret == lineRange.location + block.prefix {
                    let prefix = NSRange(location: lineRange.location, length: block.prefix)
                    commit(DiscourseMarkupCodec.replace(lastRaw, range: prefix, with: ""), selection: NSRange(location: prefix.location, length: 0)); return false
                }
                if text == "\n", block.style.isList || block.style == .quote {
                    if (line as NSString).length == block.prefix {
                        let prefix = NSRange(location: lineRange.location, length: block.prefix)
                        commit(DiscourseMarkupCodec.replace(lastRaw, range: prefix, with: ""), selection: NSRange(location: prefix.location, length: 0)); return false
                    }
                    var prefix = (line as NSString).substring(to: block.prefix)
                    if let number = Int(String(prefix.prefix { $0.isNumber })) { prefix = "\(number + 1). " }
                    prefix = prefix.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
                    insertVisualNewline(range, prefix: prefix); return false
                }
                if text == "\n" { insertVisualNewline(range, prefix: ""); return false }
            }
            let source = sourceRange(range)
            let replacement = parent.isTitle ? text.components(separatedBy: .newlines).joined(separator: " ") : text
            if replacement == text { suspendNativeUndo(); return true }
            commit(DiscourseMarkupCodec.replace(lastRaw, range: source, with: replacement), selection: NSRange(location: source.location + (replacement as NSString).length, length: 0))
            return false
        }
        func toggleTask(at displayOffset: Int) {
            guard !parent.locked, !parent.preview, parent.allowChecklists, !controller.markdown, view?.markedTextRange == nil else { return }
            let source = lastRaw as NSString
            let line = source.paragraphRange(for: NSRange(location: sourceOffset(displayOffset), length: 0))
            let value = source.substring(with: line) as NSString
            guard DiscourseMarkupCodec.style(ofLine: value as String).style == .checklist else { return }
            let bracket = value.range(of: "[")
            guard bracket.location != NSNotFound else { return }
            let target = NSRange(location: line.location + bracket.location + 1, length: 1)
            let replacement = source.substring(with: target) == " " ? "x" : " "
            commit(DiscourseMarkupCodec.replace(lastRaw, range: target, with: replacement), selection: controller.selection.range, action: "Edit task")
        }
        func removeInitialBlockPrefix() -> Bool {
            guard let view, !parent.locked, !parent.isTitle, !controller.markdown, view.markedTextRange == nil,
                  view.selectedRange.location == 0, view.selectedRange.length == 0 else { return false }
            let prefix = DiscourseMarkupCodec.style(ofLine: lastRaw).prefix
            guard prefix > 0 else { return false }
            commit(DiscourseMarkupCodec.replace(lastRaw, range: NSRange(location: 0, length: prefix), with: ""), selection: NSRange(location: 0, length: 0))
            return true
        }
        func suspendNativeUndo() {
            if !nativeUndoSuspended { history.disableUndoRegistration(); nativeUndoSuspended = true }
        }
        func textViewDidChange(_ textView: UITextView) {
            guard !rendering, textView.markedTextRange == nil else { return }
            if nativeUndoSuspended { history.enableUndoRegistration(); nativeUndoSuspended = false }
            // Native IME composition is allowed to finish before deriving a single committed edit.
            let before = lastDisplay as NSString, after = (textView.text ?? "") as NSString
            var prefix = 0
            while prefix < min(before.length, after.length), before.character(at: prefix) == after.character(at: prefix) { prefix += 1 }
            var suffix = 0
            while suffix < min(before.length, after.length) - prefix, before.character(at: before.length - suffix - 1) == after.character(at: after.length - suffix - 1) { suffix += 1 }
            if prefix > 0 && prefix < before.length && (0xDC00...0xDFFF).contains(before.character(at: prefix)) { prefix -= 1 }
            if suffix > 0 && suffix < before.length && (0xDC00...0xDFFF).contains(before.character(at: before.length - suffix)) { suffix -= 1 }
            let changed = NSRange(location: prefix, length: before.length - prefix - suffix)
            var replacement = after.substring(with: NSRange(location: prefix, length: after.length - prefix - suffix))
            var source = sourceRange(changed)
            var splitStyle = false
            if !controller.markdown && !parent.isTitle && !replacement.isEmpty,
               let span = spans.first(where: { span in
                   guard let content = span.node.contentRange, span.node.link == nil, span.node.bold || span.node.italic else { return false }
                   return source.location >= content.location && NSMaxRange(source) <= NSMaxRange(content)
               }), let content = span.node.contentRange,
               span.node.bold != controller.boldTyping || span.node.italic != controller.italicTyping {
                let originalMarker = span.node.bold && span.node.italic ? "***" : span.node.bold ? "**" : "*"
                let desiredMarker = controller.boldTyping && controller.italicTyping ? "***" : controller.boldTyping ? "**" : controller.italicTyping ? "*" : ""
                let prefix = (lastRaw as NSString).substring(with: NSRange(location: content.location, length: source.location - content.location))
                let suffix = (lastRaw as NSString).substring(with: NSRange(location: NSMaxRange(source), length: NSMaxRange(content) - NSMaxRange(source)))
                replacement = (prefix.isEmpty ? "" : originalMarker + prefix + originalMarker) + desiredMarker + replacement + desiredMarker + (suffix.isEmpty ? "" : originalMarker + suffix + originalMarker)
                source = span.node.range; splitStyle = true
            }
            if !splitStyle && !controller.markdown && !parent.isTitle && !replacement.isEmpty && (controller.boldTyping || controller.italicTyping) {
                let alreadyStyled = spans.contains { span in
                    guard let content = span.node.contentRange else { return false }
                    return source.location >= content.location && NSMaxRange(source) <= NSMaxRange(content) && span.node.bold == controller.boldTyping && span.node.italic == controller.italicTyping
                }
                if !alreadyStyled {
                    let marker = controller.boldTyping && controller.italicTyping ? "***" : controller.boldTyping ? "**" : "*"
                    replacement = marker + replacement + marker
                }
            }
            let previous = lastRaw, previousSelection = controller.selection.range
            let raw = DiscourseMarkupCodec.replace(lastRaw, range: source, with: replacement)
            let caret = NSRange(location: source.location + (replacement as NSString).length, length: 0)
            registerUndo { target in target.commit(previous, selection: previousSelection) }
            parent.raw = raw
            render(raw, selection: caret)
        }
    }
}

final class ComposerTextView: UITextView {
    var documentUndoManager: UndoManager?
    var deleteAtDocumentStart: (() -> Bool)?
    override func deleteBackward() {
        if selectedRange.location == 0, selectedRange.length == 0, deleteAtDocumentStart?() == true { return }
        super.deleteBackward()
    }
    private var arrangingAttachments = false
    var toggleTask: ((Int) -> Void)?
    var allowsTaskEditing = true
    private final class TaskButton: UIButton { var offset = 0 }
    struct BlockDecoration { var offset: Int; var marker: String; var quote: Bool }
    var blockDecorations: [BlockDecoration] = [] { didSet { setNeedsDisplay(); setNeedsLayout() } }
    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }
    override func layoutSubviews() {
        guard !arrangingAttachments else { return }
        arrangingAttachments = true; defer { arrangingAttachments = false }
        super.layoutSubviews()
        arrangeTasks()
        var hasAttachments = false
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, _, stop in
            if value is ComposerTextAttachment { hasAttachments = true; stop.pointee = true }
        }
        guard hasAttachments else {
            for card in subviews.compactMap({ $0 as? ComposerAttachmentCard }) { card.removeFromSuperview() }
            return
        }
        guard let manager = textLayoutManager, let content = manager.textContentManager else { return }
        manager.ensureLayout(for: content.documentRange)
        var visible = Set<ObjectIdentifier>()
        // iOS 26 can lay out an attachment without placing its provider view in a
        // non-scrolling UITextView. Use the same TextKit fragment geometry for its
        // native child card, so the controls share the attachment's document position.
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            guard let attachment = value as? ComposerTextAttachment,
                  let location = content.location(content.documentRange.location, offsetBy: range.location),
                  let fragment = manager.textLayoutFragment(for: location) else { return }
            var glyph = fragment.frameForTextAttachment(at: location)
            glyph.origin.x += fragment.layoutFragmentFrame.minX + self.textContainerInset.left
            glyph.origin.y += fragment.layoutFragmentFrame.minY + self.textContainerInset.top
            guard !glyph.isNull, glyph.minY.isFinite else { return }
            let card = attachment.card ?? ComposerAttachmentCard(attachment: attachment)
            attachment.card = card
            if card.superview !== self { self.addSubview(card) }
            card.frame = CGRect(x: glyph.minX, y: glyph.minY, width: attachment.bounds.width, height: attachment.bounds.height)
            card.layoutIfNeeded(); visible.insert(ObjectIdentifier(card))
        }
        for card in subviews.compactMap({ $0 as? ComposerAttachmentCard }) where !visible.contains(ObjectIdentifier(card)) { card.removeFromSuperview() }
    }
    private func arrangeTasks() {
        let tasks = blockDecorations.filter { $0.marker == "☐" || $0.marker == "☑" }
        var buttons = subviews.compactMap { $0 as? TaskButton }
        while buttons.count > tasks.count { buttons.removeLast().removeFromSuperview() }
        while buttons.count < tasks.count {
            let button = TaskButton(type: .system)
            button.addAction(UIAction { [weak self, weak button] _ in if let button { self?.toggleTask?(button.offset) } }, for: .touchUpInside)
            addSubview(button); buttons.append(button)
        }
        for (button, task) in zip(buttons, tasks) {
            guard let position = position(from: beginningOfDocument, offset: task.offset) else { continue }
            let caret = caretRect(for: position)
            let rtl = baseWritingDirection(for: position, in: .forward) == .rightToLeft
            button.frame = CGRect(x: rtl ? bounds.width - 44 : 0, y: caret.midY - 22, width: 44, height: 44)
            button.offset = task.offset; button.isEnabled = allowsTaskEditing
            button.setImage(UIImage(systemName: task.marker == "☑" ? "checkmark.square.fill" : "square"), for: .normal)
            button.accessibilityLabel = String(localized: "Task")
            button.accessibilityValue = String(localized: task.marker == "☑" ? "Checked" : "Unchecked")
            button.accessibilityIdentifier = "composer-task-\(task.offset)"
        }
    }
    var placeholder: String? { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        for decoration in blockDecorations {
            if decoration.marker == "☐" || decoration.marker == "☑" { continue }
            guard let position = position(from: beginningOfDocument, offset: decoration.offset) else { continue }
            let caret = caretRect(for: position)
            let rtl = baseWritingDirection(for: position, in: .forward) == .rightToLeft
            let x = rtl ? bounds.width - 18 : 0.0
            if decoration.quote {
                UIColor.tertiaryLabel.setFill()
                UIBezierPath(roundedRect: CGRect(x: x + 2, y: caret.minY, width: 3, height: caret.height), cornerRadius: 1.5).fill()
            } else {
                (decoration.marker as NSString).draw(in: CGRect(x: rtl ? bounds.width - 26 : 0, y: caret.minY, width: 26, height: caret.height + 4), withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.secondaryLabel])
            }
        }
        guard let placeholder, text.isEmpty else { return }
        (placeholder as NSString).draw(in: CGRect(x: 0, y: 8, width: bounds.width, height: 80), withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.tertiaryLabel])
    }
}

final class ComposerTextAttachment: NSTextAttachment, @unchecked Sendable {
    var node: MarkupNode
    var preview = false
    var photo: UIImage?
    var caption: String? { didSet { let label = card?.caption; let value = caption ?? ComposerAttachmentCard.summary(node); let concealed = node.kind == .spoiler; MainActor.assumeIsolated { label?.text = concealed ? String(localized: "Concealed text") : value } } }
    var edit: (() -> Void)?
    var remove: (() -> Void)?
    weak var card: ComposerAttachmentCard?
    init(node: MarkupNode, data: Data?, caption: String?, width: CGFloat, preview: Bool = false) {
        self.preview = preview
        self.node = node; photo = data.flatMap(Self.previewImage); self.caption = caption
        super.init(data: Data(node.raw.utf8), ofType: "app.fomio.composer-block")
        contents = Data(node.raw.utf8)
        fileType = "app.fomio.composer-block"
        allowsTextAttachmentView = false
        image = UIImage()
        bounds = CGRect(x: 0, y: 0, width: width, height: UIFontMetrics.default.scaledValue(for: data != nil ? 310 : node.kind == .quote ? 300 : 180))
    }
    private static func previewImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
    required init?(coder: NSCoder) { return nil }
}

final class ComposerAttachmentCard: UIView {
    let caption = UILabel()
    init(attachment: ComposerTextAttachment) {
        super.init(frame: attachment.bounds)
        backgroundColor = .secondarySystemBackground; layer.cornerRadius = 12
        let title = UILabel(); title.font = .preferredFont(forTextStyle: .headline); title.adjustsFontForContentSizeCategory = true
        title.text = String(localized: String.LocalizationValue(attachment.node.kind?.title ?? "Block"))
        caption.font = .preferredFont(forTextStyle: .subheadline); caption.adjustsFontForContentSizeCategory = true; caption.numberOfLines = attachment.preview ? 0 : 2
        if attachment.node.kind == .code { caption.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .regular) }
        title.setContentHuggingPriority(.required, for: .vertical); caption.setContentHuggingPriority(.required, for: .vertical)
        caption.text = attachment.caption ?? Self.summary(attachment.node)
        let edit = UIButton(type: .system); edit.setTitle(String(localized: attachment.node.kind == .opaque ? "Edit in Markdown" : "Edit"), for: .normal)
        edit.accessibilityIdentifier = "composer-block-edit-" + (attachment.node.kind?.rawValue ?? "unknown")
        edit.addAction(UIAction { _ in attachment.edit?() }, for: .touchUpInside)
        let remove = UIButton(type: .system); remove.setTitle(String(localized: "Remove"), for: .normal)
        remove.addAction(UIAction { _ in attachment.remove?() }, for: .touchUpInside)
        for button in [edit, remove] {
            button.titleLabel?.font = .preferredFont(forTextStyle: .body); button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        let actions = UIStackView(arrangedSubviews: [edit, remove]); actions.spacing = 16
        actions.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        var content: [UIView] = [title, caption]
        if attachment.node.kind == .quote {
            let prompt = UILabel(); prompt.font = .preferredFont(forTextStyle: .body); prompt.adjustsFontForContentSizeCategory = true; prompt.numberOfLines = 0; prompt.text = String(localized: "Write your reply below this quotation")
            content.append(prompt)
            let collapse = UIButton(type: .system); collapse.setTitle(String(localized: "Expand quotation"), for: .normal)
            collapse.titleLabel?.font = .preferredFont(forTextStyle: .body); collapse.titleLabel?.adjustsFontForContentSizeCategory = true
            collapse.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            collapse.addAction(UIAction { [weak self, weak collapse, weak attachment] _ in
                guard let self, let collapse, let attachment else { return }
                let expanded = self.caption.numberOfLines == 0; self.caption.numberOfLines = expanded ? 2 : 0
                collapse.setTitle(String(localized: expanded ? "Expand quotation" : "Collapse quotation"), for: .normal)
                attachment.bounds.size.height = expanded ? UIFontMetrics.default.scaledValue(for: 300) : max(UIFontMetrics.default.scaledValue(for: 300), self.systemLayoutSizeFitting(CGSize(width: self.bounds.width, height: UIView.layoutFittingCompressedSize.height)).height)
                if let editor = self.superview as? ComposerTextView, let manager = editor.textLayoutManager, let content = manager.textContentManager {
                    manager.invalidateLayout(for: content.documentRange); editor.invalidateIntrinsicContentSize(); editor.setNeedsLayout()
                }
            }, for: .touchUpInside)
            content.append(collapse)
        }
        content.append(UIView()); if !attachment.preview { content.append(actions) }
        let stack = UIStackView(arrangedSubviews: content); stack.axis = .vertical; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), stack.topAnchor.constraint(equalTo: topAnchor, constant: 12), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)])
        if let image = attachment.photo {
            let photo = UIImageView(image: image); photo.contentMode = .scaleAspectFit; photo.heightAnchor.constraint(equalToConstant: 120).isActive = true
            photo.isAccessibilityElement = true; photo.accessibilityLabel = attachment.node.text
            stack.insertArrangedSubview(photo, at: 1); attachment.bounds.size.height = UIFontMetrics.default.scaledValue(for: 310)
        }
        if attachment.preview {
            let size = systemLayoutSizeFitting(CGSize(width: attachment.bounds.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            attachment.bounds.size.height = max(100, size.height); frame.size.height = attachment.bounds.height
        }
        accessibilityElements = stack.arrangedSubviews
    }
    nonisolated static func summary(_ node: MarkupNode) -> String {
        if node.kind == .spoiler { return String(localized: "Concealed text") }
        if node.kind == .opaque { return String(localized: "Preserved block") }
        guard let value = ComposerBlockValue.editing(node) else { return node.kind == .photo || node.kind == .code || node.kind == .quote ? node.text : String(localized: String.LocalizationValue(node.kind?.title ?? "Block")) }
        switch value.kind {
        case .table: return value.cells.map { $0.joined(separator: "    ") }.joined(separator: "\n")
        case .poll: return value.heading + "\n" + value.options.map { "○ " + $0 }.joined(separator: "\n")
        case .date: return value.date.formatted(date: .abbreviated, time: .shortened)
        case .details: return value.heading + "\n" + value.body
        default: return value.body
        }
    }
    required init?(coder: NSCoder) { nil }
}


@MainActor struct ComposerMenuAction {
    var title: String
    var symbol: String
    var enabled: Bool
    var group: String?
    var perform: () -> Void
    init(_ title: String, _ symbol: String, enabled: Bool = true, group: String? = nil, perform: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.enabled = enabled; self.group = group; self.perform = perform
    }
}

/// A native menu button keeps its UIKit hierarchy stable while the editor changes size.
struct ComposerMoreMenu: UIViewRepresentable {
    @Environment(\.locale) private var locale
    var actions: [ComposerMenuAction]
    /// Icon-only on the full bar; the compact fallback spells out More.
    var labelled = true
    var onOpen: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "ellipsis"); configuration.imagePadding = 6
        // Insets give the icon-only button a 44 pt target; a SwiftUI frame around it would not enlarge the UIKit hit area.
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        button.configuration = configuration
        button.accessibilityLabel = String(localized: "More", locale: locale)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body); button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.showsMenuAsPrimaryAction = true; button.accessibilityIdentifier = "composer-more"
        button.preferredMenuElementOrder = .fixed
        button.addAction(UIAction { [weak coordinator = context.coordinator] _ in coordinator?.parent.onOpen() }, for: .touchDown)
        updateUIView(button, context: context)
        return button
    }
    func updateUIView(_ button: UIButton, context: Context) {
        let coordinator = context.coordinator; coordinator.parent = self
        if (button.configuration?.title != nil) != labelled {
            button.configuration?.title = labelled ? String(localized: "More", locale: locale) : nil
            button.tintColor = labelled ? nil : .label
        }
        let signature = locale.identifier + actions.map { "\($0.title)|\($0.enabled)|\($0.group ?? "")" }.joined(separator: ";")
        guard coordinator.signature != signature else { return }
        coordinator.signature = signature
        func element(_ index: Int) -> UIAction {
            let item = actions[index]
            return UIAction(title: String(localized: String.LocalizationValue(item.title), locale: locale), image: UIImage(systemName: item.symbol), attributes: item.enabled ? [] : [.disabled]) { [weak coordinator] _ in
                guard let coordinator, coordinator.parent.actions.indices.contains(index) else { return }
                coordinator.parent.actions[index].perform()
            }
        }
        var children: [UIMenuElement] = [], groups = Set<String>()
        for index in actions.indices {
            if let group = actions[index].group {
                if groups.insert(group).inserted {
                    children.append(UIMenu(title: String(localized: String.LocalizationValue(group), locale: locale), children: actions.indices.filter { actions[$0].group == group }.map(element)))
                }
            } else { children.append(element(index)) }
        }
        button.menu = UIMenu(children: children)
    }
    final class Coordinator {
        var parent: ComposerMoreMenu
        var signature = ""
        init(_ parent: ComposerMoreMenu) { self.parent = parent }
    }
}
