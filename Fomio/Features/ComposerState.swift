import Foundation
import UIKit
import Observation

@MainActor @Observable final class ComposerState: Identifiable {
    enum UploadState: Equatable { case none, uploading(Double), failed(String), uploaded }
    nonisolated let id: UUID
    var draft: Draft
    var uploadState: UploadState {
        guard let attachment = draft.activeAttachments.first else { return .none }
        switch attachment.status {
        case let .uploading(value): return .uploading(value)
        case let .failed(message): return .failed(message)
        case .retained, .queued, .missing: return .failed("Resume upload or remove this photo.")
        case .uploaded: return .uploaded
        }
    }
    var photoData: Data? { draft.activeAttachments.first.flatMap { try? app.draftStore.photo(draft: draft, attachment: $0) } }
    private var uploadGeneration = UUID()
    private var currentUploadID: UUID?
    var error: String?
    /// The community's validation message, shown as returned. Editing clears it.
    var rejection: String?
    /// Authorization expired while writing. Post stays a separate tap after signing in again.
    var expired = false
    var saveStatus = "Not saved yet"
    var checking = false
    var suggestions: [DiscussionSummary] = []
    var previews: [URL: OneboxMetadata] = [:]
    private var suggestionTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var suggestionGeneration = UUID()
    var needsAuthorization = false
    let origin: AppTab
    let resumed: Bool
    unowned let app: AppState
    private var original: String
    private var stored: Bool
    private var positionSnapshot: String
    private var autosave: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    init(draft: Draft, app: AppState, origin: AppTab, resumed: Bool = false) {
        var draft = draft; draft.migrateDocument(); draft.synchronizeAttachments()
        for index in draft.attachments.indices {
            if draft.attachments[index].status != .uploaded { draft.attachments[index].status = .retained }
            if draft.attachments[index].server == nil && (try? app.draftStore.photo(draft: draft, attachment: draft.attachments[index])).flatMap(UIImage.init(data:)) == nil { draft.attachments[index].status = .missing }
        }
        positionSnapshot = draft.body
        self.id = draft.id; self.draft = draft; self.app = app; self.origin = origin; self.resumed = resumed
        original = Self.signature(draft, photo: draft.uploadedPhoto != nil)
        stored = resumed
    }
    private static func signature(_ draft: Draft, photo: Bool) -> String {
        var raw = draft.body
        for attachment in draft.activeAttachments { raw = raw.replacingOccurrences(of: attachment.reference, with: attachment.localReference) }
        return "\(draft.title)|\(raw)|\(draft.categoryID?.rawValue ?? 0)"
    }
    /// Keep/Discard is offered only when title, text, destination or photo changed.
    var hasChanges: Bool { Self.signature(draft, photo: photoData != nil || draft.uploadedPhoto != nil) != original }
    var noun: String { draft.intent.isNew ? String(localized: "discussion") : String(localized: "reply") }
    var photoWillBeLost: Bool { false }
    var photoUnfinished: Bool { draft.activeAttachments.contains { $0.status != .uploaded } }
    var locked: Bool { draft.submission != .editing }
    var canPost: Bool {
        guard app.username != nil, !expired, !app.isOffline, draft.account == app.account, !locked, !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !draft.missingPhoto else { return false }
        if photoUnfinished { return false }
        let writing = DiscourseMarkupCodec.parse(draft.body).filter { $0.kind != .quote }.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if writing.isEmpty { return false }
        if draft.intent.isNew { return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && app.communities.contains { $0.id == draft.categoryID && $0.canCreate } }
        return true
    }
    private func synchronizeAttachments() {
        draft.synchronizeAttachments(previousBody: positionSnapshot); positionSnapshot = draft.body
    }
    func edited() {
        synchronizeAttachments()
        if let currentUploadID, !draft.activeAttachments.contains(where: { $0.id == currentUploadID }) {
            let queued = Set(draft.activeAttachments.filter { if case .queued = $0.status { return true }; if case .uploading = $0.status { return true }; return false }.map(\.id))
            stopUploads()
            for index in draft.attachments.indices where queued.contains(draft.attachments[index].id) { draft.attachments[index].status = .queued }
            startUploads()
        }
        rejection = nil; changed(); refreshSuggestions(); refreshPreviews()
    }
    func chooseDestination(_ id: CategoryID) {
        // Choosing a community for an untouched draft is setup, not writing; it does not prompt Keep/Discard on close.
        let untouched = !hasChanges
        if draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let template = app.category(id)?.topicTemplate { draft.body = template }
        draft.categoryID = id
        if untouched { original = Self.signature(draft, photo: false) }
        edited()
    }
    private func refreshSuggestions() {
        suggestionTask?.cancel(); suggestionGeneration = UUID()
        guard draft.intent.isNew, app.service.composerCapabilities.similarDiscussions, !draft.title.trimmingCharacters(in: .whitespaces).isEmpty else { suggestions = []; return }
        let generation = suggestionGeneration, title = draft.title, raw = draft.body
        suggestionTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(750))
                guard let self else { return }
                let results = try await app.service.similarDiscussions(title: title, raw: raw)
                guard !Task.isCancelled, suggestionGeneration == generation else { return }
                suggestions = results
            } catch { if let self, !Task.isCancelled, suggestionGeneration == generation { suggestions = [] } }
        }
    }
    private func refreshPreviews() {
        guard app.service.composerCapabilities.onebox else { return }
        let urls = DiscourseMarkupCodec.standaloneURLs(draft.body)
        previews = previews.filter { urls.contains($0.key) }
        guard previewTask == nil else { return }
        previewTask = Task { [weak self] in
            guard let self else { return }
            defer { previewTask = nil }
            var attempted = Set<URL>()
            while let url = DiscourseMarkupCodec.standaloneURLs(draft.body).first(where: { previews[$0] == nil && !attempted.contains($0) }) {
                guard !Task.isCancelled else { return }
                attempted.insert(url)
                do {
                    if let preview = try await app.service.oneboxPreview(url: url, context: OneboxContext(category: draft.categoryID, topic: draft.intent.topicID)), DiscourseMarkupCodec.standaloneURLs(draft.body).contains(url) { previews[url] = preview }
                } catch { /* A failed preview remains a plain link. */ }
            }
        }
    }
    func changed() {
        autosave?.cancel()
        // A new draft gets a device record only once it differs from what the composer opened with.
        guard hasChanges || stored else { return }
        autosave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)); guard !Task.isCancelled else { return }; self?.save() } catch {}
        }
    }
    @discardableResult func save() -> Bool {
        synchronizeAttachments()
        var value = draft
        value.attachments = draft.activeAttachments
        do { try app.draftStore.save(value); stored = true; saveStatus = "Saved on this device"; error = nil; app.draftsRevision += 1; return true }
        catch { saveStatus = "Couldn’t save on this device"; self.error = error.localizedDescription; return false }
    }
    func keepDraft(message: String? = nil) {
        autosave?.cancel(); uploadTask?.cancel()
        stopUploads()
        if save() {
            do { try app.draftStore.reconcileFiles(account: draft.account) } catch { self.error = error.localizedDescription; return }
            app.composer = nil
            app.toast(String(localized: String.LocalizationValue(message ?? "Draft kept. Find it in Me › Drafts.")))
        }
    }
    func close() { autosave?.cancel(); stopUploads(); app.composer = nil }
    func discard() {
        autosave?.cancel(); stopUploads()
        do { try app.draftStore.delete(draft.id); app.draftsRevision += 1; app.composer = nil; if resumed { app.toast(String(localized: "Draft discarded")) } }
        catch { self.error = error.localizedDescription }
    }
    func stopUploads() {
        uploadGeneration = UUID(); uploadTask?.cancel(); uploadTask = nil; currentUploadID = nil
        for index in draft.attachments.indices {
            switch draft.attachments[index].status { case .uploading, .queued: draft.attachments[index].status = .retained; default: break }
        }
    }
    func attachment(for node: MarkupNode) -> ComposerAttachment? { draft.attachmentBindings.first { $0.node.range == node.range }?.attachment }
    func data(for node: MarkupNode) -> Data? { attachment(for: node).flatMap { try? app.draftStore.photo(draft: draft, attachment: $0) } }
    func removePhoto() { for attachment in draft.activeAttachments { removePhoto(attachment.id) }; draft.missingPhoto = false }
    func removePhoto(_ id: UUID) {
        guard !locked, let attachment = draft.attachments.first(where: { $0.id == id }) else { return }
        // Keep the retained bytes until draft cleanup, so native undo can restore the photo.
        if let node = draft.attachmentBindings.first(where: { $0.attachment.id == attachment.id })?.node { draft.body = DiscourseMarkupCodec.replace(draft.body, range: node.range, with: "") }
        edited()
    }
    func addPhoto(_ data: Data, at selection: NSRange? = nil) {
        guard !locked else { return }
        if let limit = app.service.composerCapabilities.maximumUploadBytes, data.count > limit { error = String(localized: "This photo exceeds the community upload limit."); return }
        var attachment = ComposerAttachment(status: app.isOffline ? .retained : .queued)
        do { attachment.localFileName = try app.draftStore.retain(data, draft: draft, attachment: attachment.id) }
        catch { self.error = String(localized: "Could not retain the photo on this device. Your writing is kept. \(error.localizedDescription)"); return }
        let range = selection ?? NSRange(location: (draft.body as NSString).length, length: 0)
        draft.body = DiscourseMarkupCodec.replace(draft.body, range: range, with: "\n" + attachment.markup + "\n")
        draft.attachments.append(attachment)
        guard save() else { attachment.status = .retained; return }
        startUploads()
    }
    func retryPhoto() { for attachment in draft.activeAttachments where attachment.status != .uploaded { retryPhoto(attachment.id) } }
    func retryPhoto(_ id: UUID) {
        guard !locked, !app.isOffline, let index = draft.attachments.firstIndex(where: { $0.id == id }), draft.attachments[index].server == nil else { return }
        draft.attachments[index].status = .queued; startUploads()
    }
    func describePhoto(_ id: UUID, text: String) {
        guard !locked, let index = draft.attachments.firstIndex(where: { $0.id == id }) else { return }
        let node = draft.attachmentBindings.first { $0.attachment.id == id }?.node
        draft.attachments[index].description = text
        if let node { draft.body = DiscourseMarkupCodec.replace(draft.body, range: node.range, with: draft.attachments[index].markup) }; edited()
    }
    private func startUploads() {
        guard uploadTask == nil else { return }
        let generation = uploadGeneration
        uploadTask = Task { [weak self] in
            guard let self else { return }
            defer { if uploadGeneration == generation { uploadTask = nil; currentUploadID = nil } }
            while let attachment = draft.activeAttachments.first(where: { $0.status == .queued }) {
                guard !Task.isCancelled, uploadGeneration == generation, draft.account == app.account else { return }
                let id = attachment.id; currentUploadID = id
                do {
                    let data = try app.draftStore.photo(draft: draft, attachment: attachment)
                    let photo = try await app.service.upload(data) { [weak self] value in
                        guard let self, self.uploadGeneration == generation, let index = self.draft.attachments.firstIndex(where: { $0.id == id }), self.draft.activeAttachments.contains(where: { $0.id == id }) else { return }
                        self.draft.attachments[index].status = .uploading(value)
                    }
                    guard !Task.isCancelled, uploadGeneration == generation, draft.account == app.account, draft.activeAttachments.contains(where: { $0.id == id }), let index = draft.attachments.firstIndex(where: { $0.id == id }) else { return }
                    let previous = draft.attachments[index].localReference
                    draft.attachments[index].server = photo; draft.attachments[index].status = .uploaded
                    draft.body = draft.body.replacingOccurrences(of: previous, with: photo.shortURL); save()
                } catch is CancellationError { return }
                catch {
                    guard uploadGeneration == generation, let index = draft.attachments.firstIndex(where: { $0.id == id }) else { return }
                    draft.attachments[index].status = .failed(error.localizedDescription); save()
                }
            }
        }
    }
    func submit() async {
        guard canPost else { return }
        for attachment in draft.activeAttachments { if let server = attachment.server { draft.body = draft.body.replacingOccurrences(of: attachment.localReference, with: server.shortURL) } }
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
    func suspendForAuthentication() {
        stopUploads(); guard save() else { return }
        app.gate = draft.intent.isNew ? .create(nil) : .reply
        app.pendingAction = { [self] in
            guard app.account == draft.account else { return }
            if let topic = draft.intent.topicID {
                do { let page = try await app.service.discussion(topic, page: 0); guard page.canReply else { error = String(localized: "You no longer have permission to reply."); app.composer = self; return } }
                catch { self.error = error.localizedDescription; app.composer = self; return }
            }
            reauthorized(); app.composer = self
        }
        app.composer = nil
        Task { [app] in try? await Task.sleep(for: .milliseconds(350)); app.authRequested = true }
    }
    func reauthorized() { expired = false; app.toast(String(localized: "Signed in again. Tap Post when you’re ready.")) }
    func checkAgain() async {
        guard !checking, draft.submission == .unconfirmed else { return }
        checking = true; defer { checking = false }
        do {
            switch try await app.service.reconcile(draft) {
            case let .published(topic, number): finish(topic: topic, number: number); app.toast(String(localized: "Found it. Your \(noun) was posted."))
            case .unresolved: app.toast(String(localized: "Still not confirmed. Your text is kept here."))
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
