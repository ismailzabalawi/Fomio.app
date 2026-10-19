import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable { case home, communities, notifications, me; var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { switch self { case .home: "house"; case .communities: "square.grid.2x2"; case .notifications: "bell"; case .me: "person.crop.circle" } }
}
enum Route: Hashable { case community(CategoryID), discussion(TopicID, PostNumber?), thread(TopicID, PostNumber), search, profile(String), saved, drafts, credits, diagnostics, denied(CategoryID), unavailable, notificationInfo(NotificationID), notificationSettings, notificationMismatch(String) }
/// Why a discussion opened at a specific post. Shown as a text label on that post.
enum FocusReason: Hashable {
    case notification, search, saved, published
    /// Consolidated replies: the parent post or topic plus its new replies, never one author's exact reply.
    case groupedReplies(Int)
    var label: String { switch self { case .notification: "From your notification"; case .search: "Search match"; case .saved: "Saved reply"; case .published: "Your reply"; case let .groupedReplies(count): "Your post · \(count) new replies" } }
    var fromNotification: Bool { switch self { case .notification, .groupedReplies: true; default: false } }
}
/// The member action that asked for sign-in; it names the action and is restored afterwards, never auto-applied.
enum AuthGate: Equatable {
    case signIn, reply, quote, like, save, create(String?), notification
    var title: String {
        switch self { case .notification: "Sign in to open this notification"; case .signIn: "Sign in"; case .reply: "Sign in to reply"; case .quote: "Sign in to quote"; case .like: "Sign in to like posts"; case .save: "Sign in to save discussions"; case .create: "Sign in to start a discussion" }
    }
    var message: String {
        switch self {
        case .reply, .quote: "You’ll come back to this discussion with your reply open. Nothing is posted until you tap Post."
        case let .create(name): name.map { "You’ll come back with a new discussion in \($0) open. Nothing is posted until you tap Post." } ?? "You’ll come back and choose a community. Nothing is posted until you tap Post."
        case .like, .save: "You’ll come back to this post. Nothing is applied until you tap it again."
        case .signIn: "Reply to discussions, save them for later and get notified when someone replies to you."
        case .notification: "Your session on the community ended. After you sign in, Fomio takes you to the notification you tapped."
        }
    }
}
/// A post queued for review. It is never shown as published.
struct PendingNotice: Equatable { var tab: AppTab; var depth: Int; var isReply: Bool; var categoryName: String?
    var message: String { isReply ? "Your reply isn’t published yet. It has no post number and doesn’t count as a reply until a moderator approves it." : "Your discussion\(categoryName.map { " in \($0)" } ?? "") isn’t published yet. A moderator needs to approve it first." }
}
@MainActor @Observable final class TabState {
    var path: [Route] = []
    var communityQuery = ""
    var directoryInitialized = false
    var expandedCommunities: Set<CategoryID> = []
    var searchQuery = ""
    var searchResults: [DiscussionSummary] = []
    var searchNextPage: Int?
    var searchCompletedQuery: String?
    var searchAnchor: TopicID?
    var feeds: [String: FeedState] = [:]
    var discussions: [Route: DiscussionState] = [:]
    var focus: [Route: FocusReason] = [:]
    /// Notification to acknowledge once the pushed destination has been displayed.
    var acknowledgments: [Route: NotificationID] = [:]
    /// Which notification opened a route, kept for status and unavailable copy after acknowledgment starts.
    var notificationRoutes: [Route: NotificationID] = [:]
    func feed(key: String) -> FeedState { if let value = feeds[key] { return value }; let value = FeedState(); feeds[key] = value; return value }
}
@MainActor @Observable final class AppState {
    static let fixtureMember = "jonah.w"
    var selectedTab: AppTab = .home
    var tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) })
    var communities: [Community] = []
    var siteTheme = SiteTheme()
    var themeError: String?
    var communitiesLoaded = false
    var communityError: String?
    var account: AccountID = .guest
    var username: String?
    var safety: SafetySession?
    var safetyError: String?
    var safetyRevision = 0
    var safetyChanging: Set<String> = []
    var displayName: String?
    var composer: ComposerState?
    var authRequested = false
    var gate: AuthGate = .signIn
    var pendingAction: (@MainActor () async -> Void)?
    var banner: String?
    var toastMessage: String?
    var pendingNotice: PendingNotice?
    var guestNoteDismissed = false
    let notifications: NotificationStore
    let device: NotificationDevice
    /// A notification tap waiting for sign-in or for the composer to be finished. It never posts anything.
    var pendingIntent: NotificationIntent?
    var intentNeedsComposerDecision = false
    var duplicateTaps = 0
    var webDestination: URL?
    @ObservationIgnored private var recentIntents: [String: Date] = [:]
    @ObservationIgnored private var lastForegroundRefresh: Date?
    var draftsRevision = 0
    let service: any CommunityService
    let draftStore: DraftStore
    let fixture: FixtureService?
    let auth: AuthenticationService?
    let configuration: LiveConfiguration?
    let connectivity = Connectivity()
    let isConfigured: Bool
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    init(service: any CommunityService, fixture: FixtureService?, configuration: LiveConfiguration?, store: DraftStore = DraftStore()) {
        self.service = service; self.fixture = fixture; self.configuration = configuration; self.draftStore = store
        self.isConfigured = fixture != nil || configuration != nil
        self.auth = configuration.map { AuthenticationService(configuration: $0) }
        self.notifications = NotificationStore(service: service, account: .guest)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        self.device = fixture != nil ? NotificationDevice(permissions: SimulatedAlertPermission(), enrollments: SimulatedAlertEnrollment(), isPad: isPad) : NotificationDevice(permissions: SystemAlertPermission(), enrollments: UnavailableAlertEnrollment(), isPad: isPad)
        if fixture != nil { notifications.pageSize = 6 }
        if fixture != nil, !ProcessInfo.processInfo.arguments.contains("--guest") { account = .fixture; username = Self.fixtureMember; displayName = "Jonah Wells" }
        notifications.reset(account: account); device.bind(account: account)
        do { try draftStore.reconcileFiles(account: account) } catch { banner = error.localizedDescription }
    }
    var isOffline: Bool { fixture?.offline == true || (fixture == nil && connectivity.offline) }
    func loadCommunities() async {
        do {
            communities = try await service.communities(); communitiesLoaded = true; communityError = nil
            if let tab = tabs[.communities], !tab.directoryInitialized {
                tab.expandedCommunities = Set(communities.filter { $0.parentID == nil }.prefix(2).map(\.id))
                tab.directoryInitialized = true
            }
        } catch { communityError = error.localizedDescription }
    }
    func loadTheme() async {
        do { siteTheme = try await service.siteTheme(); FomioTheme.current = siteTheme; themeError = nil }
        catch { themeError = error.localizedDescription }
    }
    /// Server-scoped badge (see `NotificationTotals`). Never derived from loaded rows.
    var notificationBadge: String? { username == nil ? nil : notifications.totals?.badgeText }
    func refreshNotificationTotals() async { guard username != nil else { return }; await notifications.refreshTotals() }
    /// Foreground, reconnect and manual triggers re-read server state. None of them marks anything read.
    func foregroundRefresh(force: Bool = false) async {
        guard username != nil, notifications.account == account else { return }
        if !force, let last = lastForegroundRefresh, Date().timeIntervalSince(last) < 30 { return }
        lastForegroundRefresh = Date()
        if notifications.feed.loaded { await notifications.refresh() } else { await notifications.refreshTotals() }
    }
    var notificationSite: URL? { configuration?.baseURL ?? (fixture != nil ? NotificationFixture.site : nil) }
    /// Opens a notification's permitted destination. Acknowledgment waits until the destination is displayed.
    func open(notification item: NotificationItem, in tab: AppTab = .notifications) {
        let destination = NotificationResolver.destination(item, site: notificationSite, username: username)
        let route: Route
        let focus: FocusReason?
        switch destination {
        case let .post(topic, number): route = .discussion(topic, number); focus = .notification
        case let .topic(topic): route = .discussion(topic, nil); focus = nil
        case let .groupedReplies(topic, parent, count):
            route = parent.map { .thread(topic, $0) } ?? .discussion(topic, nil); focus = .groupedReplies(count)
        case .website, .unsupported: navigate(.notificationInfo(item.id), in: tab); return
        }
        // A previous visit's cached state must not count as displaying this notification's target.
        tabs[tab]?.discussions[route] = nil
        if item.id.rawValue > 0 { tabs[tab]?.acknowledgments[route] = item.id; tabs[tab]?.notificationRoutes[route] = item.id }
        tabs[tab]?.focus[route] = focus
        navigate(route, in: tab, focus: focus)
    }
    /// Called by the discussion screen after it rendered a successful load of `route`.
    func displayed(_ route: Route, state: DiscussionState) {
        guard let tab = tabs.first(where: { $0.value.acknowledgments[route] != nil })?.key, let id = tabs[tab]?.acknowledgments[route] else { return }
        guard state.requiredContentReady else { return }
        if case let .discussion(_, number?) = route, state.highlighted?.number != number { return }
        tabs[tab]?.acknowledgments[route] = nil
        let account = self.account
        Task { guard self.account == account, self.notifications.account == account else { return }; await self.notifications.acknowledge(id) }
    }
    /// Validates and routes a notification tap. Unknown sites, other accounts and duplicates are refused.
    func receive(_ intent: NotificationIntent) async {
        let now = Date()
        recentIntents = recentIntents.filter { now.timeIntervalSince($0.value) < 10 }
        if recentIntents[intent.dedupeKey] != nil { duplicateTaps += 1; return }
        recentIntents[intent.dedupeKey] = now
        guard let site = notificationSite, Self.sameSite(intent.site, site) else { banner = "This notification is for a different community, so Fomio won’t open it."; return }
        selectedTab = .notifications
        guard let username else {
            pendingIntent = intent; tabs[.notifications]?.path = []
            pendingAction = nil; gate = .notification; authRequested = true; return
        }
        guard intent.username.caseInsensitiveCompare(username) == .orderedSame else {
            pendingIntent = nil; tabs[.notifications]?.path = [.notificationMismatch(intent.username)]; return
        }
        // An expired or revoked key must not reach protected content: confirm it first, keep the tap otherwise.
        let account = self.account
        let valid: Bool
        do { valid = try await service.credentialIsValid(username: username) } catch { valid = true }
        guard self.account == account, self.username == username else { return }
        guard valid else {
            pendingIntent = intent; tabs[.notifications]?.path = []
            pendingAction = nil; gate = .notification; authRequested = true; return
        }
        if let composer, composer.hasChanges || composer.locked {
            pendingIntent = intent; intentNeedsComposerDecision = true; return
        }
        composer?.close()
        route(intent)
    }
    private func route(_ intent: NotificationIntent) {
        pendingIntent = nil; intentNeedsComposerDecision = false
        selectedTab = .notifications; tabs[.notifications]?.path = []
        Task { await self.notifications.refresh() }
        open(notification: notifications.item(intent.notificationID ?? .init(0)) ?? intent.item)
    }
    /// Composer protection: Keep Writing holds the notification; Save Draft and Open keeps the draft locally first.
    func keepWritingWithPendingNotification() { intentNeedsComposerDecision = false }
    func saveDraftAndOpenPendingNotification() {
        guard let intent = pendingIntent, let composer, !composer.locked || composer.draft.submission != .submitting else { return }
        composer.keepDraft(message: "Draft saved on this \(device.wording.device)")
        guard self.composer == nil else { intentNeedsComposerDecision = false; return }
        route(intent)
    }
    func composerClosed() {
        if let intent = pendingIntent, username != nil, !intentNeedsComposerDecision, composer == nil { route(intent) }
    }
    nonisolated static func sameSite(_ lhs: URL, _ rhs: URL) -> Bool {
        func key(_ url: URL) -> String { "\(url.scheme ?? "")://\(url.host?.lowercased() ?? ""):\(url.port ?? 443)\(url.path.hasSuffix("/") ? String(url.path.dropLast()) : url.path)" }
        return key(lhs) == key(rhs)
    }
    /// Public category assets may use the site's relative root or an HTTPS CDN. Never attach user keys.
    func publicAssetURL(_ value: String?) -> URL? { PublicMedia.url(value, base: configuration?.baseURL) }
    func category(_ id: CategoryID) -> Community? { communities.first { $0.id == id } }
    func categoryName(_ id: CategoryID) -> String {
        guard let value = category(id) else { return "Community" }
        if let parent = value.parentID.flatMap(category) { return "\(value.name) · \(parent.name)" }
        return value.name
    }
    func toast(_ message: String) {
        toastTask?.cancel(); toastMessage = message
        toastTask = Task { [weak self] in try? await Task.sleep(for: .seconds(3)); guard !Task.isCancelled else { return }; self?.toastMessage = nil }
    }
    func navigate(_ route: Route, in tab: AppTab? = nil, focus: FocusReason? = nil) {
        let tab = tab ?? selectedTab
        if let focus { tabs[tab]?.focus[route] = focus; tabs[tab]?.discussions[route]?.focus = focus }
        tabs[tab]?.path.append(route)
    }
    func search(_ query: String) {
        tabs[selectedTab]?.searchQuery = query; navigate(.search)
    }
    func requireMember(_ gate: AuthGate, _ action: @escaping @MainActor () async -> Void) {
        if username != nil { Task { await action() } } else { pendingAction = action; self.gate = gate; authRequested = true }
    }
    func requestSignIn() { pendingAction = nil; gate = .signIn; authRequested = true }
    func create(category: CategoryID? = nil) {
        requireMember(.create(category.flatMap { self.category($0)?.name })) { [weak self] in
            guard let self else { return }
            guard self.communities.contains(where: { $0.canCreate && (category == nil || $0.id == category) }) else { self.banner = "No permitted destination is available."; return }
            // Contextual Create inherits its community; global Create picks one in the composer's Post in field.
            self.openComposer(category: category)
        }
    }
    func openComposer(category: CategoryID?) {
        composer = ComposerState(draft: Draft(account: account, intent: .newDiscussion, categoryID: category), app: self, origin: selectedTab)
    }
    func reply(to post: Post, quote: Bool = false) {
        requireMember(quote ? .quote : .reply) { [weak self] in
            guard let self else { return }
            let current: Post
            let page: DiscussionPage
            do {
                let context = try await self.service.context(topic: post.topicID, number: post.number, focused: true)
                guard context.page.canReply, !context.target.post.deleted, !context.target.post.ignored else { self.banner = "Replies are not permitted here."; return }
                current = context.target.post; page = context.page
            } catch { self.banner = error.localizedDescription; return }
            var draft = Draft(account: self.account, intent: .reply(topic: current.topicID, parent: current.number))
            draft.contextTitle = page.summary.title; draft.contextCategory = page.summary.categoryID
            if current.number.rawValue > 1 { draft.targetAuthor = current.author }
            if quote { draft.quote = QuoteExcerpt(author: current.author, number: current.number, text: current.body) }
            self.composer = ComposerState(draft: draft, app: self, origin: self.selectedTab)
        }
    }
    func resume(_ draft: Draft) { composer = ComposerState(draft: draft, app: self, origin: selectedTab, resumed: true) }
    func signIn() async {
        do {
            if let fixture { username = Self.fixtureMember; displayName = "Jonah Wells"; account = .fixture; fixture.credentialExpired = false }
            else if let auth { let member = try await auth.signIn(); username = member; account = .init(rawValue: "\(configuration!.baseURL.absoluteString):\(member)") }
            else { throw RepositoryError.configuration }
            if let composer, composer.draft.account != account { self.composer = nil; banner = "The previous account’s draft remains private to that account." }
            if notifications.account != account { notifications.reset(account: account); device.bind(account: account) }
            try draftStore.migrateGuest(to: account)
            if composer == nil { try draftStore.reconcileFiles(account: account) }
            let action = pendingAction, gate = self.gate, intent = pendingIntent; pendingAction = nil; pendingIntent = nil
            authRequested = false; await refreshSafety(); await loadTheme(); await loadCommunities(); await action?()
            let name = username ?? "member"
            switch gate {
            case .reply, .quote: toast("Signed in as \(name). Your reply is ready.")
            case .like: toast("Signed in as \(name). Tap again to like the post.")
            case .save: toast("Signed in as \(name). Tap again to save.")
            case .notification: toast("Signed in as \(name).")
            default: toast("Signed in as \(name).")
            }
            self.gate = .signIn
            await refreshNotificationTotals()
            if let intent { forgetIntent(intent); await receive(intent) }
        } catch { banner = error.localizedDescription }
    }
    func restoreAccount() async {
        guard fixture == nil, let auth, let configuration else { return }
        do {
            if try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString) != nil {
                let name = try await auth.currentUsername(); username = name; account = .init(rawValue: "\(configuration.baseURL.absoluteString):\(name)")
            }
            if notifications.account != account { notifications.reset(account: account); device.bind(account: account) }
            if composer == nil { try draftStore.reconcileFiles(account: account) }
        } catch { banner = error.localizedDescription }
    }
    func signOut() {
        composer?.stopUploads()
        do { try draftStore.clear(account: account); try auth?.signOut() }
        catch { banner = "Sign-out could not finish: \(error.localizedDescription)"; return }
        account = .guest; username = nil; safety = nil; safetyError = nil; safetyChanging = []; displayName = nil; pendingAction = nil; composer = nil; pendingNotice = nil; guestNoteDismissed = false
        // Private notification rows, cursors, totals, pending taps and acknowledgments belong to the old account.
        notifications.reset(account: .guest); pendingIntent = nil; intentNeedsComposerDecision = false; recentIntents = [:]; webDestination = nil
        Task { await device.detach() }
        tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) }); draftsRevision += 1
        fixture?.bookmarks = [:]
        toast("Signed out")
        Task { await loadCommunities() }
    }
    func isBlocked(_ name: String) -> Bool {
        guard safety?.username == username else { return false }
        return safety?.ignoredUsers.contains { $0.caseInsensitiveCompare(name) == .orderedSame } == true
    }
    func refreshSafety() async {
        guard let username else { safety = nil; safetyError = nil; return }
        let account = self.account
        do {
            let value = try await service.safetySession()
            guard self.account == account, self.username == username else { return }
            guard value.username.caseInsensitiveCompare(username) == .orderedSame else { throw RepositoryError.unauthorized }
            if safety?.ignoredUsers != value.ignoredUsers { safetyRevision += 1 }
            safety = value; safetyError = nil
        } catch { if self.account == account { safetyError = error.localizedDescription } }
    }
    func changeBlocking(_ name: String, blocked: Bool) async throws {
        let key = name.lowercased()
        guard let username, !safetyChanging.contains(key) else { return }
        let account = self.account
        safetyChanging.insert(key); defer { safetyChanging.remove(key) }
        let result = try await service.setIgnored(username: name, ignored: blocked)
        guard self.account == account, self.username == username, result.username.caseInsensitiveCompare(username) == .orderedSame else { throw RepositoryError.unauthorized }
        safety = result; safetyError = nil; safetyRevision += 1
        // Clear list caches so unblocking reloads content that the server omitted while ignored.
        for tab in tabs.values { tab.feeds = [:]; tab.discussions = [:]; tab.searchResults = []; tab.searchCompletedQuery = nil; tab.searchNextPage = nil }
        toast(blocked ? "Member blocked" : "Member unblocked")
    }
    func published(topic: TopicID, number: PostNumber, origin: AppTab, isReply: Bool, categoryID: CategoryID?) {
        composer = nil; selectedTab = origin
        tabs[origin]?.discussions = [:]; tabs[origin]?.feeds = [:]
        let route = Route.discussion(topic, number)
        // Replace the discussion the reply was written from, so Back does not return to a stale copy.
        if isReply, case let .discussion(current, _)? = tabs[origin]?.path.last, current == topic { tabs[origin]?.path.removeLast() }
        navigate(route, in: origin, focus: isReply ? .published : nil); draftsRevision += 1
        toast(isReply ? "Reply posted" : "Discussion posted in \(categoryID.flatMap { category($0)?.name } ?? "the community")")
    }
    func discussionState(_ route: Route) -> DiscussionState {
        let tab = tabs[selectedTab]!
        if let state = tab.discussions[route] { return state }
        let state = DiscussionState(route: route, service: service)
        state.focus = tab.focus[route]
        tab.discussions[route] = state; return state
    }
    func forgetIntent(_ intent: NotificationIntent) { recentIntents[intent.dedupeKey] = nil }
    func handleLink(_ url: URL) {
        if auth?.receiveCallback(url) == true { return }
        guard let configuration, let route = LinkRouter.route(url, baseURL: configuration.baseURL) else { banner = "This link is not a supported community destination."; return }
        navigate(route)
    }
}
