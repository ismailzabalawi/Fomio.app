import Foundation
import Observation

struct SearchViewer: Hashable, Sendable {
    var site: String
    var account: AccountID
    var revision: Int
    var locale: String
    var username: String? = nil
}

/// A tab owns this state, not whichever pane happens to present its search results.
@MainActor @Observable final class DiscussionSearchState {
    enum Operation: Equatable { case initial, refresh, more(Int)
        var page: Int { if case let .more(page) = self { page } else { 1 } }
    }
    struct Failure: Equatable {
        var attemptID = UUID()
        var operation: Operation
        var message: String
        var retryable: Bool
        var needsSignIn = false
        var retryAfter: Date? = nil
        var kind: SearchFailure? = nil
    }
    private struct Input: Hashable {
        var viewer: SearchViewer
        var scope: BrowseScope
        var query: String
    }
    var query = "" {
        didSet { if query != oldValue { invalidate(clearResults: true) } }
    }
    var revealed = false
    private(set) var hits: [DiscussionSearchHit] = []
    private(set) var nextPage: Int?
    private(set) var completed = false
    private(set) var failure: Failure?
    private(set) var loading = false
    private(set) var showingPreviousResults = false
    private(set) var reachedPageLimit = false
    var anchor: PostID?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var attempt: UUID?
    @ObservationIgnored private var input: Input?
    @ObservationIgnored private var settings: SearchSettings?
    @ObservationIgnored private var settingsViewer: SearchViewer?
    @ObservationIgnored private var throttleCount = 0
    @ObservationIgnored private var throttleUntil: Date?
    @ObservationIgnored private var accessInvalidationPending = false

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    var active: Bool { !trimmedQuery.isEmpty }
    var showsNoResults: Bool { completed && hits.isEmpty && failure == nil && !loading }

