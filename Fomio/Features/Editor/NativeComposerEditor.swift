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
        let accessory = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: UIFontMetrics.default.scaledValue(for: 44)), inputViewStyle: .keyboard)
        accessory.allowsSelfSizing = true; accessory.tintColor = UIColor(Color.fomioAccent)
        let controls = UIStackView(); controls.axis = .horizontal; controls.translatesAutoresizingMaskIntoConstraints = false
        func button(_ title: String, identifier: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system); button.setTitle(String(localized: String.LocalizationValue(title)), for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .body); button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.accessibilityIdentifier = identifier; button.addTarget(context.coordinator, action: action, for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return button
        }
        if isTitle { controls.addArrangedSubview(button("Next", identifier: "composer-next", action: #selector(Coordinator.nextField))) }
        controls.addArrangedSubview(UIView())
        controls.addArrangedSubview(button("Done", identifier: "composer-keyboard-done", action: #selector(Coordinator.doneEditing)))
        accessory.addSubview(controls)
        NSLayoutConstraint.activate([controls.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 12), controls.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -12), controls.topAnchor.constraint(equalTo: accessory.topAnchor), controls.bottomAnchor.constraint(equalTo: accessory.bottomAnchor)])
        view.inputAccessoryView = accessory
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
        func render(_ raw: String, selection: NSRange) {
            guard let view, view.markedTextRange == nil else { return }
            rendering = true
            let suspend = history.isUndoRegistrationEnabled
            if suspend { history.disableUndoRegistration() }
            defer { if suspend { history.enableUndoRegistration() }; rendering = false }
            lastRaw = raw; lastMarkdown = controller.markdown; spans = []
            let result = NSMutableAttributedString(string: "")
            let paragraph = NSMutableParagraphStyle(); paragraph.baseWritingDirection = .natural; paragraph.alignment = .natural; paragraph.paragraphSpacing = 6
            let base: [NSAttributedString.Key: Any] = [.font: font(), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
            if controller.markdown || parent.isTitle { result.append(NSAttributedString(string: raw, attributes: base)) }
            else {
                for node in DiscourseMarkupCodec.parse(raw) {
                    let start = result.length
                    if node.kind != nil {
                        let attachment = ComposerTextAttachment(node: node, data: parent.attachmentData(node), caption: parent.attachmentCaption(node), width: max(180, view.bounds.width))
                        attachment.edit = { [weak self, weak attachment] in if let attachment { self?.parent.onBlock(attachment.node) } }
                        attachment.remove = { [weak self, weak attachment] in if let attachment { self?.parent.onRemove(attachment.node) } }
                        result.append(NSAttributedString(attachment: attachment))
                    } else {
                        var attributes = base; attributes[.font] = font(bold: node.bold, italic: node.italic)
                        if let link = node.link, let url = URL(string: link), ["http", "https"].contains(url.scheme ?? "") { attributes[.link] = url }
                        result.append(NSAttributedString(string: node.text, attributes: attributes))
                    }
                    spans.append(Span(display: NSRange(location: start, length: result.length - start), node: node))
                }
            }
            if !controller.markdown && !parent.isTitle {
                let displayed = result.string as NSString
                var start = 0
                while start < displayed.length {
                    let range = displayed.paragraphRange(for: NSRange(location: start, length: 0))
                    let text = displayed.substring(with: range)
                    if text.hasPrefix("* ") || text.hasPrefix("- ") {
                        result.replaceCharacters(in: NSRange(location: range.location, length: 1), with: "•")
                        let style = paragraph.mutableCopy() as! NSMutableParagraphStyle; style.headIndent = 20
                        result.addAttribute(.paragraphStyle, value: style, range: range)
                    } else if text.hasPrefix("> ") {
                        let style = paragraph.mutableCopy() as! NSMutableParagraphStyle; style.headIndent = 16; style.firstLineHeadIndent = 16
                        result.addAttributes([.paragraphStyle: style, .foregroundColor: UIColor.secondaryLabel], range: range)
                    }
                    start = NSMaxRange(range)
                }
            }
            view.attributedText = result
            var typing = base; typing[.font] = font(bold: controller.boldTyping, italic: controller.italicTyping)
            view.typingAttributes = typing
            view.placeholder = raw.isEmpty ? String(localized: String.LocalizationValue(parent.placeholder)) : nil
            view.selectedRange = displayRange(selection)
            lastDisplay = view.text ?? ""
            controller.selection = EditorSelection(clamp(selection, in: raw))
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
            for span in spans where offset >= span.display.location && offset <= NSMaxRange(span.display) {
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
            if let span = spans.first(where: { $0.node.kind == nil && range.location >= $0.display.location && NSMaxRange(range) <= NSMaxRange($0.display) }), let content = span.node.contentRange {
                if range == span.display { return span.node.range }
                func boundary(_ offset: Int) -> Int {
                    let local = max(0, min(offset - span.display.location, span.display.length))
                    return span.node.sourceOffsets?[local] ?? (content.location + local)
                }
                let lower = boundary(range.location), upper = boundary(NSMaxRange(range))
                return NSRange(location: lower, length: upper - lower)
            }
            return NSRange(location: start, length: max(0, sourceOffset(NSMaxRange(range), end: true) - start))
        }
        func displayOffset(_ offset: Int) -> Int {
            if controller.markdown || parent.isTitle { return min(offset, (lastRaw as NSString).length) }
            for span in spans where offset >= span.node.range.location && offset <= NSMaxRange(span.node.range) {
                if span.node.kind != nil { return offset == NSMaxRange(span.node.range) ? NSMaxRange(span.display) : span.display.location }
                let content = span.node.contentRange ?? span.node.range
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
                if range.length == 0 {
                    if case .bold = command { controller.boldTyping.toggle() } else { controller.italicTyping.toggle() }
                    view.typingAttributes[.font] = font(bold: controller.boldTyping, italic: controller.italicTyping)
                } else {
                    if let span = spans.first(where: {
                        guard $0.node.link == nil, $0.node.bold || $0.node.italic, let content = $0.node.contentRange else { return false }
                        return range == $0.node.range || (range.location >= content.location && NSMaxRange(range) <= NSMaxRange(content))
                    }), let content = span.node.contentRange {
                        let selection = range == span.node.range ? content : range
                        let source = lastRaw as NSString
                        let before = source.substring(with: NSRange(location: content.location, length: selection.location - content.location))
                        let text = source.substring(with: selection)
                        let after = source.substring(with: NSRange(location: NSMaxRange(selection), length: NSMaxRange(content) - NSMaxRange(selection)))
                        func marked(_ text: String, bold: Bool, italic: Bool) -> String {
                            guard !text.isEmpty else { return "" }
                            let marker = bold && italic ? "***" : bold ? "**" : italic ? "*" : ""
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !marker.isEmpty else { return text }
                            let leading = String(text.prefix { $0.isWhitespace })
                            let trailing = String(text.reversed().prefix { $0.isWhitespace }.reversed())
                            return leading + marker + trimmed + marker + trailing
                        }
                        var bold = span.node.bold, italic = span.node.italic
                        if case .bold = command { bold.toggle() } else { italic.toggle() }
                        let prefix = marked(before, bold: span.node.bold, italic: span.node.italic)
                        let selected = marked(text, bold: bold, italic: italic)
                        let suffix = marked(after, bold: span.node.bold, italic: span.node.italic)
                        let replacement = prefix + selected + suffix
                        commit(DiscourseMarkupCodec.replace(lastRaw, range: span.node.range, with: replacement), selection: NSRange(location: span.node.range.location + (prefix as NSString).length, length: (selected as NSString).length), action: "Format")
                        break
                    }
                    let marker = { if case .bold = command { return "**" }; return "*" }()
                    let selected = (lastRaw as NSString).substring(with: clamp(range, in: lastRaw))
                    let stripped = selected.hasPrefix(marker) && selected.hasSuffix(marker) && selected.count > marker.count * 2
                    let replacement = stripped ? String(selected.dropFirst(marker.count).dropLast(marker.count)) : marker + selected + marker
                    commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: replacement), selection: NSRange(location: range.location, length: (replacement as NSString).length), action: "Format")
                }
            case .quote, .list:
                let source = lastRaw as NSString
                let paragraph = source.paragraphRange(for: clamp(range, in: lastRaw))
                let prefix = { if case .quote = command { return "> " }; return "- " }()
                let replacement = source.substring(with: paragraph).components(separatedBy: "\n").map { prefix + $0 }.joined(separator: "\n")
                commit(DiscourseMarkupCodec.replace(lastRaw, range: paragraph, with: replacement), selection: NSRange(location: paragraph.location + (replacement as NSString).length, length: 0), action: "Format")
            case let .link(label, url):
                let text = DiscourseMarkupCodec.link(label: label, url: url)
                commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: text), selection: NSRange(location: range.location + (text as NSString).length, length: 0), action: "Insert link")
            case let .insert(text):
                commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: text), selection: NSRange(location: range.location + (text as NSString).length, length: 0), action: "Insert")
            case let .replace(target, text):
                commit(DiscourseMarkupCodec.replace(lastRaw, range: target, with: text), selection: NSRange(location: target.location + (text as NSString).length, length: 0), action: "Edit block")
            }
            controller.canUndo = history.canUndo; controller.canRedo = history.canRedo
        }
        @objc func nextField() { parent.onNext() }
        @objc func doneEditing() { controller.blur() }
        func textViewDidBeginEditing(_ textView: UITextView) { controller.focused = true; parent.onFocus() }
        func textViewDidEndEditing(_ textView: UITextView) { controller.focused = false }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !rendering, textView.markedTextRange == nil else { return }
            controller.selection = EditorSelection(sourceRange(textView.selectedRange))
            if let font = textView.typingAttributes[.font] as? UIFont {
                controller.boldTyping = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                controller.italicTyping = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            }
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !parent.locked else { return false }
            if textView.markedTextRange != nil { suspendNativeUndo(); return true }
            if parent.isTitle && text == "\n" { parent.onNext(); return false }
            if text == "\n" && !controller.markdown && !parent.isTitle {
                let range = sourceRange(range)
                let paragraph = (lastRaw as NSString).paragraphRange(for: range)
                let line = (lastRaw as NSString).substring(with: paragraph).trimmingCharacters(in: .newlines)
                if line.hasPrefix("* ") || line.hasPrefix("- ") {
                    if line.count == 2 {
                        let marker = NSRange(location: paragraph.location, length: 2)
                        commit(DiscourseMarkupCodec.replace(lastRaw, range: marker, with: ""), selection: NSRange(location: paragraph.location, length: 0)); return false
                    }
                    let replacement = "\n" + String(line.prefix(2))
                    commit(DiscourseMarkupCodec.replace(lastRaw, range: range, with: replacement), selection: NSRange(location: range.location + (replacement as NSString).length, length: 0)); return false
                }
            }
            let source = sourceRange(range)
            let replacement = parent.isTitle ? text.components(separatedBy: .newlines).joined(separator: " ") : text
            if replacement == text { suspendNativeUndo(); return true }
            commit(DiscourseMarkupCodec.replace(lastRaw, range: source, with: replacement), selection: NSRange(location: source.location + (replacement as NSString).length, length: 0))
            return false
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
            registerUndo { target in target.commit(previous, selection: previousSelection) }
            lastRaw = raw; lastDisplay = textView.text ?? ""
            if !controller.markdown && !parent.isTitle {
                var position = 0
                spans = DiscourseMarkupCodec.parse(raw).map { node in
                    let length = node.kind == nil ? (node.text as NSString).length : 1
                    defer { position += length }
                    return Span(display: NSRange(location: position, length: length), node: node)
                }
                textView.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textView.textStorage.length)) { value, range, _ in
                    if let attachment = value as? ComposerTextAttachment, let span = spans.first(where: { $0.display.location == range.location && $0.node.kind != nil }) { attachment.node = span.node }
                }
            }
            let projected = controller.markdown || parent.isTitle ? raw : DiscourseMarkupCodec.parse(raw).map { $0.kind == nil ? $0.text : "\u{fffc}" }.joined()
            if projected.replacingOccurrences(of: "(?m)^[-*] ", with: "• ", options: .regularExpression) != lastDisplay && projected != lastDisplay {
                parent.raw = raw
                render(raw, selection: NSRange(location: source.location + (replacement as NSString).length, length: 0))
                return
            }
            parent.raw = raw
            controller.selection = EditorSelection(sourceRange(textView.selectedRange))
            controller.canUndo = history.canUndo; controller.canRedo = history.canRedo
            (textView as? ComposerTextView)?.placeholder = raw.isEmpty ? String(localized: String.LocalizationValue(parent.placeholder)) : nil
            textView.invalidateIntrinsicContentSize()
        }
    }
}

