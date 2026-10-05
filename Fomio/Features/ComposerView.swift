import SwiftUI
import PhotosUI

struct ComposerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var phase
    @Bindable var state: ComposerState
    @State private var photos: [PhotosPickerItem] = []
    @State private var photoInsertion = EditorSelection()
    @State private var presentation: EditorPresentation?
    private enum EditorPresentation: Hashable { case link, photos, exit, retry, inserter, photo(UUID), block(ComposerBlockKind, Int, Int, String), discussion(TopicID) }
    private var navigationPresentation: Binding<EditorPresentation?> { Binding(get: { presentation.flatMap { Self.isPushed($0) ? $0 : nil } }, set: { presentation = $0 }) }
    private func presented(_ value: EditorPresentation) -> Binding<Bool> { Binding(get: { presentation == value }, set: { presentation = $0 ? value : nil }) }
    private var showExit: Bool { get { presentation == .exit } nonmutating set { presentation = newValue ? .exit : nil } }
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
    @State private var choosingCommunity = false
    @State private var turningInto = false
    /// The body has held the caret at least once, so the bar keeps its block context with the keyboard down.
    @State private var bodyEngaged = false
    /// Where + puts the next block, captured when the inserter opens.
    @State private var insertion: (location: Int, leading: String, trailing: String) = (0, "", "")
    @State private var pendingInsert: ComposerInserter.Choice?
    @State private var blockAffix: (leading: String, trailing: String)?

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
                            NativeComposerEditor(raw: $state.draft.body, controller: bodyEditor, locked: state.locked, attachmentData: { state.data(for: $0) }, attachmentCaption: { node in state.attachment(for: node).map(photoStatus) }, onBlock: { node in if let attachment = state.attachment(for: node) { suspendEditingFocus(); photoDescription = attachment.description; editingPhoto = attachment } else { openBlock(node) } }, onRemove: { node in bodyEditor.send(.replace(node.range, "")) }, onFocus: { titleEditor.blur(); focusedField = .body; bodyEngaged = true }, label: state.draft.intent.isNew ? "Opening post" : "Reply text", placeholder: state.draft.intent.isNew ? "Write the opening post" : "Write your reply")
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
                .safeAreaInset(edge: .bottom, spacing: 12) {
                    // The bar floats above the keyboard, or above the safe area once the keyboard is hidden.
                    // It stays mounted while the community list is open: rebuilding the native More menu then
                    // left the next text input without a software keyboard.
                    if !state.locked { composerBar.opacity(choosingCommunity ? 0 : 1).allowsHitTesting(!choosingCommunity).accessibilityHidden(choosingCommunity) }
                }
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
            .sheet(isPresented: presented(.inserter), onDismiss: completeInsert) {
                ComposerInserter(placement: insertionPlacement, blocks: insertableBlocks, samplePhoto: app.fixture != nil) { choice in
                    pendingInsert = choice; presentation = nil
                }
            }
            .onChange(of: state.locked) { _, locked in if locked { focusedField = nil; suspendedFocus = nil; turningInto = false } }
            .onChange(of: bodyEditor.textStyle) { _, style in if style == nil { turningInto = false } }
            .modifier(ToastHost(message: app.toastMessage, bottom: 12))
            .navigationDestination(item: navigationPresentation) { route in
                switch route {
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
                        let affix = blockAffix ?? ("", length == 0 ? "\n" : "")
                        bodyEditor.send(.replace(NSRange(location: location, length: length), affix.leading + markup + affix.trailing)); presentation = nil
                    }
                case let .discussion(id): ComposerSuggestionView(topic: id, service: app.service)
                default: EmptyView()
                }
            }
            .onChange(of: focusedField) { _, field in if field != nil { choosingCommunity = false } }
            .onChange(of: presentation) { previous, current in
                if current == nil, case .block = previous { blockAffix = nil }
                // A pushed form's keyboard would otherwise stay up across the pop, and the composer never
                // receives the keyboard safe area, leaving the bar behind the keys. Restore brings it back.
                if current == nil, let previous, Self.isPushed(previous) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                // A choice from the inserter finishes in completeInsert once the sheet is gone.
                if previous != nil && current == nil && pendingInsert == nil { restoreEditingFocus() }
            }
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
            guard !Task.isCancelled, !state.locked, app.composer?.id == state.id, !showPhotoPicker, !choosingCommunity, !showExit else { return }
            focusedField = field
            await Task.yield()
            guard focusedField == field, !state.locked, app.composer?.id == state.id else { return }
            // Select through the editor so the text view's caret moves too, not only the reported selection.
            if field == .title { titleEditor.send(.select(selection)); titleEditor.focus() }
            else { bodyEditor.send(.select(selection)); bodyEditor.focus() }
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
        CommunityField(selected: state.draft.categoryID, isOpen: $choosingCommunity, locked: state.locked, onOpen: suspendEditingFocus) { id in
            state.chooseDestination(id); restoreEditingFocus()
        }
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
    private static func isPushed(_ presentation: EditorPresentation) -> Bool {
        switch presentation { case .link, .photo, .block, .discussion: true; default: false }
    }
    // MARK: Bar
    private var barMode: ComposerBar<ComposerMoreMenu>.Mode {
        if turningInto, let style = bodyEditor.textStyle { return .turnInto(style) }
        if titleEditor.focused { return .title }
        if bodyEditor.focused && bodyEditor.selection.length > 0 { return .selection(bodyEditor.textStyle) }
        if bodyEditor.focused || bodyEngaged { return .write(bodyEditor.textStyle) }
        return .entry
    }
    private var composerBar: some View {
        ComposerBar(
            mode: barMode, editing: titleEditor.focused || bodyEditor.focused,
            bold: bodyEditor.boldTyping, italic: bodyEditor.italicTyping, canUndo: bodyEditor.canUndo, canRedo: bodyEditor.canRedo,
            canFormatInline: DiscourseMarkupCodec.supportsInlineFormatting(state.draft.body, range: bodyEditor.selection.range),
            actions: .init(
                insert: openInserter,
                openTurnInto: { turningInto = true },
                closeTurnInto: { turningInto = false },
                turnInto: { style in turningInto = false; bodyEditor.send(.style(style)); bodyEditor.focus() },
                bold: { bodyEditor.send(.bold); bodyEditor.focus() },
                italic: { bodyEditor.send(.italic); bodyEditor.focus() },
                link: openLink,
                quote: { bodyEditor.send(.style(bodyEditor.textStyle == .quote ? .paragraph : .quote)); bodyEditor.focus() },
                done: { let end = NSMaxRange(bodyEditor.selection.range); bodyEditor.send(.select(EditorSelection(NSRange(location: end, length: 0)))) },
                keyboard: toggleKeyboard,
                undo: { bodyEditor.send(.undo) },
                redo: { bodyEditor.send(.redo) }
            )
        ) { labelled in editorMenu(labelled: labelled) }
    }
    private func toggleKeyboard() {
        if titleEditor.focused || bodyEditor.focused { titleEditor.blur(); bodyEditor.blur(); focusedField = nil; return }
        // Show keyboard returns to the remembered caret: the body once written in, otherwise an empty new-topic title.
        if !bodyEngaged && state.draft.intent.isNew && state.draft.title.isEmpty { titleEditor.focus(); focusedField = .title }
        else { bodyEditor.focus(); focusedField = .body }
    }
    private func openInserter() {
        turningInto = false
        let raw = state.draft.body
        if bodyEngaged {
            let point = DiscourseMarkupCodec.blockInsertion(raw, at: bodyEditor.selection.range)
            let source = raw as NSString
            let trailing = point.location < source.length && source.character(at: point.location) != 10 ? "\n" : ""
            insertion = (point.location, point.leading, trailing)
        } else {
            let length = (raw as NSString).length
            insertion = (length, raw.isEmpty || raw.hasSuffix("\n") ? "" : "\n", "")
        }
        suspendEditingFocus()
        presentation = .inserter
    }
    /// States where the block will go, quoting the block it follows.
    private var insertionPlacement: String {
        let source = state.draft.body as NSString
        guard insertion.location > 0, insertion.location <= source.length else { return String(localized: "Adds at the start.") }
        if insertion.location == source.length && !bodyEngaged { return String(localized: "Adds at the end.") }
        let line = source.substring(to: insertion.location).trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").last ?? ""
        let text = (line as NSString).substring(from: DiscourseMarkupCodec.style(ofLine: line).prefix).trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return String(localized: "Adds at the cursor.") }
        let excerpt = text.count > 40 ? String(text.prefix(40)) + "…" : text
        return String(localized: "Adds after “\(excerpt)”")
    }
    private var insertableBlocks: [ComposerBlockKind] {
        ComposerBlockKind.allCases.filter { ![.photo, .opaque, .quote].contains($0) && app.service.composerCapabilities.blocks.contains($0) }
    }
    private func completeInsert() {
        guard let choice = pendingInsert else { return }
        pendingInsert = nil
        let at = NSRange(location: insertion.location, length: 0)
        switch choice {
        case let .text(style):
            let text = insertion.leading + style.prefix + insertion.trailing
            let caret = EditorSelection(NSRange(location: insertion.location + ((insertion.leading + style.prefix) as NSString).length, length: 0))
            bodyEditor.send(.replace(at, text)); bodyEditor.send(.select(caret))
            suspendedFocus = .body; suspendedSelection = caret
            restoreEditingFocus()
        case .photo:
            photoInsertion = EditorSelection(at); presentation = .photos
        case .samplePhoto:
            if let url = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"), let data = try? Data(contentsOf: url) {
                let previous = state.draft.body; state.addPhoto(data, at: at); bodyEditor.send(.adopt(previous, EditorSelection(at)))
            }
            restoreEditingFocus()
        case let .block(kind):
            blockAffix = (insertion.leading, insertion.trailing.isEmpty ? "\n" : insertion.trailing)
            presentation = .block(kind, insertion.location, 0, "")
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
    private func editorMenu(labelled: Bool) -> ComposerMoreMenu {
        let canFormatInline = DiscourseMarkupCodec.supportsInlineFormatting(state.draft.body, range: bodyEditor.selection.range)
        var actions: [ComposerMenuAction] = [
            .init("Bold", "bold", enabled: canFormatInline, group: "Format") { bodyEditor.send(.bold); bodyEditor.focus() },
            .init("Italic", "italic", enabled: canFormatInline, group: "Format") { bodyEditor.send(.italic); bodyEditor.focus() },
            .init("Link", "link", enabled: canFormatInline, group: "Format") { openLink() },
            .init("Emoji", "face.smiling", group: "Format") { bodyEditor.focus() }
        ]
        // Turn into stays reachable here when large text drops the type chip from the bar.
        for style in ComposerTextStyle.offered {
            actions.append(.init(style.title, style.symbol, enabled: bodyEditor.textStyle != nil, group: "Turn into") { bodyEditor.send(.style(style)); bodyEditor.focus() })
        }
        actions.append(.init("Add block…", "plus") { openInserter() })
        actions.append(.init("Add photo", "photo") { photoInsertion = bodyEditor.selection; suspendEditingFocus(); showPhotoPicker = true })
        if app.fixture != nil {
            actions.append(.init("Sample photo", "photo") {
                if let url = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"), let data = try? Data(contentsOf: url) {
                    let previous = state.draft.body; state.addPhoto(data, at: bodyEditor.selection.range); bodyEditor.send(.adopt(previous, bodyEditor.selection))
                }
            })
        }
        actions.append(.init(bodyEditor.markdown ? "Rich text" : "Edit in Markdown", "textformat") { bodyEditor.send(.markdown); bodyEditor.focus() })
        actions.append(.init("Undo", "arrow.uturn.backward", enabled: bodyEditor.canUndo) { bodyEditor.send(.undo) })
        actions.append(.init("Redo", "arrow.uturn.forward", enabled: bodyEditor.canRedo) { bodyEditor.send(.redo) })
        return ComposerMoreMenu(actions: actions, labelled: labelled, onOpen: { restoreTask?.cancel(); turningInto = false })
    }
    private func photoPicker(_ title: String, symbol: String?) -> some View {
        Button { photoInsertion = bodyEditor.selection; suspendEditingFocus(); showPhotoPicker = true } label: {
            if let symbol { Label(LocalizedStringKey(title), systemImage: symbol).frame(minHeight: 44) } else { Text(LocalizedStringKey(title)).frame(minHeight: 44) }
        }.font(.subheadline.weight(.semibold)).disabled(state.locked)
    }
}
/// The "Post in" field of a new discussion. It opens in place into a searchable list of the communities the account can post in.
struct CommunityField: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let selected: CategoryID?
    @Binding var isOpen: Bool
    let locked: Bool
    let onOpen: () -> Void
    let onPick: (CategoryID) -> Void
    @State private var query = ""
    @State private var listHeight: CGFloat = 0
    @State private var expanded: Set<CategoryID> = []
    @FocusState private var searching: Bool
    @ScaledMetric(relativeTo: .body) private var maxListHeight: CGFloat = 300
    @ScaledMetric(relativeTo: .body) private var mark: CGFloat = 28
    private struct Option: Identifiable { var community: Community; var parent: Community?; var id: CategoryID { community.id } }
    private struct OptionGroup: Identifiable { var heading: Community?; var options: [Option]; var id: CategoryID? { heading?.id ?? options.first?.id } }

    var body: some View {
        let label = selected.map(app.categoryName)
        VStack(spacing: 0) {
            if isOpen { searchHeader } else { collapsedHeader(label) }
            if isOpen {
                Divider().overlay(Color.fomioSeparator)
                list.transition(.opacity)
            }
        }
        .background(Color.fomioFill, in: .rect(cornerRadius: 14)).clipShape(.rect(cornerRadius: 14))
        .overlay { if label == nil || isOpen { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.fomioAccent, lineWidth: 1.5) } }
        .onChange(of: locked) { _, value in if value { close() } }
    }
    private func collapsedHeader(_ label: String?) -> some View {
        Button(action: open) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { collapsedParts(label) }
                VStack(alignment: .leading, spacing: 4) { collapsedParts(label) }
            }.padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(.rect)
        }.buttonStyle(.plain).disabled(locked)
        .accessibilityLabel(label.map { String(localized: "Posting in \($0). Change community") } ?? String(localized: "Choose a community, required")).accessibilityIdentifier("composer-destination")
    }
    @ViewBuilder private func collapsedParts(_ label: String?) -> some View {
        Text("Post in").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
        Text(label ?? String(localized: "Choose a community")).font(.subheadline.weight(.semibold)).foregroundStyle(label == nil ? Color.fomioSecondaryText : .primary)
        Spacer(minLength: 0)
        HStack(spacing: 4) {
            Text(LocalizedStringKey(label == nil ? "Required" : "Change"))
            Image(systemName: "chevron.down").font(.caption.weight(.bold)).accessibilityHidden(true)
        }.font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
    }
    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.fomioSecondaryText).accessibilityHidden(true)
            TextField("Search communities", text: $query)
                .focused($searching).submitLabel(.done).autocorrectionDisabled().textInputAutocapitalization(.never)
                .onSubmit { if let first = visibleOptions.first, !trimmedQuery.isEmpty { pick(first.id) } else { searching = false } }
                .onKeyPress(.escape) { close(); return .handled }
                .accessibilityIdentifier("destination-search")
            if !query.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).foregroundStyle(Color.fomioSecondaryText).frame(minWidth: 32, minHeight: 44)
            }
            Button("Close community list", systemImage: "chevron.up", action: close).labelStyle(.iconOnly).font(.subheadline.weight(.bold)).foregroundStyle(Color.fomioAccent).frame(minWidth: 32, minHeight: 44)
                .accessibilityIdentifier("destination-close")
        }.font(.subheadline).padding(.leading, 14).padding(.trailing, 8).frame(minHeight: 48)
    }
    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if trimmedQuery.isEmpty {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        let children = group.options.filter { $0.parent != nil }
                        if index > 0 { Rectangle().fill(guide).frame(height: 1).padding(.vertical, 4).accessibilityHidden(true) }
                        if let heading = group.heading {
                            // A parent the account can't post in only opens and closes its family.
                            Button { toggle(group) } label: { HStack(spacing: 0) { parentHeading(heading); disclosure(group, count: children.count) }.contentShape(.rect) }
                                .buttonStyle(.plain).accessibilityLabel(heading.name).accessibilityValue(expansionValue(group)).accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("destination-toggle-\(heading.id.rawValue)")
                        }
                        ForEach(group.options.filter { $0.parent == nil }) { parent in
                            HStack(spacing: 0) {
                                row(parent, style: .parent)
                                if !children.isEmpty {
                                    Button { toggle(group) } label: { disclosure(group, count: children.count) }.buttonStyle(.plain)
                                        .accessibilityLabel(String(localized: "Sub-communities of \(parent.community.name)")).accessibilityValue(expansionValue(group))
                                        .accessibilityIdentifier("destination-toggle-\(parent.id.rawValue)")
                                }
                            }.background(selected == parent.id ? Color.fomioSelected : .clear)
                        }
                        if let id = group.id, expanded.contains(id) {
                            // Sub-communities hang off a rail drawn from the parent's mark.
                            VStack(spacing: 0) { ForEach(children) { row($0, style: .child) } }
                                .overlay(alignment: .leading) { Capsule().fill(guide).frame(width: 2).padding(.leading, 14 + mark / 2 - 1).padding(.bottom, 10).accessibilityHidden(true) }
                                .transition(.opacity)
                        }
                    }
                    if groups.isEmpty { message(String(localized: "No community you can post in is available.")) }
                } else {
                    ForEach(visibleOptions) { row($0, style: .result) }
                    if visibleOptions.isEmpty { message(String(localized: "No community matches “\(trimmedQuery)”.")) }
                }
            }.padding(.vertical, 4)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { listHeight = $0 }
        }
        .frame(height: min(listHeight, maxListHeight)).scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.never)
    }
    private enum RowStyle { case parent, child, result }
    /// The separator token nearly vanishes on the dark fill, so hierarchy lines derive from secondary text to stay visible in both appearances.
    private var guide: Color { Color.fomioSecondaryText.opacity(0.35) }
    /// A parent the account can't post in: its mark and name label the group but can't be chosen.
    private func parentHeading(_ community: Community) -> some View {
        HStack(spacing: 12) {
            Monogram(name: community.name, size: mark)
            Text(community.name).font(.body.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
        }.padding(.leading, 14).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
    /// Sub-community count and chevron; the count tells what a closed family holds.
    private func disclosure(_ group: OptionGroup, count: Int) -> some View {
        let open = group.id.map(expanded.contains) ?? false
        return HStack(spacing: 6) {
            Text(count, format: .number).font(.footnote.weight(.medium)).foregroundStyle(Color.fomioSecondaryText)
            Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(Color.fomioAccent).rotationEffect(.degrees(open ? 180 : 0))
        }.padding(.horizontal, 14).frame(minWidth: 44, minHeight: 44).contentShape(.rect).accessibilityHidden(true)
    }
    private func expansionValue(_ group: OptionGroup) -> String {
        (group.id.map(expanded.contains) ?? false) ? String(localized: "Expanded") : String(localized: "Collapsed")
    }
    private func toggle(_ group: OptionGroup) {
        guard let id = group.id else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) } }
    }
    private func row(_ option: Option, style: RowStyle) -> some View {
        let isSelected = selected == option.id
        return Button { pick(option.id) } label: {
            HStack(spacing: 12) {
                // Parents carry their letter mark; in search results a sub-community shows its parent's, so families stay recognisable.
                if style != .child { Monogram(name: (option.parent ?? option.community).name, size: mark) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(matched(option.community.name)).font(option.parent == nil ? .body.weight(.semibold) : .body).foregroundStyle(style == .child ? AnyShapeStyle(.primary.opacity(0.8)) : AnyShapeStyle(.primary))
                    if style == .result, let parent = option.parent { Text(matched(String(localized: "in \(parent.name)"))).font(.footnote).foregroundStyle(Color.fomioSecondaryText) }
                }.multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").foregroundStyle(Color.fomioAccent).fontWeight(.semibold) }
            }
            .padding(.leading, style == .child ? 14 + mark + 12 : 14).padding(.trailing, 14).padding(.vertical, style == .child ? 6 : 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(isSelected && style != .parent ? Color.fomioSelected : .clear).contentShape(.rect)
        }.buttonStyle(.plain)
        .accessibilityLabel((option.parent.map { String(localized: "\(option.community.name), in \($0.name)") } ?? option.community.name) + (isSelected ? String(localized: ", selected") : ""))
        .accessibilityIdentifier("destination-\(option.id.rawValue)")
    }
    private func message(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
    // MARK: Data
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Only communities the account can post in; a parent it can't post in is a heading only.
    private var groups: [OptionGroup] {
        app.communities.filter { $0.parentID == nil }.compactMap { root in
            let children = app.communities.filter { $0.parentID == root.id && $0.canCreate }.map { Option(community: $0, parent: root) }
            let options = (root.canCreate ? [Option(community: root, parent: nil)] : []) + children
            return options.isEmpty ? nil : OptionGroup(heading: root.canCreate ? nil : root, options: options)
        }
    }
    /// Matches on the community or its parent's name; names starting with the query come first.
    private var visibleOptions: [Option] {
        let options = groups.flatMap(\.options)
        guard !trimmedQuery.isEmpty else { return options }
        let matches = options.filter { $0.community.name.localizedStandardContains(trimmedQuery) || ($0.parent?.name.localizedStandardContains(trimmedQuery) ?? false) }
        let leading = matches.filter { $0.community.name.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil }
        return leading + matches.filter { option in !leading.contains { $0.id == option.id } }
    }
    private func matched(_ text: String) -> AttributedString {
        var value = AttributedString(text)
        guard !trimmedQuery.isEmpty, let range = value.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) else { return value }
        value[range].inlinePresentationIntent = .stronglyEmphasized
        return value
    }
    // MARK: Actions
    private func open() {
        onOpen()
        // Families start closed; the one holding the current choice opens so it stays visible.
        expanded = Set([selected.flatMap(app.category).map { $0.parentID ?? $0.id }].compactMap { $0 })
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { isOpen = true }
    }
    private func close() {
        searching = false; query = ""
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { isOpen = false }
    }
    private func pick(_ id: CategoryID) {
        close(); onPick(id)
    }
}
