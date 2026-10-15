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
                                NativeComposerEditor(raw: $state.draft.title, controller: titleEditor, isTitle: true, locked: state.locked, onNext: { bodyEditor.focus(); focusedField = .body }, onFocus: { bodyEditor.blur(); focusedField = .title }, identifier: "composer-title", label: L("composer.title_field"), placeholder: L("composer.title_field"))
                                Divider().overlay(Color.fomioSeparator)
                            }
                            NativeComposerEditor(raw: $state.draft.body, controller: bodyEditor, locked: state.locked, attachmentData: { state.data(for: $0) }, attachmentCaption: { node in state.attachment(for: node).map(photoStatus) }, onBlock: { node in if let attachment = state.attachment(for: node) { suspendEditingFocus(); photoDescription = attachment.description; editingPhoto = attachment } else { openBlock(node) } }, onRemove: { node in bodyEditor.send(.replace(node.range, "")) }, onFocus: { titleEditor.blur(); focusedField = .body; bodyEngaged = true }, label: state.draft.intent.isNew ? L("composer.body.opening_label") : L("composer.body.reply_label"), placeholder: state.draft.intent.isNew ? L("composer.body.opening_placeholder") : L("composer.body.reply_placeholder"))
                            if !state.suggestions.isEmpty {
                                DisclosureGroup(L("composer.similar")) {
                                    ForEach(state.suggestions) { topic in Button(topic.title) { if state.save() { suspendEditingFocus(); presentation = .discussion(topic.id) } }.frame(minHeight: 44) }
                                }
                            }
                            ForEach(state.previews.values.sorted { $0.url.absoluteString < $1.url.absoluteString }, id: \.url) { preview in
                                VStack(alignment: .leading, spacing: 4) { Text(preview.title).font(.headline); Text(preview.summary).font(.subheadline); Text(preview.url.host ?? "").font(.caption) }.padding(12).background(Color.fomioFill, in: .rect(cornerRadius: 12))
                            }
                            ForEach(state.draft.activeAttachments) { attachment in photoStatusRow(attachment) }
                            if state.saveStatus == .failed { Label(L("composer.save.failed"), systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("draft-save-status") }
                            if let error = state.error { Text(error.text).font(.subheadline).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("composer-error").id(Recovery.error).accessibilityFocused($recoveryFocus, equals: .error) }
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
            .navigationTitle(state.draft.intent.isNew ? L("composer.new_discussion") : L("post.reply")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if navigationPresentation.wrappedValue == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel"), systemImage: "xmark") { close() }.disabled(state.draft.submission == .submitting).accessibilityIdentifier("composer-close").keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state.draft.submission == .submitting { ProgressView().accessibilityLabel(L("composer.posting")) }
                    else { Button(L("composer.post")) { focusedField = nil; titleEditor.blur(); bodyEditor.blur(); Task { await state.submit() } }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).disabled(!state.canPost).accessibilityIdentifier("composer-post").keyboardShortcut(.return, modifiers: .command) }
                }
            }
            }
            .background(ComposerDismissGuard(blocked: state.hasChanges, submitting: state.draft.submission == .submitting, onAttempt: { close() }).frame(width: 0, height: 0))
            .confirmationDialog(keepTitle, isPresented: presented(.exit), titleVisibility: .visible) {
                Button(state.photoWillBeLost && state.photoUnfinished ? L("composer.keep_draft_without_photo") : L("composer.keep_draft")) { state.keepDraft() }
                Button(state.resumed ? L("composer.discard_draft") : L("composer.discard"), role: .destructive) { state.discard() }
                Button(L("composer.keep_editing")) { showExit = false; restoreEditingFocus() }.accessibilityIdentifier("composer-keep-editing")
            } message: { if let warning = keepPhotoWarning { Text(warning) } }
            .alert(L("composer.retry.title"), isPresented: presented(.retry)) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("composer.retry.action")) { Task { await state.postAgain() } }
            } message: { Text(state.draft.intent.isNew ? L("composer.retry.message.discussion") : L("composer.retry.message.reply")) }
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
                        TextField(L("composer.link.text"), text: $linkLabel)
                        TextField(L("composer.link.url"), text: $linkURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }.navigationTitle(L("composer.link"))
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("composer.insert")) { if let range = editingLinkRange { bodyEditor.send(.replace(range, DiscourseMarkupCodec.link(label: linkLabel, url: linkURL))) } else { bodyEditor.send(.link(linkLabel, linkURL)) }; presentation = nil }.disabled(URL(string: linkURL)?.scheme.map { !["https", "http"].contains($0) } ?? true) } }
                case let .photo(id):
                    Form { TextField(L("composer.photo.description"), text: $photoDescription, axis: .vertical) }.navigationTitle(L("composer.photo"))
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("common.save")) {
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
                        } catch { state.error = .key("composer.photo.read_failed") }
                    }
                    photos = []
                }
            }
        }
    }
    private func close() {
        suspendEditingFocus()
        if state.locked { state.keepDraft(message: state.draft.submission == .unconfirmed ? L("composer.kept_unconfirmed") : nil) }
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
    private var keepTitle: String { state.resumed ? L("composer.keep.changed") : state.draft.intent.isNew ? L("composer.keep.title.discussion") : L("composer.keep.title.reply") }
    private var keepPhotoWarning: String? {
        guard state.photoWillBeLost && state.photoUnfinished else { return nil }
        let isNew = state.draft.intent.isNew
        if case .uploading = state.uploadState { return isNew ? L("composer.keep.photo_uploading.discussion") : L("composer.keep.photo_uploading.reply") }
        return isNew ? L("composer.keep.photo_failed.discussion") : L("composer.keep.photo_failed.reply")
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
            let sub = state.draft.quote.map { L("composer.context.quoting", ["name": $0.author, "number": String($0.number.rawValue)]) }
                ?? state.draft.targetAuthor.map { L("composer.context.replying_to", ["name": $0, "number": String(parent?.rawValue ?? 0)]) }
                ?? category.map { L("composer.context.replying_in", ["community": $0]) } ?? L("composer.context.replying")
            VStack(alignment: .leading, spacing: 3) {
                Text(sub).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                Text(state.draft.contextTitle ?? L("composer.discussion_number", ["number": String(topic.rawValue)])).font(.subheadline.weight(.semibold)).lineLimit(2).contentDirection(state.draft.contextTitle ?? "")
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 12)).accessibilityElement(children: .combine)
        }
    }
    // MARK: States
    @ViewBuilder private var statusCards: some View {
        if let message = state.rejection {
            alertCard(symbol: "exclamationmark.triangle.fill", tint: .fomioDanger) {
                Text(L("composer.rejected.title")).font(.headline).accessibilityFocused($recoveryFocus, equals: .rejection)
                Text(message.text).font(.subheadline)
                Text(L("composer.rejected.message")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            }.id(Recovery.rejection)
        }
        if state.expired {
            alertCard(symbol: "person.crop.circle.badge.exclamationmark", tint: .fomioAccent) {
                Text(L("composer.expired.title")).font(.headline).accessibilityFocused($recoveryFocus, equals: .authorization)
                Text(state.draft.intent.isNew ? L("composer.expired.message.discussion") : L("composer.expired.message.reply")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                Button(L("auth.sign_in")) { suspendEditingFocus(); state.suspendForAuthentication() }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44)
            }.id(Recovery.authorization)
        }
        if app.isOffline && !state.locked {
            LText(lead: "offline.lead", rest: "offline.composer")
                .font(.subheadline).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
        }
        if state.draft.submission == .unconfirmed {
            alertCard(symbol: "questionmark.circle.fill", tint: .fomioAccent) {
                Text(state.draft.intent.isNew ? L("composer.unconfirmed.title.discussion") : L("composer.unconfirmed.title.reply")).font(.headline).accessibilityFocused($recoveryFocus, equals: .unconfirmed)
                Text(L("composer.unconfirmed.message")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack { unconfirmedActions }
                    VStack(alignment: .leading) { unconfirmedActions }
                }
                Divider()
                Text(L("composer.unconfirmed.duplicate_warning")).font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                Button(L("composer.retry.open")) { presentation = .retry }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.id(Recovery.unconfirmed)
        }
        if state.draft.submission == .pending {
            alertCard(symbol: "clock", tint: .fomioAccent) {
                Text(L("pending.title")).font(.headline).accessibilityFocused($recoveryFocus, equals: .pending)
                Text(state.draft.intent.isNew ? L("composer.pending.message.discussion") : L("composer.pending.message.reply")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            }.id(Recovery.pending)
        }
        if state.draft.missingPhoto && state.photoData == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("composer.photo_lost.title")).font(.headline).accessibilityFocused($recoveryFocus, equals: .missingPhoto)
                Text(state.draft.intent.isNew ? L("composer.photo_lost.message.discussion") : L("composer.photo_lost.message.reply")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { lostPhotoActions }
                    VStack(alignment: .leading, spacing: 0) { lostPhotoActions }
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioSelected, in: .rect(cornerRadius: 14)).id(Recovery.missingPhoto)
        }
    }
    @ViewBuilder private var unconfirmedActions: some View {
        Button(L("composer.check_again")) { Task { await state.checkAgain() } }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).disabled(state.checking).frame(minHeight: 44)
        Button(state.draft.intent.isNew ? L("composer.keep_as_draft") : L("composer.back_to_discussion")) { state.keepDraft(message: L("composer.kept_unconfirmed")) }.buttonStyle(.bordered).frame(minHeight: 44)
    }
    @ViewBuilder private var lostPhotoActions: some View {
        photoPicker(L("composer.photo.add_again"), symbol: nil)
        Button(L("composer.photo.continue_without")) { state.removePhoto() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
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
        case .retained: L("composer.photo.status.retained")
        case .queued: L("composer.photo.status.queued")
        case let .uploading(value): L("composer.photo.status.uploading", ["percent": (value).formatted(.percent.precision(.fractionLength(0)).locale(Localizer.shared.formattingLocale))])
        case let .failed(message): L("composer.photo.status.failed", ["reason": message.text])
        case .uploaded: L("composer.photo.status.uploaded")
        case .missing: L("composer.photo.status.missing")
        }
    }
    private func photoStatusRow(_ attachment: ComposerAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(photoStatus(attachment)).font(.subheadline).accessibilityAddTraits(.updatesFrequently)
            HStack {
                switch attachment.status {
                case .retained, .failed: Button(attachment.status == .retained ? L("composer.photo.resume_upload") : L("composer.photo.retry_upload")) { state.retryPhoto(attachment.id) }.frame(minHeight: 44)
                default: EmptyView()
                }
                Button(L("composer.photo.remove")) {
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
        guard insertion.location > 0, insertion.location <= source.length else { return L("composer.insert.at_start") }
        if insertion.location == source.length && !bodyEngaged { return L("composer.insert.at_end") }
        let line = source.substring(to: insertion.location).trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").last ?? ""
        let text = (line as NSString).substring(from: DiscourseMarkupCodec.style(ofLine: line).prefix).trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return L("composer.insert.at_cursor") }
        let excerpt = text.count > 40 ? String(text.prefix(40)) + L("common.ellipsis") : text
        return L("composer.insert.after", ["excerpt": excerpt])
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
            .init(L("composer.format.bold"), "bold", enabled: canFormatInline, group: L("composer.format")) { bodyEditor.send(.bold); bodyEditor.focus() },
            .init(L("composer.format.italic"), "italic", enabled: canFormatInline, group: L("composer.format")) { bodyEditor.send(.italic); bodyEditor.focus() },
            .init(L("composer.link"), "link", enabled: canFormatInline, group: L("composer.format")) { openLink() }
        ]
        // Turn into stays reachable here when large text drops the type chip from the bar.
        for style in ComposerTextStyle.offered {
            actions.append(.init(style.title, style.symbol, enabled: bodyEditor.textStyle != nil, group: L("composer.turn_into")) { bodyEditor.send(.style(style)); bodyEditor.focus() })
        }
        actions.append(.init(L("composer.add_block_ellipsis"), "plus") { openInserter() })
        actions.append(.init(L("composer.add_photo"), "photo") { photoInsertion = bodyEditor.selection; suspendEditingFocus(); showPhotoPicker = true })
        if app.fixture != nil {
            actions.append(.init(DevText("Sample photo"), "photo") {
                if let url = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"), let data = try? Data(contentsOf: url) {
                    let previous = state.draft.body; state.addPhoto(data, at: bodyEditor.selection.range); bodyEditor.send(.adopt(previous, bodyEditor.selection))
                }
            })
        }
        actions.append(.init(bodyEditor.markdown ? L("composer.rich_text") : L("composer.edit_markdown"), "textformat") { bodyEditor.send(.markdown); bodyEditor.focus() })
        actions.append(.init(L("composer.undo"), "arrow.uturn.backward", enabled: bodyEditor.canUndo) { bodyEditor.send(.undo) })
        actions.append(.init(L("composer.redo"), "arrow.uturn.forward", enabled: bodyEditor.canRedo) { bodyEditor.send(.redo) })
        return ComposerMoreMenu(actions: actions, labelled: labelled, onOpen: { restoreTask?.cancel(); turningInto = false })
    }
    private func photoPicker(_ title: String, symbol: String?) -> some View {
        Button { photoInsertion = bodyEditor.selection; suspendEditingFocus(); showPhotoPicker = true } label: {
            if let symbol { Label(title, systemImage: symbol).frame(minHeight: 44) } else { Text(title).frame(minHeight: 44) }
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
        .accessibilityLabel(label.map { L("composer.destination.a11y_selected", ["community": $0]) } ?? L("composer.destination.a11y_required")).accessibilityIdentifier("composer-destination")
    }
    @ViewBuilder private func collapsedParts(_ label: String?) -> some View {
        Text(L("composer.destination.post_in")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
        Text(label ?? L("composer.destination.choose")).font(.subheadline.weight(.semibold)).foregroundStyle(label == nil ? Color.fomioSecondaryText : .primary)
        Spacer(minLength: 0)
        HStack(spacing: 4) {
            Text(label == nil ? L("composer.destination.required") : L("composer.destination.change"))
            Image(systemName: "chevron.down").font(.caption.weight(.bold)).accessibilityHidden(true)
        }.font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
    }
    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.fomioSecondaryText).accessibilityHidden(true)
            TextField(L("composer.destination.search"), text: $query)
                .focused($searching).submitLabel(.done).autocorrectionDisabled().textInputAutocapitalization(.never)
                .onSubmit { if let first = visibleOptions.first, !trimmedQuery.isEmpty { pick(first.id) } else { searching = false } }
                .onKeyPress(.escape) { close(); return .handled }
                .accessibilityIdentifier("destination-search")
            if !query.isEmpty {
                Button(L("common.clear_search"), systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).foregroundStyle(Color.fomioSecondaryText).frame(minWidth: 32, minHeight: 44)
            }
            Button(L("composer.destination.close"), systemImage: "chevron.up", action: close).labelStyle(.iconOnly).font(.subheadline.weight(.bold)).foregroundStyle(Color.fomioAccent).frame(minWidth: 32, minHeight: 44)
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
                                        .accessibilityLabel(L("composer.destination.children_of", ["community": parent.community.name])).accessibilityValue(expansionValue(group))
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
                    if groups.isEmpty { message(L("composer.destination.none_available")) }
                } else {
                    ForEach(visibleOptions) { row($0, style: .result) }
                    if visibleOptions.isEmpty { message(L("composer.destination.no_match", ["query": trimmedQuery])) }
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
            CategoryMark(category: community, size: mark)
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
        (group.id.map(expanded.contains) ?? false) ? L("common.expanded") : L("common.collapsed")
    }
    private func toggle(_ group: OptionGroup) {
        guard let id = group.id else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) } }
    }
    private func row(_ option: Option, style: RowStyle) -> some View {
        let isSelected = selected == option.id
        return Button { pick(option.id) } label: {
            HStack(spacing: 12) {
                // Each result uses its own Discourse category identity.
                if style != .child { CategoryMark(category: option.community, size: mark) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(matched(option.community.name)).font(option.parent == nil ? .body.weight(.semibold) : .body).foregroundStyle(style == .child ? AnyShapeStyle(.primary.opacity(0.8)) : AnyShapeStyle(.primary))
                    if style == .result, let parent = option.parent { Text(matched(L("composer.destination.in_parent", ["community": parent.name]))).font(.footnote).foregroundStyle(Color.fomioSecondaryText) }
                }.multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").foregroundStyle(Color.fomioAccent).fontWeight(.semibold) }
            }
            .padding(.leading, style == .child ? 14 + mark + 12 : 14).padding(.trailing, 14).padding(.vertical, style == .child ? 6 : 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(isSelected && style != .parent ? Color.fomioSelected : .clear).contentShape(.rect)
        }.buttonStyle(.plain)
        .accessibilityLabel(rowLabel(option, selected: isSelected))
        .accessibilityIdentifier("destination-\(option.id.rawValue)")
    }
    private func rowLabel(_ option: Option, selected: Bool) -> String {
        let name = option.parent.map { L("composer.destination.child_a11y", ["community": option.community.name, "parent": $0.name]) } ?? option.community.name
        return selected ? L("common.selected_a11y", ["item": name]) : name
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
