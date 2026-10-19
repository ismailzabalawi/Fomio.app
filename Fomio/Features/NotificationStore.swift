import Foundation
import Observation

/// Account-scoped notification inbox. Discourse stays authoritative for rows, read state and totals; this store only
/// reconciles what the server returned. Every async result is discarded if the account changed meanwhile.
@MainActor @Observable final class NotificationStore {
    struct Feed: Equatable {
        var ids: [NotificationID] = []
        /// Raw history offset for the next request. Nil only when the server's total says the history ended.
        var nextOffset: Int? = 0
        var loading = false
        var loaded = false
        var pageError: String?
        /// The newest page returned no displayable rows while history continues (permission or Ignore filtering).
        var lastPageEmpty = false
    }
    let service: any CommunityService
    private(set) var account: AccountID
    private var generation = 0
    var pageSize = 60
    private(set) var items: [NotificationID: NotificationItem] = [:]
    private(set) var feeds: [NotificationFilter: Feed] = [.all: Feed(), .unread: Feed()]
    var filter: NotificationFilter = .all
    private(set) var totals: NotificationTotals?
    private(set) var acknowledgments: [NotificationID: AcknowledgmentState] = [:]
    private(set) var refreshing = false
    private(set) var refreshError: String?
    private(set) var lastUpdated: Date?
    var syncNote: String?
    /// Inbox scroll anchor, retained while destinations are pushed.
    var anchor: NotificationID?
    /// IDs this client acknowledged, so a later refresh can tell them apart from reads on another device.
    private var locallyRead: Set<NotificationID> = []
    /// Bumped whenever a feed's raw cursor is rewritten locally. A page request that started before the rewrite
    /// cannot be placed safely, so it is discarded and the feed restarts from the server.
    private var cursorEpoch: [NotificationFilter: Int] = [.all: 0, .unread: 0]
    /// Bumped by every confirmed read. A server snapshot taken before a confirmation can never turn that row back
    /// to unread, and an Unread refresh that overlapped one is fetched again.
    private var revision = 0
    private var readRevision: [NotificationID: Int] = [:]

    init(service: any CommunityService, account: AccountID) { self.service = service; self.account = account }

    var feed: Feed { feeds[filter] ?? Feed() }
    func rows(_ filter: NotificationFilter? = nil) -> [NotificationItem] { (feeds[filter ?? self.filter]?.ids ?? []).compactMap { items[$0] } }
    func item(_ id: NotificationID) -> NotificationItem? { items[id] }

    /// Clears every private row, cursor, acknowledgment and total. Called on sign-out and account changes.
    func reset(account: AccountID) {
        generation += 1
        self.account = account
        items = [:]; feeds = [.all: Feed(), .unread: Feed()]; totals = nil; acknowledgments = [:]
        refreshing = false; refreshError = nil; lastUpdated = nil; syncNote = nil; anchor = nil; locallyRead = []; filter = .all
        cursorEpoch = [.all: 0, .unread: 0]; revision = 0; readRevision = [:]
    }

    func loadIfNeeded() async { if feeds[filter]?.loaded != true { await loadMore() } }

    /// Loads the next raw history window. A window that yields nothing displayable is not the end of history.
    func loadMore(hiding hidden: (NotificationItem) -> Bool = { _ in false }) async {
        let filter = self.filter
        guard var feed = feeds[filter], !feed.loading, let offset = feed.nextOffset else { return }
        let token = generation, epoch = cursorEpoch[filter], snapshot = revision
        feed.loading = true; feed.pageError = nil; feeds[filter] = feed
        do {
            let page = try await service.notificationHistory(offset: offset, limit: pageSize, filter: filter)
            guard token == generation else { return }
            guard epoch == cursorEpoch[filter] else {
                // The unread history shifted (an acknowledgment landed) while this page was in flight. Its rows may
                // sit on either side of the shift, so restart the feed rather than risk skipping a row.
                restart(filter)
                if filter == self.filter { await loadMore(hiding: hidden) }
                return
            }
            merge(page.items, snapshot: snapshot)
            feed = feeds[filter] ?? Feed()
            let fresh = page.items.map(\.id).filter { !feed.ids.contains($0) }
            feed.ids += fresh
            feed.nextOffset = page.nextOffset
            feed.loaded = true
            feed.lastPageEmpty = page.nextOffset != nil && page.items.filter { !hidden($0) && (filter == .all || !$0.read) }.isEmpty
            feed.loading = false
            feeds[filter] = feed
            if offset == 0 { lastUpdated = Date(); refreshError = nil }
        } catch is CancellationError {
            if token == generation { feeds[filter]?.loading = false }
        } catch {
            guard token == generation else { return }
            feeds[filter]?.loading = false
            if feeds[filter]?.loaded == true { feeds[filter]?.pageError = error.localizedDescription }
            else { feeds[filter]?.pageError = error.localizedDescription; refreshError = error.localizedDescription }
        }
    }