final class ComposerTextView: UITextView {
    var documentUndoManager: UndoManager?
    private var arrangingAttachments = false
    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }
    override func layoutSubviews() {
        guard !arrangingAttachments else { return }
        arrangingAttachments = true; defer { arrangingAttachments = false }
        super.layoutSubviews()
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
    var placeholder: String? { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let placeholder, text.isEmpty else { return }
        (placeholder as NSString).draw(in: CGRect(x: 0, y: 8, width: bounds.width, height: 80), withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.tertiaryLabel])
    }
}

final class ComposerTextAttachment: NSTextAttachment, @unchecked Sendable {
    var node: MarkupNode
    var photo: UIImage?
    var caption: String? { didSet { let label = card?.caption; let value = caption ?? node.text; let concealed = node.kind == .spoiler; MainActor.assumeIsolated { label?.text = concealed ? String(localized: "Concealed text") : value } } }
    var edit: (() -> Void)?
    var remove: (() -> Void)?
    weak var card: ComposerAttachmentCard?
    init(node: MarkupNode, data: Data?, caption: String?, width: CGFloat) {
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
        caption.font = .preferredFont(forTextStyle: .subheadline); caption.adjustsFontForContentSizeCategory = true; caption.numberOfLines = 2
        if attachment.node.kind == .code { caption.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .regular) }
        title.setContentHuggingPriority(.required, for: .vertical); caption.setContentHuggingPriority(.required, for: .vertical)
        caption.text = attachment.caption ?? (attachment.node.kind == .spoiler ? String(localized: "Concealed text") : attachment.node.text)
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
        content.append(UIView()); content.append(actions)
        let stack = UIStackView(arrangedSubviews: content); stack.axis = .vertical; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), stack.topAnchor.constraint(equalTo: topAnchor, constant: 12), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)])
        if let image = attachment.photo {
            let photo = UIImageView(image: image); photo.contentMode = .scaleAspectFit; photo.heightAnchor.constraint(equalToConstant: 120).isActive = true
            photo.isAccessibilityElement = true; photo.accessibilityLabel = attachment.node.text
            stack.insertArrangedSubview(photo, at: 1); attachment.bounds.size.height = UIFontMetrics.default.scaledValue(for: 310)
        }
        accessibilityElements = stack.arrangedSubviews
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
    var onOpen: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = String(localized: "More", locale: locale); configuration.image = UIImage(systemName: "ellipsis"); configuration.imagePadding = 6
        button.configuration = configuration
        button.titleLabel?.font = .preferredFont(forTextStyle: .body); button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.showsMenuAsPrimaryAction = true; button.accessibilityIdentifier = "composer-more"
        button.addAction(UIAction { [weak coordinator = context.coordinator] _ in coordinator?.parent.onOpen() }, for: .touchDown)
        updateUIView(button, context: context)
        return button
    }
    func updateUIView(_ button: UIButton, context: Context) {
        let coordinator = context.coordinator; coordinator.parent = self
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
