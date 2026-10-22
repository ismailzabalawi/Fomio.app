#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

/// An isolated, memory-only experiment. It has no repository, draft store or Post action.
struct SwiftUIRichComposerPrototype: View {
    static let sample = "مرحبا **بالعالم** 👋🏽\n\nHello *Fomio* — family 👨‍👩‍👧‍👦 and ~~old text~~.\nEscaped: \\*literal\\*"
    @State private var session = PrototypeEditorSession(source: sample)
    @State private var pasteNotice: String?
    @State private var pasteTask: Task<Void, Never>?
    @State private var pasteToken = UUID()
    @State private var pendingPlainPaste: [NSItemProvider] = []
    @State private var pendingTarget: PrototypeEditorSession.PasteTarget?
    private var document: PrototypeRichDocument { session.value.document }
    private var text: AttributedString { session.value.text }
    private var selection: AttributedTextSelection { session.value.selection }
    private var source: String { session.value.source }
    private var markdown: Bool { session.value.markdown }
    @FocusState private var focused: Bool
    @Environment(\.fontResolutionContext) private var fontContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Local experiment · writing is cleared when this session ends")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Editing mode", selection: modeBinding) {
                    Text("Rich text").tag(false)
                    Text("Markdown").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("prototype-mode")
                if let issue = document.issue {
                    Text(issue).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("prototype-issue")
                }
                historyBar
                if let pasteNotice {
                    Text(pasteNotice).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("prototype-paste-notice")
                }
                if !pendingPlainPaste.isEmpty {
                    Button("Paste plain text instead") {
                        guard pendingTarget == session.pasteTarget else {
                            clearPendingPaste(); pasteNotice = "Paste canceled because the document changed. Paste again at the new selection."; return
                        }
                        paste(pendingPlainPaste, plainText: true)
                    }.accessibilityIdentifier("prototype-paste-plain")
                }
                if markdown {
                    TextEditor(text: sourceBinding, selection: sourceSelectionBinding)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .focused($focused)
                        .accessibilityLabel("Prototype Markdown")
                        .accessibilityIdentifier("prototype-markdown")
                } else if document.projection != nil {
                    TextEditor(text: richBinding, selection: selectionBinding)
                        .attributedTextFormattingDefinition(AttributedTextFormatting.EmptyDefinition<PrototypeAttributeScope>())
                        .textInputFormattingControlVisibility(.hidden, for: .all)
                        .focused($focused)
                        .accessibilityLabel("Prototype rich text")
                        .accessibilityIdentifier("prototype-rich")
                } else {
                    ScrollView { Text(source).font(.body.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    Button("Edit in Markdown") { changeMode(true) }
                        .buttonStyle(.borderedProminent)
                }
                if !markdown && document.projection != nil { formattingBar }
                else { HStack { Spacer(minLength: 0); hideKeyboardButton }.buttonStyle(.bordered) }
            }
            .onChange(of: focused) { _, _ in session.breakTyping() }
            .onDisappear { pasteTask?.cancel() }
            .padding().frame(maxWidth: 720).frame(maxWidth: .infinity)
            .navigationTitle("Rich text prototype")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Samples", systemImage: "doc.text") {
                        Button("Arabic and emoji") { load(Self.sample) }
                        Button("Plain text") { load("Write here…") }
                        Button("Preserved Discourse block") { load("[poll]\n* نعم 😀\n* No\n[/poll]") }
                    }.accessibilityIdentifier("prototype-samples")
                }
            }
        }
    }

    private var formattingBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) {
                    HStack { formatButtons }
                    HStack { selectAllButton; Spacer(minLength: 0); hideKeyboardButton }
                }
            } else {
                HStack { formatButtons; Spacer(minLength: 0); selectAllButton; hideKeyboardButton }
            }
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
    }
    // Keep dismissal in the editor's layout, rather than adding a separately
    // measured SwiftUI keyboard accessory row during responder transitions.
    private var hideKeyboardButton: some View {
        Button { focused = false } label: {
            Image(systemName: "keyboard.chevron.compact.down").frame(minWidth: 32, minHeight: 32)
        }
        .accessibilityLabel("Hide keyboard")
        .accessibilityIdentifier("prototype-hide-keyboard")
        .disabled(!focused)
    }
    @ViewBuilder private var formatButtons: some View {
        formatButton("Bold", symbol: "bold", mark: .bold)
        formatButton("Italic", symbol: "italic", mark: .italic)
        formatButton("Strikethrough", symbol: "strikethrough", mark: .strike)
    }
    private var selectAllButton: some View {
        Button("Select all") {
            cancelPaste(); session.breakTyping()
            session.select(AttributedTextSelection(range: text.startIndex..<text.endIndex))
            focused = true
        }.accessibilityIdentifier("prototype-select-all")
    }
    private func isActive(_ mark: PrototypeMarks) -> Bool {
        let values = Array(selection.attributes(in: text))
        return !values.isEmpty && values.allSatisfy { ($0[PrototypeMarksAttribute.self] ?? []).contains(mark) }
    }
    private func formatButton(_ title: String, symbol: String, mark: PrototypeMarks) -> some View {
        Button {
            cancelPaste()
            session.format(mark)
            focused = true
        } label: { Image(systemName: symbol).frame(minWidth: 32, minHeight: 32) }
        .accessibilityLabel(title)
        .accessibilityValue(isActive(mark) ? "On" : "Off")
        .accessibilityIdentifier("prototype-\(title.lowercased())")
        .tint(isActive(mark) ? .accentColor : .primary)
    }
    private var historyBar: some View {
        HStack {
            Button { restore(redo: false) } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!session.canUndo).accessibilityIdentifier("prototype-undo")
                .accessibilityLabel(session.canUndo ? "Undo \(session.undoName)" : "Undo")
                .keyboardShortcut("z", modifiers: .command)
            Button { restore(redo: true) } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!session.canRedo).accessibilityIdentifier("prototype-redo")
                .accessibilityLabel(session.canRedo ? "Redo \(session.redoName)" : "Redo")
                .keyboardShortcut("z", modifiers: [.command, .shift])
            Spacer(minLength: 0)
            PasteButton(supportedContentTypes: PrototypePaste.supportedTypes) {
                paste($0, plainText: markdown)
            }.accessibilityIdentifier("prototype-paste")
        }.labelStyle(.iconOnly).buttonStyle(.bordered)
    }
    private var richBinding: Binding<AttributedString> {
        Binding(get: { text }, set: { session.editRich(PrototypePaste.native($0, context: fontContext)) })
    }
    private var sourceBinding: Binding<String> {
        Binding(get: { source }, set: { session.editSource($0) })
    }
    private var selectionBinding: Binding<AttributedTextSelection> {
        Binding(get: { selection }, set: {
            if $0.indices(in: text) != selection.indices(in: text) { clearPendingPaste() }
            session.select($0)
        })
    }
    private var sourceSelectionBinding: Binding<TextSelection?> {
        Binding(get: { session.value.sourceSelection }, set: {
            if $0?.indices != session.value.sourceSelection?.indices { clearPendingPaste() }
            session.selectSource($0)
        })
    }
    private var modeBinding: Binding<Bool> { Binding(get: { markdown }, set: changeMode) }
    private func changeMode(_ wantsMarkdown: Bool) {
        guard markdown != wantsMarkdown else { return }
        cancelPaste(); focused = false
        session.changeMode(wantsMarkdown)
    }
    private func load(_ sample: String) {
        cancelPaste(); focused = false
        session.load(sample)
    }
    private func restore(redo: Bool) {
        cancelPaste()
        let previousMode = markdown
        if redo { session.redo() } else { session.undo() }
        if previousMode != markdown { focused = false }
    }
    private func clearPendingPaste() {
        pendingPlainPaste = []; pendingTarget = nil
    }
    private func cancelPaste() {
        pasteTask?.cancel(); pasteToken = UUID()
        clearPendingPaste(); pasteNotice = nil
    }
    private func paste(_ providers: [NSItemProvider], plainText: Bool) {
        cancelPaste(); session.breakTyping()
        let target = session.pasteTarget
        let token = pasteToken
        pasteNotice = "Reading clipboard…"
        pasteTask = Task { @MainActor in
            do {
                let content = try await PrototypePaste.read(providers, plainText: plainText)
                guard !Task.isCancelled, token == pasteToken else { return }
                guard session.paste(content.text, at: target) else {
                    pasteNotice = "Paste canceled because the document or selection changed. Paste again."; return
                }
                pasteNotice = content.notice
            } catch {
                guard !Task.isCancelled, token == pasteToken else { return }
                pasteNotice = (error as? PrototypePaste.Failure)?.errorDescription ?? "This clipboard content could not be read. Nothing was inserted."
                if !plainText, target == session.pasteTarget,
                   providers.allSatisfy({ $0.canLoadObject(ofClass: NSString.self) }) {
                    pendingPlainPaste = providers; pendingTarget = target
                }
            }
        }
    }

}

#Preview("SwiftUI rich composer experiment") {
    SwiftUIRichComposerPrototype()
}
#endif
