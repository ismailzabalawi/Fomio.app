import SwiftUI
import PhotosUI

struct ComposerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var phase
    @Bindable var state: ComposerState
    @State private var photos: [PhotosPickerItem] = []
    @State private var photoInsertion = EditorSelection()
    @State private var presentation: EditorPresentation?
    private enum EditorPresentation: Hashable { case destination, link, photos, exit, retry, photo(UUID), block(ComposerBlockKind, Int, Int, String), discussion(TopicID) }
    private var navigationPresentation: Binding<EditorPresentation?> { Binding(get: { switch presentation { case .destination, .link, .photo, .block, .discussion: presentation; default: nil } }, set: { presentation = $0 }) }
    private func presented(_ value: EditorPresentation) -> Binding<Bool> { Binding(get: { presentation == value }, set: { presentation = $0 ? value : nil }) }
    private var showExit: Bool { get { presentation == .exit } nonmutating set { presentation = newValue ? .exit : nil } }
    private var destinationChooser: Bool { get { presentation == .destination } nonmutating set { presentation = newValue ? .destination : nil } }
    private var showPhotoPicker: Bool { get { presentation == .photos } nonmutating set { presentation = newValue ? .photos : nil } }
    private var showLink: Bool { get { presentation == .link } nonmutating set { presentation = newValue ? .link : nil } }
    private var editingPhoto: ComposerAttachment? { get { if case let .photo(id) = presentation { return state.draft.attachments.first { $0.id == id } }; return nil } nonmutating set { presentation = newValue.map { .photo($0.id) } } }
    @State private var photoDescription = ""
    @State private var restoreTask: Task<Void, Never>?
    @State private var suspendedFocus: Field?
    @State private var titleEditor = EditorController()
    @State private var bodyEditor = EditorController()
    @State private var linkLabel = ""
    @State private var linkURL = ""
    @State private var editingLinkRange: NSRange?

    @State private var suspendedSelection = EditorSelection()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Field: Hashable { case title, body }
    private enum Recovery: Hashable { case rejection, authorization, unconfirmed, pending, missingPhoto, photo, error }
    @State private var focusedField: Field?
    @AccessibilityFocusState private var recoveryFocus: Recovery?
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    ReadingColumn {
                        VStack(alignment: .leading, spacing: 16) {
                            statusCards
                            if state.draft.intent.isNew { destinationRow } else { replyContext }
                            if state.draft.intent.isNew {
                                NativeComposerEditor(raw: $state.draft.title, controller: titleEditor, isTitle: true, locked: state.locked, onNext: { titleEditor.blur(); bodyEditor.focus(); focusedField = .body }, onFocus: { bodyEditor.blur(); focusedField = .title }, identifier: "composer-title", label: "Title", placeholder: "Title")
                                Divider().overlay(Color.fomioSeparator)
                            }
                            NativeComposerEditor(raw: $state.draft.body, controller: bodyEditor, locked: state.locked, attachmentData: { state.data(for: $0) }, attachmentCaption: { node in state.attachment(for: node).map(photoStatus) }, onBlock: { node in if let attachment = state.attachment(for: node) { suspendEditingFocus(); photoDescription = attachment.description; editingPhoto = attachment } else { openBlock(node) } }, onRemove: { node in bodyEditor.send(.replace(node.range, "")) }, onFocus: { titleEditor.blur(); focusedField = .body }, label: state.draft.intent.isNew ? "Opening post" : "Reply text", placeholder: state.draft.intent.isNew ? "Write the opening post" : "Write your reply")
                            if !state.suggestions.isEmpty {
                                DisclosureGroup("Similar discussions") {
                                    ForEach(state.suggestions) { topic in Button(topic.title) { if state.save() { suspendEditingFocus(); presentation = .discussion(topic.id) } }.frame(minHeight: 44) }
                                }
                            }
                            ForEach(state.previews.values.sorted { $0.url.absoluteString < $1.url.absoluteString }, id: \.url) { preview in
                                VStack(alignment: .leading, spacing: 4) { Text(preview.title).font(.headline); Text(preview.summary).font(.subheadline); Text(preview.url.host ?? "").font(.caption) }.padding(12).background(Color.fomioFill, in: .rect(cornerRadius: 12))
                            }
                            ForEach(state.draft.activeAttachments) { attachment in photoStatusRow(attachment) }
                            if state.saveStatus == "Couldn’t save on this device" { Label(LocalizedStringKey(state.saveStatus), systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("draft-save-status") }
                            if let error = state.error { Text(error).font(.subheadline).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("composer-error").id(Recovery.error).accessibilityFocused($recoveryFocus, equals: .error) }
                        }.padding(20)
                    }
                }.background(Color.fomioBackground).scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) { accessoryBar }
                .task(id: recoveryTarget) {
                    guard let target = recoveryTarget else { return }
                    focusedField = nil; titleEditor.blur(); bodyEditor.blur()
                    await Task.yield()
                    guard !Task.isCancelled, recoveryTarget == target else { return }
                    if reduceMotion { proxy.scrollTo(target, anchor: .top) }
                    else { withAnimation { proxy.scrollTo(target, anchor: .top) } }
                    recoveryFocus = target
                }
            }
            .navigationTitle(state.draft.intent.isNew ? "New discussion" : "Reply").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if navigationPresentation.wrappedValue == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { close() }.disabled(state.draft.submission == .submitting).accessibilityIdentifier("composer-close").keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state.draft.submission == .submitting { ProgressView().accessibilityLabel("Posting") }
                    else { Button("Post") { focusedField = nil; titleEditor.blur(); bodyEditor.blur(); Task { await state.submit() } }.buttonStyle(.glassProminent).disabled(!state.canPost).accessibilityIdentifier("composer-post").keyboardShortcut(.return, modifiers: .command) }
                }
            }
            }
            .background(ComposerDismissGuard(blocked: state.hasChanges, submitting: state.draft.submission == .submitting, onAttempt: { close() }).frame(width: 0, height: 0))
            .confirmationDialog(keepTitle, isPresented: presented(.exit), titleVisibility: .visible) {
                Button(state.photoWillBeLost && state.photoUnfinished ? "Keep draft without photo" : "Keep draft") { state.keepDraft() }
                Button(state.resumed ? "Discard draft" : "Discard", role: .destructive) { state.discard() }
                Button("Keep editing") { showExit = false; restoreEditingFocus() }.accessibilityIdentifier("composer-keep-editing")
            } message: { if let warning = keepPhotoWarning { Text(warning) } }
            .alert("Post again?", isPresented: presented(.retry)) {
                Button("Cancel", role: .cancel) {}
                Button("Post again") { Task { await state.postAgain() } }
            } message: { Text("If your first \(state.noun) went through, this will create a duplicate.") }
            .photosPicker(isPresented: presented(.photos), selection: $photos, matching: .images)
                        .onChange(of: state.locked) { _, locked in if locked { focusedField = nil; suspendedFocus = nil } }
            .modifier(ToastHost(message: app.toastMessage, bottom: focusedField == nil ? 72 : 12))
            .navigationDestination(item: navigationPresentation) { route in
                switch route {
                case .destination: DestinationChooser(selected: state.draft.categoryID) { state.chooseDestination($0); presentation = nil }
                case .link:
                    Form {
                        TextField("Text", text: $linkLabel)
                        TextField("URL", text: $linkURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }.navigationTitle("Link")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Insert") { if let range = editingLinkRange { bodyEditor.send(.replace(range, DiscourseMarkupCodec.link(label: linkLabel, url: linkURL))) } else { bodyEditor.send(.link(linkLabel, linkURL)) }; presentation = nil }.disabled(URL(string: linkURL)?.scheme.map { !["https", "http"].contains($0) } ?? true) } }
                case let .photo(id):
                    Form { TextField("Image description", text: $photoDescription, axis: .vertical) }.navigationTitle("Photo")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        if let node = DiscourseMarkupCodec.parse(state.draft.body).first(where: { state.attachment(for: $0)?.id == id }), let index = state.draft.attachments.firstIndex(where: { $0.id == id }) {
                            var changed = state.draft.attachments[index]; changed.description = photoDescription
                            bodyEditor.send(.replace(node.range, changed.markup)); state.draft.attachments[index].description = photoDescription
                        }; presentation = nil
                    } } }
                case let .block(kind, location, length, raw):
                    ComposerBlockForm(value: DiscourseMarkupCodec.parse(raw).first.flatMap(ComposerBlockValue.editing) ?? ComposerBlockValue(kind: kind), maximumOptions: app.service.composerCapabilities.maximumPollOptions) { markup in
                        bodyEditor.send(.replace(NSRange(location: location, length: length), markup + (length == 0 ? "\n" : ""))); presentation = nil
                    }
                case let .discussion(id): ComposerSuggestionView(topic: id, service: app.service)
                default: EmptyView()
                }
            }
            .onChange(of: presentation) { previous, current in if previous != nil && current == nil { restoreEditingFocus() } }
            .onChange(of: state.draft.title) { state.edited() }
            .onChange(of: state.draft.body) { state.edited() }
            .onChange(of: phase) { _, value in if value != .active && state.hasChanges { state.save() } }
            .onChange(of: photos) { _, items in
                Task {
                    var insertion = photoInsertion.range
                    for item in items {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) {
                                let previous = state.draft.body
                                let before = (previous as NSString).length
                                state.addPhoto(jpeg, at: insertion)
                                bodyEditor.send(.adopt(previous, EditorSelection(insertion)))
                                insertion = NSRange(location: insertion.location + (state.draft.body as NSString).length - before, length: 0)
                            }
                        } catch { state.error = "Could not read the selected photo. Your writing is kept." }
                    }
                    photos = []
                }
            }
        }
    }
    private func close() {
        suspendEditingFocus()
        if state.locked { state.keepDraft(message: state.draft.submission == .unconfirmed ? "Kept as a draft. Check the discussion before posting again." : nil) }
        else if state.hasChanges { showExit = true }
        else { state.close() }
    }
    // Recovery changes reveal the relevant message without stealing focus during ordinary autosave or upload progress.
    private var recoveryTarget: Recovery? {
        if state.rejection != nil { return .rejection }
        if state.expired { return .authorization }
        if state.draft.submission == .unconfirmed { return .unconfirmed }
        if state.draft.submission == .pending { return .pending }
        if state.error != nil { return .error }
        if state.draft.missingPhoto && state.photoData == nil { return .missingPhoto }

        return nil
    }
    private func suspendEditingFocus() {
        restoreTask?.cancel(); restoreTask = nil
        suspendedFocus = titleEditor.focused ? .title : bodyEditor.focused ? .body : nil
        suspendedSelection = titleEditor.focused ? titleEditor.selection : bodyEditor.selection
        titleEditor.blur(); bodyEditor.blur()
        focusedField = nil
    }
    private func restoreEditingFocus() {
        let field = suspendedFocus
        let selection = suspendedSelection
        suspendedFocus = nil
        suspendedSelection = EditorSelection()
        guard let field, !state.locked, app.composer?.id == state.id else { return }
        // UIKit finishes dismissing the dialog before restoring the first responder.
        restoreTask?.cancel()
        restoreTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, !state.locked, app.composer?.id == state.id, !showPhotoPicker, !destinationChooser, !showExit else { return }
            focusedField = field
            await Task.yield()
            guard focusedField == field, !state.locked, app.composer?.id == state.id else { return }
            if field == .title { titleEditor.selection = selection; titleEditor.focus() }
            else { bodyEditor.selection = selection; bodyEditor.focus() }
        }
    }
    private var keepTitle: String { state.resumed ? String(localized: "You changed this draft.") : String(localized: "Keep this \(state.noun) as a draft?") }
    private var keepPhotoWarning: String? {
        guard state.photoWillBeLost && state.photoUnfinished else { return nil }
        let kept = state.draft.intent.isNew ? "title, text and community" : "text"
        if case .uploading = state.uploadState { return "The photo is still uploading. Keeping the draft stops the upload and the photo won’t be kept. Your \(kept) will be kept." }
        return "The photo didn’t upload, so it won’t be kept. Your \(kept) will be kept."
    }
    // MARK: Context
    private var destinationRow: some View {
        let label = state.draft.categoryID.map(app.categoryName)
        return Button { suspendEditingFocus(); destinationChooser = true } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { destinationParts(label) }
                VStack(alignment: .leading, spacing: 4) { destinationParts(label) }
            }.padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.fomioFill, in: .rect(cornerRadius: 14))
            .overlay { if label == nil { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.fomioAccent, lineWidth: 1.5) } }
            .contentShape(.rect)
        }.buttonStyle(.plain).disabled(state.locked)
        .accessibilityLabel(label.map { String(localized: "Posting in \($0). Change community") } ?? String(localized: "Choose a community, required")).accessibilityIdentifier("composer-destination")
    }
    @ViewBuilder private func destinationParts(_ label: String?) -> some View {
        Text("Post in").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
        Text(label ?? String(localized: "Choose a community")).font(.subheadline.weight(.semibold)).foregroundStyle(label == nil ? Color.fomioSecondaryText : .primary)
        Spacer(minLength: 0)
        Text(LocalizedStringKey(label == nil ? "Required" : "Change")).font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
    }
    @ViewBuilder private var replyContext: some View {
        if case let .reply(topic, parent) = state.draft.intent {
            let category = state.draft.contextCategory.map(app.categoryName)
            let sub = state.draft.quote.map { String(localized: "Quoting \($0.author) · #\($0.number.rawValue)") }
                ?? state.draft.targetAuthor.map { String(localized: "Replying to \($0) · #\(parent?.rawValue ?? 0)") }
                ?? String(localized: "Replying to the discussion") + (category.map { " · \($0)" } ?? "")
            VStack(alignment: .leading, spacing: 3) {
                Text(sub).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                Text(state.draft.contextTitle ?? String(localized: "Discussion \(topic.rawValue)")).font(.subheadline.weight(.semibold)).lineLimit(2)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 12)).accessibilityElement(children: .combine)
        }
    }
    // MARK: States
    @ViewBuilder private var statusCards: some View {
        if let message = state.rejection {
            alertCard(symbol: "exclamationmark.triangle.fill", tint: .fomioDanger) {
                Text("Couldn't post").font(.headline).accessibilityFocused($recoveryFocus, equals: .rejection)
                Text(message).font(.subheadline)
                Text("Your writing is kept. Edit and try again.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            }.id(Recovery.rejection)
        }
        if state.expired {
            alertCard(symbol: "person.crop.circle.badge.exclamationmark", tint: .fomioAccent) {
                Text("You've been signed out").font(.headline).accessibilityFocused($recoveryFocus, equals: .authorization)
                Text("Sign in again to post. Your \(state.noun) stays here and won't be sent automatically.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                Button("Sign in") { suspendEditingFocus(); state.suspendForAuthentication() }.buttonStyle(.glassProminent).frame(minHeight: 44)
            }.id(Recovery.authorization)
        }
        if app.isOffline && !state.locked {
            Text("\(Text("You're offline.").bold()) Keep writing. Post works again once you're back online; nothing is sent automatically.")
                .font(.subheadline).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
        }
        if state.draft.submission == .unconfirmed {
            alertCard(symbol: "questionmark.circle.fill", tint: .fomioAccent) {
                Text("We couldn't confirm whether your \(state.noun) posted").font(.headline).accessibilityFocused($recoveryFocus, equals: .unconfirmed)
                Text("Our check didn't find it yet. That doesn't mean it failed. Your text is kept here.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack { unconfirmedActions }
                    VStack(alignment: .leading) { unconfirmedActions }
                }
                Divider()
                Text("Posting again could create a duplicate if the first one went through.").font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                Button("Post again…") { presentation = .retry }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.id(Recovery.unconfirmed)
        }
        if state.draft.submission == .pending {
            alertCard(symbol: "clock", tint: .fomioAccent) {
                Text("Submitted for review").font(.headline).accessibilityFocused($recoveryFocus, equals: .pending)
                Text("Your \(state.noun) isn’t published yet. This local record stays locked so it can’t be posted twice.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            }.id(Recovery.pending)
        }
        if state.draft.missingPhoto && state.photoData == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photo not kept").font(.headline).accessibilityFocused($recoveryFocus, equals: .missingPhoto)
                Text("It hadn’t finished uploading. \(state.draft.intent.isNew ? "Title, text and community are restored." : "Your text is restored.")").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { lostPhotoActions }
                    VStack(alignment: .leading, spacing: 0) { lostPhotoActions }
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioSelected, in: .rect(cornerRadius: 14)).id(Recovery.missingPhoto)
        }
    }
    @ViewBuilder private var unconfirmedActions: some View {
        Button("Check again") { Task { await state.checkAgain() } }.buttonStyle(.glassProminent).disabled(state.checking).frame(minHeight: 44)
        Button(state.draft.intent.isNew ? "Keep as draft" : "Back to discussion") { state.keepDraft(message: "Kept as a draft. Check the discussion before posting again.") }.buttonStyle(.bordered).frame(minHeight: 44)
    }
    @ViewBuilder private var lostPhotoActions: some View {
        photoPicker("Add photo again", symbol: nil)
        Button("Continue without photo") { state.removePhoto() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
    }
    private func alertCard<Content: View>(symbol: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) { content() }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14)).accessibilityElement(children: .contain)
    }
    // MARK: Photo
    private func photoStatus(_ attachment: ComposerAttachment) -> String {
        switch attachment.status {
        case .retained: String(localized: "Photo kept on this device. Resume upload to post.")
        case .queued: String(localized: "Waiting to upload")
        case let .uploading(value): String(localized: "Uploading photo · \(Int(value * 100))%")
        case let .failed(message): String(localized: "Photo didn’t upload. \(message)")
        case .uploaded: String(localized: "Photo attached")
        case .missing: String(localized: "Photo file unavailable. Remove it or select it again.")
        }
    }
    private func photoStatusRow(_ attachment: ComposerAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(photoStatus(attachment))).font(.subheadline).accessibilityAddTraits(.updatesFrequently)
            HStack {
                switch attachment.status {
                case .retained, .failed: Button(LocalizedStringKey(attachment.status == .retained ? "Resume upload" : "Retry upload")) { state.retryPhoto(attachment.id) }.frame(minHeight: 44)
                default: EmptyView()
                }
                Button("Remove photo") {
                    if let node = DiscourseMarkupCodec.parse(state.draft.body).first(where: { state.attachment(for: $0)?.id == attachment.id }) { bodyEditor.send(.replace(node.range, "")) }
                }.frame(minHeight: 44)
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 12))
    }
    @ViewBuilder private var accessoryBar: some View {
        if !state.locked {
            HStack {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        Button("Bold", systemImage: "bold") { bodyEditor.send(.bold); bodyEditor.focus() }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        Button("Italic", systemImage: "italic") { bodyEditor.send(.italic); bodyEditor.focus() }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        Button("Link", systemImage: "link") { openLink() }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        photoPicker("Add photo", symbol: "photo")
                    }
                    Color.clear.frame(width: 0, height: 44)
                }
                Spacer(minLength: 0)
                editorMenu
            }.padding(.horizontal, 20).padding(.vertical, 4).background(.bar)
        }
    }
    private func openBlock(_ node: MarkupNode) {
        guard node.kind == .quote || node.kind.map({ app.service.composerCapabilities.blocks.contains($0) }) == true, ComposerBlockValue.editing(node) != nil else { bodyEditor.send(.select(EditorSelection(node.range))); if !bodyEditor.markdown { bodyEditor.send(.markdown) }; bodyEditor.focus(); return }
        suspendEditingFocus(); presentation = .block(node.kind ?? .opaque, node.range.location, node.range.length, node.raw)
    }
    private func openLink() {
        suspendEditingFocus()
        editingLinkRange = nil; linkLabel = ""; linkURL = ""
        let selection = bodyEditor.selection.range
        if let node = DiscourseMarkupCodec.parse(state.draft.body).first(where: { $0.link != nil && selection.location >= $0.range.location && NSMaxRange(selection) <= NSMaxRange($0.range) }) {
            editingLinkRange = node.range; linkLabel = node.text; linkURL = node.link ?? ""
        } else if selection.length > 0, let range = Range(selection, in: state.draft.body) { linkLabel = String(state.draft.body[range]) }
        showLink = true
    }
    private var editorMenu: some View {
        var actions: [ComposerMenuAction] = [
            .init("Bold", "bold", group: "Format") { bodyEditor.send(.bold); bodyEditor.focus() },
            .init("Italic", "italic", group: "Format") { bodyEditor.send(.italic); bodyEditor.focus() },
            .init("Link", "link", group: "Format") { openLink() },
            .init("Quote", "text.quote", group: "Format") { bodyEditor.send(.quote); bodyEditor.focus() },
            .init("Bulleted list", "list.bullet", group: "Format") { bodyEditor.send(.list); bodyEditor.focus() },
            .init("Emoji", "face.smiling", group: "Format") { bodyEditor.focus() },
            .init("Add photo", "photo") { suspendEditingFocus(); showPhotoPicker = true }
        ]
        if app.fixture != nil {
            actions.append(.init("Sample photo", "photo") {
                if let url = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"), let data = try? Data(contentsOf: url) {
                    let previous = state.draft.body; state.addPhoto(data, at: bodyEditor.selection.range); bodyEditor.send(.adopt(previous, bodyEditor.selection))
                }
            })
        }
        for kind in ComposerBlockKind.allCases where app.service.composerCapabilities.blocks.contains(kind) {
            actions.append(.init(kind.title, "square.and.pencil", group: "Insert block") { suspendEditingFocus(); presentation = .block(kind, bodyEditor.selection.location, bodyEditor.selection.length, "") })
        }
        actions.append(.init(bodyEditor.markdown ? "Rich text" : "Edit in Markdown", "textformat") { bodyEditor.send(.markdown); bodyEditor.focus() })
        actions.append(.init("Undo", "arrow.uturn.backward", enabled: bodyEditor.canUndo) { bodyEditor.send(.undo) })
        actions.append(.init("Redo", "arrow.uturn.forward", enabled: bodyEditor.canRedo) { bodyEditor.send(.redo) })
        return ComposerMoreMenu(actions: actions, onOpen: { restoreTask?.cancel() }).fixedSize().frame(minWidth: 44, minHeight: 44)
    }
    private func photoPicker(_ title: String, symbol: String?) -> some View {
        Button { photoInsertion = bodyEditor.selection; suspendEditingFocus(); showPhotoPicker = true } label: {
            if let symbol { Label(LocalizedStringKey(title), systemImage: symbol).frame(minHeight: 44) } else { Text(LocalizedStringKey(title)).frame(minHeight: 44) }
        }.font(.subheadline.weight(.semibold)).disabled(state.locked)
    }
}
struct DestinationChooser: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let selected: CategoryID?
    let onPick: (CategoryID) -> Void
    var body: some View {
        List {
                // Only communities the account can post in; a non-postable parent is a heading only.
                ForEach(app.communities.filter { root in root.parentID == nil && (root.canCreate || app.communities.contains { $0.parentID == root.id && $0.canCreate }) }) { root in
                    Section {
                        if root.canCreate { row(root, parent: nil) }
                        ForEach(app.communities.filter { $0.parentID == root.id && $0.canCreate }) { row($0, parent: root) }
                    } header: { if !root.canCreate { Text(root.name) } }
                }
            }.navigationTitle("Choose a community").navigationBarTitleDisplayMode(.inline)

    }
    private func row(_ category: Community, parent: Community?) -> some View {
        Button { onPick(category.id); dismiss() } label: {
            HStack {
                Text(category.name).font(parent == nil ? .body.weight(.semibold) : .body).foregroundStyle(.primary).padding(.leading, parent == nil ? 0 : 16).multilineTextAlignment(.leading)
                Spacer()
                if selected == category.id { Image(systemName: "checkmark").foregroundStyle(Color.fomioAccent).fontWeight(.semibold) }
            }.frame(minHeight: 44).contentShape(.rect)
        }.buttonStyle(.plain)
        .accessibilityLabel((parent.map { "\(category.name), in \($0.name)" } ?? category.name) + (selected == category.id ? ", selected" : ""))
        .accessibilityIdentifier("destination-\(category.id.rawValue)")
    }
}
