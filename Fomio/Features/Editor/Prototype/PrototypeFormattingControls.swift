#if DEBUG
import SwiftUI

/// Bold, italic, strikethrough, link, lists and quote for a prototype session.
/// Shared by the prototype screen and the composer's Debug rich editor.
struct PrototypeFormattingControls: View {
    @Binding var session: PrototypeEditorSession
    /// Runs before any change, for example to cancel a pending paste.
    var willEdit: () -> Void = {}
    /// Runs after a change, usually to return focus to the editor.
    var didEdit: () -> Void = {}
    @State private var linkSheet = false
    @State private var linkLabel = ""
    @State private var linkAddress = ""
    @State private var linkInserts = false
    /// The selection when the dialog opened; the editor can move it while the dialog has focus.
    @State private var linkRange = (0, 0)
    private var text: AttributedString { session.value.text }
    private var selection: AttributedTextSelection { session.value.selection }

    var body: some View {
        HStack {
            formatButton("Bold", symbol: "bold", mark: .bold)
            formatButton("Italic", symbol: "italic", mark: .italic)
            formatButton("Strikethrough", symbol: "strikethrough", mark: .strike)
            Button { openLink() } label: { Image(systemName: "link").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel("Link")
                .accessibilityValue(session.selectedLink == nil ? "Off" : "On")
                .accessibilityIdentifier("prototype-link")
                .tint(session.selectedLink == nil ? .primary : .accentColor)
            blockButton("Bulleted list", symbol: "list.bullet", identifier: "bullet", block: .bullet)
            blockButton("Numbered list", symbol: "list.number", identifier: "numbered", block: .ordered(1))
            blockButton("Quote", symbol: "text.quote", identifier: "quote", block: .quote)
        }
        // A sheet rather than an alert: an alert keeps the Apply state it opened with.
        .sheet(isPresented: $linkSheet, onDismiss: didEdit) {
            NavigationStack {
                Form {
                    Section {
                        if linkInserts { TextField("Text", text: $linkLabel).accessibilityIdentifier("prototype-link-text") }
                        TextField("URL", text: $linkAddress)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("prototype-link-url")
                    } footer: { Text("Links can use https, http or mailto.") }
                    if session.selectedLink != nil {
                        Button("Remove link", role: .destructive) { restoreLinkRange(); session.link(nil); linkSheet = false }
                    }
                }
                .navigationTitle("Link").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { linkSheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { applyLink(); linkSheet = false }
                            .disabled(linkURL == nil || (linkInserts && linkLabel.isEmpty))
                            .accessibilityIdentifier("prototype-link-apply")
                    }
                }
            }.presentationDetents([.medium, .large])
        }
    }

    private func isActive(_ mark: PrototypeMarks) -> Bool {
        let values = Array(selection.attributes(in: text))
        return !values.isEmpty && values.allSatisfy { ($0[PrototypeMarksAttribute.self] ?? []).contains(mark) }
    }
    private func formatButton(_ title: String, symbol: String, mark: PrototypeMarks) -> some View {
        Button {
            willEdit()
            session.format(mark)
            didEdit()
        } label: { Image(systemName: symbol).frame(minWidth: 44, minHeight: 44) }
        .accessibilityLabel(title)
        .accessibilityValue(isActive(mark) ? "On" : "Off")
        .accessibilityIdentifier("prototype-\(title.lowercased())")
        .tint(isActive(mark) ? .accentColor : .primary)
    }
    private func blockButton(_ title: String, symbol: String, identifier: String, block: PrototypeBlock) -> some View {
        let active = session.selectedBlocks.allSatisfy { $0?.isKind(of: block) == true }
        return Button {
            willEdit()
            session.toggleBlock(block)
            didEdit()
        } label: { Image(systemName: symbol).frame(minWidth: 44, minHeight: 44) }
        .accessibilityLabel(title)
        .accessibilityValue(active ? "On" : "Off")
        .accessibilityIdentifier("prototype-\(identifier)")
        .tint(active ? .accentColor : .primary)
    }
    private var linkURL: URL? {
        let trimmed = linkAddress.trimmingCharacters(in: .whitespaces)
        let candidate = trimmed.contains(":") ? trimmed : "https://" + trimmed
        return URL(string: candidate).flatMap { PrototypeRichDocument.isLinkable($0) ? $0 : nil }
    }
    private func openLink() {
        willEdit(); session.breakTyping()
        let (lower, upper) = PrototypeEditorSession.offsets(selection, in: text)
        linkRange = (lower, upper)
        linkInserts = lower == upper
        linkLabel = ""
        linkAddress = session.selectedLink?.absoluteString ?? ""
        linkSheet = true
    }
    private func restoreLinkRange() {
        let start = PrototypeEditorSession.index(linkRange.0, in: text), end = PrototypeEditorSession.index(linkRange.1, in: text)
        session.select(start == end ? AttributedTextSelection(insertionPoint: start) : AttributedTextSelection(range: start..<end))
    }
    private func applyLink() {
        guard let url = linkURL else { return }
        restoreLinkRange()
        session.link(url, label: linkInserts ? linkLabel : nil)
    }
}
#endif
