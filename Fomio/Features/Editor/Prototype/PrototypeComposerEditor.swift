#if DEBUG
import SwiftUI

/// Debug-only: the rich prototype as the composer body, behind the `--rich-composer` launch argument.
/// The draft stays Discourse source; every rich change is exported back to it, so drafts and posting are unchanged.
@MainActor @Observable final class PrototypeComposerModel {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--rich-composer") }

    var session: PrototypeEditorSession {
        // Exporting updates the session's document too; don't export again for that.
        didSet { if !exporting { exporting = true; export(); exporting = false } }
    }
    @ObservationIgnored private var exporting = false
    /// Asks the editor to take focus, for example after a bar button.
    private(set) var focusRequest = 0
    private var exported: String
    private let write: (String) -> Void

    /// Nil when the source holds syntax the prototype cannot edit; the standard editor is used instead.
    init?(source: String, write: @escaping (String) -> Void) {
        let session = PrototypeEditorSession(source: source)
        guard !session.value.markdown else { return nil }
        self.session = session
        exported = source
        self.write = write
    }
    func requestFocus() { focusRequest += 1 }
    /// Adopts a change made outside the editor, such as a restored template. Returns false if it is not editable here.
    func adopt(_ source: String) -> Bool {
        guard source != exported else { return true }
        let session = PrototypeEditorSession(source: source)
        guard !session.value.markdown else { return false }
        exported = source
        self.session = session
        return true
    }
    private func export() {
        guard session.syncSource(), session.value.source != exported else { return }
        exported = session.value.source
        write(exported)
    }
}

struct PrototypeComposerEditor: View {
    @Bindable var model: PrototypeComposerModel
    let label: String
    let placeholder: String
    var onFocus: () -> Void = {}
    @FocusState private var focused: Bool
    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: Binding(get: { model.session.value.text }, set: {
                model.session.editRich(PrototypePaste.native($0, context: fontContext), deferShaping: true)
                Task { @MainActor in model.session.shapePendingEdit() }
            }),
                       selection: Binding(get: { model.session.value.selection }, set: { model.session.select($0) }))
                .attributedTextFormattingDefinition(AttributedTextFormatting.EmptyDefinition<PrototypeAttributeScope>())
                .textInputFormattingControlVisibility(.hidden, for: .all)
                .scrollDisabled(true)
                .frame(minHeight: 200)
                .focused($focused)
                .overlay(alignment: .topLeading) {
                    if model.session.value.text.characters.isEmpty {
                        Text(LocalizedStringKey(placeholder)).foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(Text(LocalizedStringKey(label)))
                .accessibilityIdentifier("composer-rich-body")
            if let issue = model.session.value.document.issue {
                Label(issue, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("composer-rich-issue")
            }
        }
        .onChange(of: focused) { _, value in model.session.breakTyping(); if value { onFocus() } }
        .onChange(of: model.focusRequest) { focused = true }
    }
}

/// People matching the `@` word at the caret. Nothing shows when no one matches or the search fails: typing stays free.
struct PrototypeMentionSuggestions: View {
    @Binding var session: PrototypeEditorSession
    let search: @MainActor (String) async throws -> [MentionCandidate]
    var didEdit: () -> Void = {}
    @State private var results: [MentionCandidate] = []

    var body: some View {
        let term = session.mentionQuery?.term
        // A stack, not a Group: an empty Group has no view to run the task.
        VStack(spacing: 0) {
            if term != nil, !results.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(results) { candidate in
                            Button {
                                session.mention(candidate.username)
                                didEdit()
                            } label: {
                                HStack(spacing: 6) {
                                    Text(verbatim: "@\(candidate.username)").bold()
                                    if let name = candidate.name, !name.isEmpty { Text(verbatim: name).foregroundStyle(.secondary) }
                                }
                                .lineLimit(1).frame(minHeight: 44)
                            }
                            .accessibilityLabel(Text(verbatim: "Mention \(candidate.name ?? candidate.username), @\(candidate.username)"))
                            .accessibilityIdentifier("composer-mention-\(candidate.username)")
                        }
                    }
                }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
        }
        .task(id: term) {
            guard let term else { results = []; return }
            // Wait for a pause in typing before asking the server.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = (try? await search(term)) ?? []
            if !Task.isCancelled { results = found }
        }
    }
}

/// Replaces the composer bar while the rich prototype edits the body.
/// Two rows of 44-point controls, so every formatting action stays on screen on iPhone.
struct PrototypeComposerBar: View {
    @Bindable var model: PrototypeComposerModel
    let searchMentions: @MainActor (String) async throws -> [MentionCandidate]
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            PrototypeMentionSuggestions(session: $model.session, search: searchMentions, didEdit: model.requestFocus)
            // Scrolls only when large text no longer fits one row.
            ScrollView(.horizontal) {
                PrototypeFormattingControls(session: $model.session, didEdit: model.requestFocus)
            }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward") { model.session.undo(); model.requestFocus() }
                    .disabled(!model.session.canUndo).accessibilityIdentifier("composer-rich-undo")
                Button("Redo", systemImage: "arrow.uturn.forward") { model.session.redo(); model.requestFocus() }
                    .disabled(!model.session.canRedo).accessibilityIdentifier("composer-rich-redo")
            }.frame(minHeight: 44)
        }
        .labelStyle(.iconOnly).buttonStyle(.borderless)
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
#endif