    /// Re-reads the newest window and reconciles it with loaded rows. Never marks anything read.
    func refresh() async {
        let filter = self.filter
        guard !refreshing else { return }
        guard feeds[filter]?.loaded == true else { await loadMore(); await refreshTotals(); return }
        let token = generation
        refreshing = true; defer { if token == generation { refreshing = false } }
        do {
            var snapshot = revision, epoch = cursorEpoch[filter]
            var page = try await service.notificationHistory(offset: 0, limit: pageSize, filter: filter)
            guard token == generation else { return }
            // An Unread window fetched before a read was confirmed (or before its cursor moved) is placed against the
            // wrong offsets and would bring the read row back. Fetch again until a snapshot postdates every change.
            var attempts = 0
            while filter == .unread, snapshot != revision || epoch != cursorEpoch[filter], attempts < 3 {
                attempts += 1; snapshot = revision; epoch = cursorEpoch[filter]
                page = try await service.notificationHistory(offset: 0, limit: pageSize, filter: filter)
                guard token == generation else { return }
            }
            if filter == .unread, snapshot != revision || epoch != cursorEpoch[filter] {
                restart(filter); refreshError = nil; await loadMore(); return
            }
            let readElsewhere = page.items.filter { incoming in items[incoming.id].map { !$0.read && incoming.read && !locallyRead.contains(incoming.id) } ?? false }.count
            merge(page.items, snapshot: snapshot)
            var feed = feeds[filter] ?? Feed()
            let returned = page.items.map(\.id).filter { filter == .all || items[$0]?.read != true }
            let returnedSet = Set(returned)
            // Rows that the server no longer returns inside the window it just covered were consolidated, deleted or
            // hidden. Rows below the window are kept; the next offset is lowered by removals so nothing is skipped.
            let windowEnd = feed.ids.lastIndex { returnedSet.contains($0) } ?? -1
            var removed = Array(feed.ids.prefix(windowEnd + 1).filter { !returnedSet.contains($0) })
            var older = Array(feed.ids.dropFirst(windowEnd + 1).filter { !returnedSet.contains($0) })
            if windowEnd < 0 {
                // No returned row overlaps what was loaded: the window was replaced, filtered out or emptied, so no
                // old row can be verified as older. Restart from this authoritative first window.
                removed = feed.ids.filter { !returnedSet.contains($0) }; older = []
                feed.nextOffset = page.nextOffset
                feed.lastPageEmpty = page.nextOffset != nil && page.items.isEmpty
                cursorEpoch[filter, default: 0] += 1
            } else if page.nextOffset == nil {
                // The server says its whole history fits in this window: nothing older remains.
                removed += older; older = []; feed.nextOffset = nil
            } else if let next = feed.nextOffset {
                feed.nextOffset = max(page.nextOffset ?? 0, next - removed.count)
            }
            feed.ids = returned + older
            let other: NotificationFilter = filter == .all ? .unread : .all
            for id in removed { acknowledgments[id] = nil }
            feed.pageError = nil
            feeds[filter] = feed
            // The other filter's cursor is stale after a refresh; it reloads from the start when selected.
            if feeds[other]?.loaded == true || feeds[other]?.loading == true { restart(other) }
            // Rows no feed references any more (removed, replaced or newly inaccessible) leave memory with their titles.
            let kept = Set(feed.ids)
            items = items.filter { kept.contains($0.key) || acknowledgments[$0.key] != nil }
            refreshError = nil; lastUpdated = Date()
            if readElsewhere > 0 { syncNote = readElsewhere == 1 ? "Updated. 1 notification was read on another device." : "Updated. \(readElsewhere) notifications were read on another device." }
        } catch is CancellationError {
        } catch {
            guard token == generation else { return }
            refreshError = error.localizedDescription
        }
        await refreshTotals()
    }

