import SwiftUI
import PhotosUI

struct ComposerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var phase
    @Bindable var state: ComposerState
    @State private var photo: PhotosPickerItem?
    @State private var showExit = false
    @State private var postAgainWarning = false
    @State private var destinationChooser = false
    @State private var showPhotoPicker = false
    @State private var suspendedFocus: Field?
    @State private var titleSelection: TextSelection?
    @State private var bodySelection: TextSelection?
    @State private var suspendedSelection: TextSelection?
    @State private var restoreAfterExit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Field: Hashable { case title, body }
    private enum Recovery: Hashable { case rejection, authorization, unconfirmed, pending, missingPhoto, photo, error }
    @FocusState private var focusedField: Field?
    @AccessibilityFocusState private var recoveryFocus: Recovery?
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    ReadingColumn {
                        VStack(alignment: .leading, spacing: 16) {
                            statusCards
                            if state.draft.intent.isNew { destinationRow } else { replyContext }
                            if let quote = state.draft.quote { QuoteBlock(quote: quote, lineLimit: 3) }
                            if state.draft.intent.isNew {
                                TextField("Title", text: $state.draft.title, selection: $titleSelection).font(.title3.weight(.semibold)).frame(minHeight: 44).disabled(state.locked)
                                    .focused($focusedField, equals: .title).submitLabel(.next).onSubmit { focusedField = .body }
                                    .accessibilityLabel("Title").accessibilityIdentifier("composer-title")
                                Divider().overlay(Color.fomioSeparator)
                            }
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $state.draft.body, selection: $bodySelection).font(.body).frame(minHeight: 200).scrollContentBackground(.hidden).focused($focusedField, equals: .body).disabled(state.locked)
                                    .accessibilityLabel(state.draft.intent.isNew ? "Opening post" : "Reply text").accessibilityIdentifier("composer-body")
                                if state.draft.body.isEmpty {
                                    Text(state.draft.intent.isNew ? "Write the opening post" : "Write your reply").foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true)
                                }
                            }
                            if state.photoData != nil || state.uploadState != .none { photoRow.id(Recovery.photo) }
                            if state.saveStatus == "Couldn’t save on this device" { Label(state.saveStatus, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("draft-save-status") }
                            if let error = state.error { Text(error).font(.subheadline).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("composer-error").id(Recovery.error).accessibilityFocused($recoveryFocus, equals: .error) }
                        }.padding(20)
                    }
                }.background(Color.fomioBackground).scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) { accessoryBar }
                .task(id: recoveryTarget) {
                    guard let target = recoveryTarget else { return }
                    focusedField = nil
                    await Task.yield()
                    guard !Task.isCancelled, recoveryTarget == target else { return }
                    if reduceMotion { proxy.scrollTo(target, anchor: .top) }
                    else { withAnimation { proxy.scrollTo(target, anchor: .top) } }
                    recoveryFocus = target
                }
            }
            .navigationTitle(state.draft.intent.isNew ? "New discussion" : "Reply").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { close() }.disabled(state.draft.submission == .submitting).accessibilityIdentifier("composer-close").keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state.draft.submission == .submitting { ProgressView().accessibilityLabel("Posting") }
                    else { Button("Post") { focusedField = nil; Task { await state.submit() } }.buttonStyle(.glassProminent).disabled(!state.canPost).accessibilityIdentifier("composer-post").keyboardShortcut(.return, modifiers: .command) }
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog(keepTitle, isPresented: $showExit, titleVisibility: .visible) {
                Button(state.photoWillBeLost && state.photoUnfinished ? "Keep draft without photo" : "Keep draft") { restoreAfterExit = false; state.keepDraft() }
                Button(state.resumed ? "Discard draft" : "Discard", role: .destructive) { restoreAfterExit = false; state.discard() }
                Button("Keep editing") { restoreAfterExit = true; showExit = false }.accessibilityIdentifier("composer-keep-editing")
            } message: { if let warning = keepPhotoWarning { Text(warning) } }
            .alert("Post again?", isPresented: $postAgainWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Post again") { Task { await state.postAgain() } }
            } message: { Text("If your first \(state.noun) went through, this will create a duplicate.") }
            .sheet(isPresented: $state.needsAuthorization, onDismiss: { if app.username != nil { state.reauthorized() } }) { SignInView(app: app).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $destinationChooser, onDismiss: { restoreEditingFocus() }) { DestinationChooser(selected: state.draft.categoryID) { state.draft.categoryID = $0; state.edited() } }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photo, matching: .images)
            .onChange(of: showPhotoPicker) { _, presented in if !presented { restoreEditingFocus() } }
            .onChange(of: showExit) { _, presented in
                if !presented && restoreAfterExit { restoreAfterExit = false; restoreEditingFocus() }
            }
            .onChange(of: state.locked) { _, locked in if locked { focusedField = nil; suspendedFocus = nil } }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .title { Button("Next") { focusedField = .body }.accessibilityIdentifier("composer-next") }
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("composer-keyboard-done")
                }
            }
            .modifier(ToastHost(message: app.toastMessage, bottom: focusedField == nil ? 72 : 12))
            .onChange(of: state.draft.title) { state.edited() }
            .onChange(of: state.draft.body) { state.edited() }
            .onChange(of: phase) { _, value in if value != .active && state.hasChanges { state.save() } }
            .onChange(of: photo) { _, item in
                Task {
                    do { if let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) { state.addPhoto(jpeg) } }
                    catch { state.error = "Could not read the selected photo. Your writing is kept." }
                    photo = nil
                }
            }
        }
    }
    private func close() {
        suspendEditingFocus()
        if state.locked { state.keepDraft(message: state.draft.submission == .unconfirmed ? "Kept as a draft. Check the discussion before posting again." : nil) }
        else if state.hasChanges { restoreAfterExit = true; showExit = true }
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
        if case .failed = state.uploadState { return .photo }
        return nil
    }
    private func suspendEditingFocus() {
        suspendedFocus = focusedField
        suspendedSelection = focusedField == .title ? titleSelection : bodySelection
        focusedField = nil
    }
    private func restoreEditingFocus() {
        let field = suspendedFocus
        let selection = suspendedSelection
        suspendedFocus = nil
        suspendedSelection = nil
        guard !state.locked, app.composer?.id == state.id else { return }
        // Let the presentation dismiss before asking the native editor to resume.
        Task { @MainActor in
            await Task.yield()
            guard !state.locked, app.composer?.id == state.id, !showPhotoPicker, !destinationChooser, !showExit else { return }
            focusedField = field
            await Task.yield()
            guard focusedField == field, !state.locked, app.composer?.id == state.id else { return }
            if field == .title { titleSelection = selection }
            else if field == .body { bodySelection = selection }
        }
    }
    private var keepTitle: String { state.resumed ? "You changed this draft." : "Keep this \(state.noun) as a draft?" }
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
        .accessibilityLabel(label.map { "Posting in \($0). Change community" } ?? "Choose a community, required").accessibilityIdentifier("composer-destination")
    }
    @ViewBuilder private func destinationParts(_ label: String?) -> some View {
        Text("Post in").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
        Text(label ?? "Choose a community").font(.subheadline.weight(.semibold)).foregroundStyle(label == nil ? Color.fomioSecondaryText : .primary)
        Spacer(minLength: 0)
        Text(label == nil ? "Required" : "Change").font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
    }
    @ViewBuilder private var replyContext: some View {
        if case let .reply(topic, parent) = state.draft.intent {
            let category = state.draft.contextCategory.map(app.categoryName)
            let sub = state.draft.quote.map { "Quoting \($0.author) · #\($0.number.rawValue)" }
                ?? state.draft.targetAuthor.map { "Replying to \($0) · #\(parent?.rawValue ?? 0)" }
                ?? "Replying to the discussion\(category.map { " · \($0)" } ?? "")"
            VStack(alignment: .leading, spacing: 3) {
                Text(sub).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                Text(state.draft.contextTitle ?? "Discussion \(topic.rawValue)").font(.subheadline.weight(.semibold)).lineLimit(2)
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
                Button("Sign in") { suspendEditingFocus(); app.gate = state.draft.intent.isNew ? .create(nil) : .reply; state.needsAuthorization = true }.buttonStyle(.glassProminent).frame(minHeight: 44)
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
                Button("Post again…") { postAgainWarning = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
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
    private var photoRow: some View {
        let failed: Bool = { if case .failed = state.uploadState { true } else { false } }()
        let progress: Double? = { if case let .uploading(value) = state.uploadState { value } else { nil } }()
        let label = progress.map { "Uploading photo · \(Int($0 * 100))%" } ?? (failed ? "Photo didn’t upload" : "Photo attached")
        let help = progress != nil ? "Post becomes available when the upload finishes." : failed ? "Your writing is kept. Retry, or remove the photo to post without it." : "One photo per post in this version."
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let data = state.photoData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
                    else { Image(systemName: "photo").font(.title2).foregroundStyle(Color.fomioSecondaryText).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.fomioSelected) }
                }.frame(width: 56, height: 56).clipShape(.rect(cornerRadius: 12)).opacity(state.uploadState == .uploaded ? 1 : 0.55).accessibilityLabel("Attached photo")
                VStack(alignment: .leading, spacing: 5) {
                    Label { Text(label) } icon: { if failed { Image(systemName: "exclamationmark.triangle.fill") } }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(failed ? Color.fomioDanger : .primary).accessibilityAddTraits(.updatesFrequently).accessibilityFocused($recoveryFocus, equals: .photo)
                    if let progress { ProgressView(value: progress).accessibilityLabel("Photo upload progress") }
                    Text(help).font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                }
            }
            HStack(spacing: 18) {
                if failed { Button("Retry upload") { state.retryPhoto() } }
                Button(progress != nil ? "Cancel upload" : "Remove photo") { state.removePhoto() }.disabled(state.locked)
            }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
    }
    @ViewBuilder private var accessoryBar: some View {
        if !state.locked && state.photoData == nil && state.uploadState == .none && !state.draft.missingPhoto {
            HStack(spacing: 18) {
                photoPicker("Add photo", symbol: "photo").accessibilityLabel("Add photo")
                if app.fixture != nil {
                    Button("Sample photo") { if let url = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg"), let data = try? Data(contentsOf: url) { state.addPhoto(data) } }
                        .font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("sample-photo")
                }
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 4).background(.bar)
        }
    }
    private func photoPicker(_ title: String, symbol: String?) -> some View {
        Button { suspendEditingFocus(); showPhotoPicker = true } label: {
            if let symbol { Label(title, systemImage: symbol).frame(minHeight: 44) } else { Text(title).frame(minHeight: 44) }
        }.font(.subheadline.weight(.semibold)).disabled(state.locked)
    }
}
struct DestinationChooser: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let selected: CategoryID?
    let onPick: (CategoryID) -> Void
    var body: some View {
        NavigationStack {
            List {
                // Only communities the account can post in; a non-postable parent is a heading only.
                ForEach(app.communities.filter { root in root.parentID == nil && (root.canCreate || app.communities.contains { $0.parentID == root.id && $0.canCreate }) }) { root in
                    Section {
                        if root.canCreate { row(root, parent: nil) }
                        ForEach(app.communities.filter { $0.parentID == root.id && $0.canCreate }) { row($0, parent: root) }
                    } header: { if !root.canCreate { Text(root.name) } }
                }
            }.navigationTitle("Choose a community").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } } }
        }
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