    func schedule(service: any SearchRepository, viewer: SearchViewer, scope: BrowseScope, catalog: [Community], debounce: Duration = .milliseconds(350)) {
        let next = Input(viewer: viewer, scope: scope, query: trimmedQuery)
        guard next != input else { return } // Remounting never retries a failure or repeats a success.
        invalidate(clearResults: true)
        input = next
        guard !next.query.isEmpty else { return }
        start(.initial, service: service, input: next, catalog: catalog, delay: debounce)
    }
    func retry(service: any SearchRepository, viewer: SearchViewer, scope: BrowseScope, catalog: [Community]) {
        guard !loading, let failure, failure.retryable, !failure.needsSignIn,
              failure.retryAfter.map({ $0 <= Date() }) != false,
              let input, input == Input(viewer: viewer, scope: scope, query: trimmedQuery) else { return }
        start(failure.operation, service: service, input: input, catalog: catalog)
    }
    func refresh(service: any SearchRepository, viewer: SearchViewer, scope: BrowseScope, catalog: [Community]) {
        guard !loading, active else { return }
        let current = Input(viewer: viewer, scope: scope, query: trimmedQuery)
        if current != input { schedule(service: service, viewer: viewer, scope: scope, catalog: catalog, debounce: .zero); return }
        start(completed ? .refresh : .initial, service: service, input: current, catalog: catalog)
    }
    func more(service: any SearchRepository, viewer: SearchViewer, scope: BrowseScope, catalog: [Community]) {
        guard !loading, failure == nil, let page = nextPage, page <= 10,
              let input, input == Input(viewer: viewer, scope: scope, query: trimmedQuery) else { return }
        start(.more(page), service: service, input: input, catalog: catalog)
    }
    func cancel() { query = ""; revealed = false; invalidate(clearResults: true) }
    /// Consumed once by the tab coordinator; grouped failures never invalidate read access.
    func consumeAccessInvalidation() -> Bool {
        let pending = accessInvalidationPending; accessInvalidationPending = false; return pending
    }
    func rebaseAccessFailure(viewer: SearchViewer) {
        guard let previous = input, failure != nil else { return }
        task?.cancel(); task = nil; attempt = nil; loading = false
        settings = nil; settingsViewer = nil
        var viewer = viewer; viewer.locale = previous.viewer.locale
        input = Input(viewer: viewer, scope: previous.scope, query: trimmedQuery)
        hits = []; nextPage = nil; completed = false; anchor = nil; showingPreviousResults = false
        failure?.operation = .initial
    }
    /// A shared visibility change clears private rows in every visible scene.
    /// Bind the recovery to its new viewer so a remount cannot resubmit it.
    func pauseForAccessChange(viewer: SearchViewer, scope: BrowseScope, needsSignIn: Bool) {
        let previous = input, previousFailure = failure
        invalidateViewer()
        guard active else { return }
        var viewer = viewer
        if let previous { viewer.locale = previous.viewer.locale }
        input = Input(viewer: viewer, scope: scope, query: trimmedQuery)
        failure = Failure(operation: .initial, message: SearchFailure.accessDenied.localizedDescription,
                          retryable: true, needsSignIn: needsSignIn || previousFailure?.needsSignIn == true, kind: .accessDenied)
        if let previousFailure, previousFailure.kind == .accessDenied { failure?.attemptID = previousFailure.attemptID }
    }
    func invalidateViewer() {
        settings = nil; settingsViewer = nil
        invalidate(clearResults: true)
    }
    private func invalidate(clearResults: Bool) {
        task?.cancel(); task = nil; attempt = nil; loading = false; failure = nil; input = nil; accessInvalidationPending = false
        showingPreviousResults = false
        throttleCount = 0
        if clearResults { hits = []; nextPage = nil; completed = false; anchor = nil; reachedPageLimit = false }
    }
    private func start(_ operation: Operation, service: any SearchRepository, input: Input, catalog: [Community], delay: Duration = .zero) {
        guard !loading else { return }
        if let until = throttleUntil, until > Date() {
            failure = Failure(operation: operation, message: SearchFailure.rateLimited(until).localizedDescription, retryable: true, retryAfter: until)
            return
        }
        let id = UUID(); attempt = id; loading = true; failure = nil
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.attempt == id { self.loading = false; self.attempt = nil; self.task = nil } }
            do {
                if delay > .zero { try await Task.sleep(for: delay) }
                try Task.checkCancellation()
                if self.settingsViewer != input.viewer { self.settings = nil; self.settingsViewer = input.viewer }
                let settings: SearchSettings
                if let cached = self.settings { settings = cached }
                else {
                    settings = try await service.searchSettings()
                    guard self.current(id, input) else { return }
                    self.settings = settings
                }
                let request = try DiscussionSearchRequest(query: input.query, scope: input.scope, page: operation.page, settings: settings, catalog: catalog, validationLocale: Locale(identifier: input.viewer.locale))
                let page = try await service.search(request)
                guard self.current(id, input) else { return }
                switch operation {
                case .initial, .refresh: self.hits = page.items
                case .more:
                    // Repeated exact hits at a page boundary do not create duplicate rows.
                    let existing = Set(self.hits.map(\.id))
                    self.hits += page.items.filter { !existing.contains($0.id) }
                }
                self.nextPage = page.nextPage
                self.completed = true; self.failure = nil; self.showingPreviousResults = false
                self.throttleCount = 0
                self.reachedPageLimit = page.reachedLimit
            } catch {
                guard self.current(id, input) else { return }
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
                let accessFailure = (error as? SearchFailure) == .accessDenied || (error as? RepositoryError).map { [.unauthorized, .denied, .unavailable].contains($0) } == true
                var error = error
                if (error as? RepositoryError) == .rateLimited { error = SearchFailure.rateLimited(nil) }
                if (error as? SearchFailure) == .accessDenied {
                    if let username = input.viewer.username {
                        do { try await service.verifySearchViewer(username: username); error = RepositoryError.denied }
                        catch let sessionError { error = sessionError }
                        guard self.current(id, input) else { return }
                    } else { error = RepositoryError.denied }
                    // Even when the session check fails, do not retain potentially private rows.
                    self.hits = []; self.nextPage = nil; self.completed = false; self.anchor = nil
                }
                var retryable = true
                if case .input = error as? SearchFailure { retryable = false }
                var retryAfter: Date?
                if case let .rateLimited(serverDate) = error as? SearchFailure {
                    self.throttleCount = min(self.throttleCount + 1, 5)
                    retryAfter = serverDate ?? Date().addingTimeInterval(min(60, 5 * pow(2, Double(self.throttleCount - 1))))
                    self.throttleUntil = retryAfter
                }
                if case .invalid = error as? RepositoryError { self.settings = nil }
                let needsSignIn = (error as? RepositoryError) == .unauthorized
                if needsSignIn || (error as? RepositoryError) == .denied || (error as? RepositoryError) == .unavailable {
                    self.hits = []; self.nextPage = nil; self.completed = false; self.anchor = nil
                }
                self.showingPreviousResults = operation == .refresh && self.completed
                self.accessInvalidationPending = accessFailure
                self.failure = Failure(attemptID: id, operation: accessFailure ? .initial : operation, message: error.localizedDescription, retryable: retryable, needsSignIn: needsSignIn, retryAfter: retryAfter, kind: error as? SearchFailure)
            }
        }
    }
    private func current(_ id: UUID, _ input: Input) -> Bool {
        attempt == id && self.input == input && trimmedQuery == input.query && !Task.isCancelled
    }
}