    func select(_ filter: NotificationFilter) async {
        guard filter != self.filter else { return }
        self.filter = filter; anchor = nil
        await loadIfNeeded()
    }

    func refreshTotals() async {
        let token = generation
        do {
            let value = try await service.notificationTotals()
            guard token == generation else { return }
            totals = value
        } catch {
            // A failed total keeps the last verified value; it is never replaced by a count of loaded rows.
        }
    }

    /// Exact-ID acknowledgment after the destination is displayed. Failure and unknown outcomes keep the row unread.
    func acknowledge(_ id: NotificationID) async {
        guard id.rawValue > 0, items[id]?.read != true else { return }
        switch acknowledgments[id] { case .pending?, .checking?: return; default: break }
        let token = generation
        acknowledgments[id] = .pending
        do {
            try await service.markNotificationRead(id)
            guard token == generation else { return }
            confirmRead(id)
        } catch RepositoryError.unconfirmed {
            guard token == generation else { return }
            acknowledgments[id] = .unknown
        } catch is CancellationError {
            if token == generation { acknowledgments[id] = .unknown }
        } catch {
            guard token == generation else { return }
            acknowledgments[id] = .failed(error.localizedDescription)
        }
        await refreshTotals()
    }

    /// Reconciles an unknown outcome from server truth. Only a returned row is evidence: read → confirmed, unread →
    /// failed. Absence proves nothing, because permission and badge filtering remove rows after the query.
    func recheck(_ id: NotificationID) async {
        let token = generation, snapshot = revision
        acknowledgments[id] = .checking
        var offset: Int? = 0
        var pages = 0
        do {
            while let current = offset, pages < 5 {
                let page = try await service.notificationHistory(offset: current, limit: pageSize, filter: .all)
                guard token == generation else { return }
                if let found = page.items.first(where: { $0.id == id }) {
                    if found.read { merge([found], snapshot: snapshot); confirmRead(id) }
                    else if readRevision[id].map({ $0 > snapshot }) == true { /* confirmed meanwhile */ }
                    else { merge([found], snapshot: snapshot); acknowledgments[id] = .failed("Not marked as read. It stays unread.") }
                    await refreshTotals(); return
                }
                offset = page.nextOffset; pages += 1
            }
            guard token == generation else { return }
            acknowledgments[id] = .unknown
        } catch {
            guard token == generation else { return }
            acknowledgments[id] = .unknown
        }
        await refreshTotals()
    }

    /// A positive server confirmation that `id` is read. The row leaves the Unread feed and that feed's raw cursor
    /// moves back by one, because Discourse applies `read: false` before `offset`.
    private func confirmRead(_ id: NotificationID) {
        items[id]?.read = true; locallyRead.insert(id); acknowledgments[id] = nil
        revision += 1; readRevision[id] = revision
        guard var unread = feeds[.unread], let index = unread.ids.firstIndex(of: id) else {
            if feeds[.unread]?.loading == true { cursorEpoch[.unread, default: 0] += 1 }
            return
        }
        unread.ids.remove(at: index)
        if let next = unread.nextOffset { unread.nextOffset = max(0, next - 1) }
        feeds[.unread] = unread
        cursorEpoch[.unread, default: 0] += 1
    }
    private func restart(_ filter: NotificationFilter) {
        feeds[filter] = Feed(); cursorEpoch[filter, default: 0] += 1
    }

    /// Inserts or updates rows by ID. Existing rows take the server's current read state and content.
    private func merge(_ incoming: [NotificationItem], snapshot: Int) {
        for var item in incoming {
            // A snapshot older than this client's confirmed read cannot downgrade it.
            if !item.read, let confirmed = readRevision[item.id], confirmed > snapshot { item.read = true }
            if let existing = items[item.id], existing.categoryID != nil, item.categoryID == nil { item.categoryID = existing.categoryID }
            if item.read { acknowledgments[item.id] = nil }
            items[item.id] = item
        }
    }
}
