import Foundation
import Observation

@MainActor @Observable final class ComposerState: Identifiable {
    enum UploadState: Equatable { case none, uploading(Double), failed(String), uploaded }
    nonisolated let id: UUID
    var draft: Draft
    var uploadState: UploadState = .none
    var photoData: Data?
    var error: String?
    /// The community's validation message, shown as returned. Editing clears it.
    var rejection: String?
    /// Authorization expired while writing. Post stays a separate tap after signing in again.
    var expired = false
    var saveStatus = "Not saved yet"
    var checking = false
    var needsAuthorization = false
    let origin: AppTab
    let resumed: Bool
    unowned let app: AppState
    private let original: String
    private var autosave: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    init(draft: Draft, app: AppState, origin: AppTab, resumed: Bool = false) {
        self.id = draft.id; self.draft = draft; self.app = app; self.origin = origin; self.resumed = resumed
        if draft.uploadedPhoto != nil { uploadState = .uploaded }
        original = Self.signature(draft, photo: draft.uploadedPhoto != nil)
    }
    private static func signature(_ draft: Draft, photo: Bool) -> String { "\(draft.title)|\(draft.body)|\(draft.categoryID?.rawValue ?? 0)|\(photo)" }
    /// Keep/Discard is offered only when title, text, destination or photo changed.
    var hasChanges: Bool { Self.signature(draft, photo: photoData != nil || draft.uploadedPhoto != nil) != original }
    var noun: String { draft.intent.isNew ? "discussion" : "reply" }
    var photoWillBeLost: Bool { photoData != nil && (draft.uploadedPhoto == nil || app.fixture != nil) }
    var photoUnfinished: Bool { if case .uploading = uploadState { true } else if case .failed = uploadState { true } else { false } }
    var locked: Bool { draft.submission != .editing }
    var canPost: Bool {
        guard app.username != nil, !expired, !app.isOffline, draft.account == app.account, !locked, !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !draft.missingPhoto else { return false }
        if photoUnfinished { return false }
        if draft.intent.isNew { return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && app.communities.contains { $0.id == draft.categoryID && $0.canCreate } }
        return true
    }
    func edited() { rejection = nil; changed() }
    func changed() {
        autosave?.cancel()
        autosave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)); guard !Task.isCancelled else { return }; self?.save() } catch {}
        }
    }
    @discardableResult func save() -> Bool {
        var value = draft
        if photoData != nil && draft.uploadedPhoto == nil { value.missingPhoto = true }
        if app.fixture != nil && draft.uploadedPhoto != nil { value.uploadedPhoto = nil; value.missingPhoto = true }
        do { try app.draftStore.save(value); saveStatus = "Saved on this device"; error = nil; app.draftsRevision += 1; return true }
        catch { saveStatus = "Couldn’t save on this device"; self.error = error.localizedDescription; return false }
    }
    func keepDraft(message: String? = nil) {
        autosave?.cancel(); uploadTask?.cancel()
        let droppedPhoto = photoWillBeLost && photoUnfinished
        if photoWillBeLost { draft.missingPhoto = true; draft.uploadedPhoto = nil }
        photoData = nil
        if save() {
            app.composer = nil
            app.toast(droppedPhoto ? "Draft kept without the photo. Find it in Me › Drafts." : message ?? "Draft kept. Find it in Me › Drafts.")
        }
    }
    func close() { autosave?.cancel(); uploadTask?.cancel(); app.composer = nil }
    func discard() {
        autosave?.cancel(); uploadTask?.cancel()
        do { try app.draftStore.delete(draft.id); app.draftsRevision += 1; app.composer = nil; if resumed { app.toast("Draft discarded") } }
        catch { self.error = error.localizedDescription }
    }
    func removePhoto() {
        uploadTask?.cancel(); uploadTask = nil; photoData = nil; draft.uploadedPhoto = nil; draft.missingPhoto = false; uploadState = .none; changed()
    }
    func addPhoto(_ data: Data) {
        guard !locked else { return }
        guard !app.isOffline else { app.toast("Photos can’t upload while you’re offline. Your writing is kept."); return }
        uploadTask?.cancel(); photoData = data; draft.missingPhoto = false; draft.uploadedPhoto = nil
        uploadState = .uploading(0); changed()
        uploadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let photo = try await app.service.upload(data) { [weak self] progress in self?.uploadState = .uploading(progress) }
                try Task.checkCancellation(); draft.uploadedPhoto = photo; uploadState = .uploaded; save()
            } catch is CancellationError {} catch { uploadState = .failed(error.localizedDescription); save() }
        }
    }
    func retryPhoto() { if let photoData { addPhoto(photoData) } }
    func submit() async {
        guard canPost else { return }
        draft.submission = .submitting; rejection = nil
        guard save() else { draft.submission = .editing; return }
        do {
            let outcome = try await app.service.publish(draft)
            switch outcome {
            case let .published(topic, number): finish(topic: topic, number: number)
            case .pending:
                // The local record stays locked so it cannot be posted twice; the page says it isn't published.
                draft.submission = .pending; save(); autosave?.cancel()
                app.pendingNotice = PendingNotice(tab: origin, depth: app.tabs[origin]?.path.count ?? 0, isReply: !draft.intent.isNew, categoryName: draft.categoryID.flatMap { app.category($0)?.name })
                app.composer = nil
            case .unconfirmed: draft.submission = .unconfirmed; save()
            }
        } catch {
            if error as? RepositoryError == .unconfirmed { draft.submission = .unconfirmed }
            else { draft.submission = .editing }
            save()
            switch error as? RepositoryError {
            case let .invalid(message)?: rejection = message
            case .unauthorized?: app.username = nil; app.pendingAction = nil; expired = true
            default: self.error = error.localizedDescription
            }
        }
    }
    func reauthorized() { expired = false; app.toast("Signed in again. Tap Post when you’re ready.") }
    func checkAgain() async {
        guard !checking, draft.submission == .unconfirmed else { return }
        checking = true; defer { checking = false }
        do {
            switch try await app.service.reconcile(draft) {
            case let .published(topic, number): finish(topic: topic, number: number); app.toast("Found it. Your \(noun) was posted.")
            case .unresolved: app.toast("Still not confirmed. Your text is kept here.")
            }
        } catch { self.error = error.localizedDescription }
    }
    func allowManualRetry() { draft.submission = .editing; save() }
    /// Explicit, warned retry. It may duplicate the first post if that one went through.
    func postAgain() async { allowManualRetry(); await submit() }
    private func finish(topic: TopicID, number: PostNumber) {
        autosave?.cancel()
        do { try app.draftStore.delete(draft.id) }
        catch { draft.submission = .pending; save(); app.banner = "Published, but local draft cleanup failed. The draft is locked to prevent reposting." }
        app.published(topic: topic, number: number, origin: origin, isReply: !draft.intent.isNew, categoryID: draft.categoryID)
    }
}
