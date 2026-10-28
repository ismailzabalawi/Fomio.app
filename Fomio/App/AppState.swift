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
    var browseScope: BrowseScope = .all
    var discussionSearch = DiscussionSearchState()
    var readingSelectionRevision = 0
    var feeds: [String: FeedState] = [:]
    var discussions: [Route: DiscussionState] = [:]
    var focus: [Route: FocusReason] = [:]
    /// Notification to acknowledge once the pushed destination has been displayed.
    var acknowledgments: [Route: NotificationID] = [:]
    /// Which notification opened a route, kept for status and unavailable copy after acknowledgment starts.
    var notificationRoutes: [Route: NotificationID] = [:]
    func feed(key: String) -> FeedState { if let value = feeds[key] { return value }; let value = FeedState(); feeds[key] = value; return value }
}
/// Refuses the same notification tap delivered twice within ten seconds, whichever window receives it.
struct TapFilter {
    private var recent: [String: Date] = [:]
    private(set) var duplicates = 0
    mutating func accept(_ intent: NotificationIntent, now: Date = Date()) -> Bool {
        recent = recent.filter { now.timeIntervalSince($0.value) < 10 }
        if recent[intent.dedupeKey] != nil { duplicates += 1; return false }
        recent[intent.dedupeKey] = now; return true
    }
    mutating func forget(_ intent: NotificationIntent) { recent[intent.dedupeKey] = nil }
    mutating func clear() { recent = [:] }
}
/// Process-wide identity, draft ownership and notifications; browsing state belongs to each scene.
@MainActor @Observable final class AppWindows {
    let service: any CommunityService
    let fixture: FixtureService?
    let configuration: LiveConfiguration?
    let store: DraftStore
    let auth: AuthenticationService?
    private(set) var account: AccountID
    private(set) var username: String?
    private(set) var displayName: String?
    private(set) var identityRevision = 0
    var draftsRevision = 0
    /// One inbox, read state and badge for every window: a read confirmed in one window shows in the others at once.
    let notifications: NotificationStore
    /// Alert permission and enrollment belong to the device, not to a window.
    let device: NotificationDevice
    @ObservationIgnored var taps = TapFilter()
    /// Taps that arrived before any window finished launching (a cold start from an alert).
    @ObservationIgnored private var heldIntents: [NotificationIntent] = []
    @ObservationIgnored private weak var lastActive: AppState?
    private struct Window { weak var state: AppState? }
    @ObservationIgnored private var windows: [Window] = []

    init(service: any CommunityService, fixture: FixtureService?, configuration: LiveConfiguration?, store: DraftStore = DraftStore()) {
        self.service = service; self.fixture = fixture; self.configuration = configuration; self.store = store
        auth = configuration.map { AuthenticationService(configuration: $0) }
        let member = fixture != nil && !ProcessInfo.processInfo.arguments.contains("--guest")
        account = member ? .fixture : .guest
        username = member ? AppState.fixtureMember : nil
        displayName = member ? "Jonah Wells" : nil
        (notifications, device) = AppState.makeNotifications(service: service, fixture: fixture, account: member ? .fixture : .guest)
    }
    func makeWindow() -> AppState { AppState(service: service, fixture: fixture, configuration: configuration, store: store, windows: self) }
    func register(_ state: AppState) {
        windows.removeAll { $0.state == nil }; windows.append(Window(state: state))
        state.account = account; state.username = username; state.displayName = displayName
    }
    func unregister(_ state: AppState) {
        windows.removeAll { $0.state == nil || $0.state === state }
        if lastActive === state { lastActive = nil }
    }
    var states: [AppState] { windows.compactMap(\.state) }
    /// The window a notification tap opens in: the one used most recently, else the newest launched window.
    var notificationTarget: AppState? {
        let ready = states.filter(\.acceptsNotifications)
        if let lastActive, ready.contains(where: { $0 === lastActive }) { return lastActive }
        return ready.last
    }
    /// Installs the process-wide alert handlers once, rather than letting whichever window launched last win.
    func installNotificationHandlers(_ incoming: IncomingNotifications = .shared) {
        incoming.foreground = { [weak self] in Task { await self?.notificationTarget?.foregroundRefresh(force: true) } }
        incoming.handler = { [weak self] intent in self?.deliver(intent) }
    }
    func deliver(_ intent: NotificationIntent) {
        guard let target = notificationTarget else { heldIntents.append(intent); return }
        Task { await target.receive(intent) }
    }
    func activated(_ state: AppState) { lastActive = state }
    /// A window finished restoring the account and its first load; held taps open there.
    func windowReady(_ state: AppState) {
        state.acceptsNotifications = true
        if lastActive == nil { lastActive = state }
        let held = heldIntents; heldIntents = []
        for intent in held { Task { await state.receive(intent) } }
    }
    func editor(for id: UUID) -> AppState? { states.first { $0.ownedDraftID == id } }
    var openDrafts: [Draft] { states.flatMap { $0.ownedDrafts } }
    func expireAuthentication() {
        identityRevision += 1; username = nil
        for state in states { state.receiveExpiredAuthentication() }
    }
    func publish(account: AccountID, username: String?, displayName: String?, from origin: AppState, signingOut: Bool = false) {
        identityRevision += 1
        self.account = account; self.username = username; self.displayName = displayName
        // Cleared and detached once here; each window then drops its own pending tap and read-on-display bookkeeping.
        AppState.rebind(notifications, device, to: account, signingOut: signingOut)
        if signingOut { taps.clear(); heldIntents = [] }
        for state in states {
            state.receiveAccount(account, username: username, displayName: displayName, signingOut: signingOut, preserveIntent: state === origin)
        }
    }
}
@MainActor @Observable final class AppState {
    static let fixtureMember = "jonah.w"
    var selectedTab: AppTab = .home
    var tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) })
    var communities: [Community] = []
    var siteTheme = SiteTheme()
    var themeError: String?
    var communitiesLoaded = false
    var catalogRevision = 0
    @ObservationIgnored private var catalogRequest: UUID?
    @ObservationIgnored private var categoryRequests: [CategoryID: UUID] = [:]
    private var resolvedCategories: [CategoryID: Community] = [:]
    var resolvingCategories: Set<CategoryID> = []
    var categoryResolutionErrors: [CategoryID: String] = [:]
    var communityError: String?
    var account: AccountID = .guest
    var username: String?
    var safety: SafetySession?
    var safetyError: String?
    var safetyRevision = 0
    var safetyChanging: Set<String> = []
    var displayName: String?
    private var presentedComposer: ComposerState?
    private var suspendedComposer: ComposerState?
    @ObservationIgnored private var completingAuthentication = false
    var ownedDraftID: UUID? { presentedComposer?.id ?? suspendedComposer?.id }
    var ownedDrafts: [Draft] { [presentedComposer?.draft, suspendedComposer?.draft].compactMap { $0 } }
    func reserveForAuthentication(_ composer: ComposerState) { suspendedComposer = composer }
    func cancelAuthenticationIntent() {
        guard !completingAuthentication else { return }
        pendingAction = nil; suspendedComposer = nil; gate = .signIn
        if username == nil { pendingIntent = nil }
    }
    var composer: ComposerState? {
        get { presentedComposer }
        set {
            if let newValue, let ownedDraftID, newValue.id != ownedDraftID {
                banner = String(localized: "Finish or close your current draft first."); return
            }
            if let newValue, let owner = windows?.editor(for: newValue.id), owner !== self {
                banner = String(localized: "This draft is already open in another window."); return
            }
            guard presentedComposer !== newValue else { return }
            presentedComposer?.deactivate()
            presentedComposer = newValue
            if newValue?.id == suspendedComposer?.id { suspendedComposer = nil }
            newValue?.activate()
        }
    }
    var authRequested = false
    var gate: AuthGate = .signIn
    var pendingAction: (@MainActor () async -> Void)?
    var banner: String?
    var toastMessage: String?
    var pendingNotice: PendingNotice?
    var guestNoteDismissed = false
    /// Shared with every window through `windows`; a stand-alone state (unit tests) owns its own pair.
    let notifications: NotificationStore
    let device: NotificationDevice
    /// A notification tap waiting for sign-in or for this window's composer to be finished. It never posts anything.
    var pendingIntent: NotificationIntent?
    var intentNeedsComposerDecision = false
    var webDestination: URL?
    /// Set once this window has restored the account and finished its first load; taps are routed only then.
    @ObservationIgnored var acceptsNotifications = false
    @ObservationIgnored private var localTaps = TapFilter()
    private var taps: TapFilter {
        get { windows?.taps ?? localTaps }
        set { if let windows { windows.taps = newValue } else { localTaps = newValue } }
    }
    var duplicateTaps: Int { taps.duplicates }
    private var localDraftsRevision = 0
    var draftsRevision: Int {
        get { windows?.draftsRevision ?? localDraftsRevision }
        set { if let windows { windows.draftsRevision = newValue } else { localDraftsRevision = newValue } }
    }
    let windows: AppWindows?
    private(set) var identityRevision = 0
    let service: any CommunityService
    let draftStore: DraftStore
    let fixture: FixtureService?
    let auth: AuthenticationService?
    let configuration: LiveConfiguration?
    let connectivity = Connectivity()
    let isConfigured: Bool
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    init(service: any CommunityService, fixture: FixtureService?, configuration: LiveConfiguration?, store: DraftStore = DraftStore(), windows: AppWindows? = nil) {
        self.windows = windows
        self.service = service; self.fixture = fixture; self.configuration = configuration; self.draftStore = store
        self.isConfigured = fixture != nil || configuration != nil
        self.auth = windows?.auth ?? configuration.map { AuthenticationService(configuration: $0) }
        let member = fixture != nil && !ProcessInfo.processInfo.arguments.contains("--guest")
        if let windows { notifications = windows.notifications; device = windows.device }
        else { (notifications, device) = Self.makeNotifications(service: service, fixture: fixture, account: member ? .fixture : .guest) }
        if member { account = .fixture; username = Self.fixtureMember; displayName = "Jonah Wells" }
        windows?.register(self)
        do { try reconcileDraftFiles() } catch { banner = error.localizedDescription }
    }
    static func makeNotifications(service: any CommunityService, fixture: FixtureService?, account: AccountID) -> (NotificationStore, NotificationDevice) {
        let store = NotificationStore(service: service, account: account)
        if fixture != nil { store.pageSize = 6 }
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let device = fixture != nil ? NotificationDevice(permissions: SimulatedAlertPermission(), enrollments: SimulatedAlertEnrollment(), isPad: isPad) : NotificationDevice(permissions: SystemAlertPermission(), enrollments: UnavailableAlertEnrollment(), isPad: isPad)
        device.bind(account: account)
        return (store, device)
    }
    /// Private rows, cursors, totals and acknowledgments belong to one account; sign-out also detaches device alerts.
    static func rebind(_ notifications: NotificationStore, _ device: NotificationDevice, to account: AccountID, signingOut: Bool) {
        if signingOut { notifications.reset(account: .guest); Task { await device.detach() } }
        else if notifications.account != account { notifications.reset(account: account); device.bind(account: account) }
    }
    func closeWindow() {
        identityRevision += 1
        if let composer, composer.hasChanges { _ = composer.save() }
        composer = nil; suspendedComposer = nil; pendingAction = nil; pendingIntent = nil
        windows?.unregister(self)
    }
    /// Notification taps go to the window used most recently.
    func becameActive() { windows?.activated(self) }
    func notificationsReady() { if let windows { windows.windowReady(self) } else { acceptsNotifications = true } }
    var isOffline: Bool { fixture?.offline == true || (fixture == nil && connectivity.offline) }
    func loadCommunities() async {
        let request = UUID(), viewer = account
        catalogRequest = request
        do {
            let catalog = try await service.communities()
            guard catalogRequest == request, account == viewer else { return }
            if communities != catalog { catalogRevision += 1 }
            communities = catalog; communitiesLoaded = true; communityError = nil
            if let tab = tabs[.communities], !tab.directoryInitialized {
                tab.expandedCommunities = Set(communities.filter { $0.parentID == nil }.prefix(2).map(\.id))
                tab.directoryInitialized = true
            }
        } catch { if catalogRequest == request && account == viewer { communityError = error.localizedDescription } }
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
        // Throttled on the shared store, so several windows becoming active make one request.
        if !force, let last = notifications.lastForegroundRefresh, Date().timeIntervalSince(last) < 30 { return }
        notifications.lastForegroundRefresh = Date()
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
        guard taps.accept(intent) else { return }
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
            // Every window learns the session ended; only this one asks to sign in and keeps the tap.
            authenticationExpired()
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
    func category(_ id: CategoryID) -> Community? { communities.first { $0.id == id } ?? resolvedCategories[id] }
    /// Discussions in a scope from Discourse's cached per-category counts: a category plus its visible
    /// children, or every visible community for All. Nil when the site omits any needed count.
    func topicCount(_ scope: BrowseScope) -> Int? {
        let visible = communities.filter { !$0.restricted }
        let included = scope.categoryID.map { id in visible.filter { $0.id == id || $0.parentID == id } } ?? visible
        guard !included.isEmpty else { return nil }
        return included.reduce(0 as Int?) { total, community in total.flatMap { sum in community.topicCount.map { sum + $0 } } }
    }
    /// Per window: hiding the sidebar returns destinations to the tab bar until it is shown again.
    var sidebarHidden = false
    var browseCatalog: [Community] {
        let known = Set(communities.map(\.id))
        return communities + resolvedCategories.values.filter { !known.contains($0.id) }.sorted { $0.id.rawValue < $1.id.rawValue }
    }
    func resolveCategory(_ id: CategoryID, retry: Bool = false) async {
        guard category(id) == nil, !resolvingCategories.contains(id), retry || categoryResolutionErrors[id] == nil else { return }
        let viewer = account, request = UUID()
        categoryRequests[id] = request
        resolvingCategories.insert(id)
        defer {
            if categoryRequests[id] == request { categoryRequests[id] = nil; resolvingCategories.remove(id) }
        }
        do {
            let value = try await service.community(id)
            guard account == viewer, categoryRequests[id] == request else { return }
            var ancestor: Community?
            if let parent = value.parentID, category(parent) == nil { ancestor = try await service.community(parent) }
            guard account == viewer, categoryRequests[id] == request, !Task.isCancelled else { return }
            resolvedCategories[id] = value; categoryResolutionErrors[id] = nil
            if let ancestor { resolvedCategories[ancestor.id] = ancestor }
            catalogRevision += 1
        } catch is CancellationError {} catch {
            if account == viewer, categoryRequests[id] == request { categoryResolutionErrors[id] = error.localizedDescription }
        }
    }
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
        if case let .community(id) = route { selectScope(.category(id), in: tab); return }
        if route == .search { tabs[tab]?.discussionSearch.revealed = true }
        if case .discussion = route { tabs[tab]?.readingSelectionRevision += 1 }
        if case .thread = route { tabs[tab]?.readingSelectionRevision += 1 }
        if let focus { tabs[tab]?.focus[route] = focus; tabs[tab]?.discussions[route]?.focus = focus }
        if case .discussion = route, let state = tabs[tab], let index = state.path.firstIndex(where: {
            if case .discussion = $0 { true } else if case .thread = $0 { true } else { false }
        }) {
            state.path = Array(state.path.prefix(index)) + [route]
            return
        }
        tabs[tab]?.path.append(route)
    }
    func search(_ query: String) {
        tabs[selectedTab]?.discussionSearch.query = query
        tabs[selectedTab]?.discussionSearch.revealed = true
        navigate(.search)
    }
    func selectScope(_ scope: BrowseScope, in origin: AppTab? = nil) {
        let tab = origin ?? selectedTab
        guard let state = tabs[tab] else { return }
        if state.browseScope != scope {
            if !state.discussionSearch.active { state.feeds[state.browseScope.feedKey]?.capturePosition() }
            state.feeds[scope.feedKey]?.needsPositionRestore = true
            state.discussionSearch.invalidateViewer()
        }
        state.browseScope = scope
        // Scope selection changes the list while retaining the selected reading route/cache.
        let index = state.path.firstIndex { if case .discussion = $0 { return true }; if case .thread = $0 { return true }; return false }
        let reading = index.map { Array(state.path[$0...]) } ?? []
        let list: [Route] = tab == .home ? [] : scope.categoryID.map { [.community($0)] } ?? [.search]
        state.path = list + reading
    }
    var searchViewer: SearchViewer {
        SearchViewer(site: configuration?.baseURL.absoluteString ?? "fixture", account: account, revision: catalogRevision &+ safetyRevision &+ identityRevision, locale: Locale.current.identifier, username: username)
    }
    func requireMember(_ gate: AuthGate, _ action: @escaping @MainActor () async -> Void) {
        if username != nil { Task { await action() } } else { pendingAction = action; self.gate = gate; authRequested = true }
    }
    func requestSignIn() { pendingAction = nil; gate = .signIn; authRequested = true }
    func create(category: CategoryID? = nil) {
        requireMember(.create(category.flatMap { self.category($0)?.name })) { [weak self] in
            guard let self else { return }
            guard self.browseCatalog.contains(where: { $0.canCreate && (category == nil || $0.id == category) }) else { self.banner = "No permitted destination is available."; return }
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
            // Reply continues a kept draft for the same post rather than starting a second one.
            if !quote, let kept = self.keptReplies(topic: post.topicID).first(where: { $0.intent == .reply(topic: post.topicID, parent: post.number) }) {
                self.resume(kept); return
            }
            let revision = self.identityRevision
            let current: Post
            let page: DiscussionPage
            do {
                let context = try await self.service.context(topic: post.topicID, number: post.number, focused: true)
                guard self.identityRevision == revision else { return }
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
    func resume(_ draft: Draft) {
        guard draft.account == account else { banner = String(localized: "This draft belongs to another account."); return }
        guard windows?.editor(for: draft.id) == nil else { banner = String(localized: "This draft is already open in another window."); return }
        // Reload after a different window has saved, rather than overwriting it with a stale list row.
        do {
            guard let latest = try draftStore.list(account: account).first(where: { $0.id == draft.id }) else { draftsRevision += 1; return }
            composer = ComposerState(draft: latest, app: self, origin: selectedTab, resumed: true)
        } catch { banner = error.localizedDescription }
    }
    /// Unsent replies kept on a topic, newest first, excluding any open in a window.
    func keptReplies(topic: TopicID) -> [Draft] {
        ((try? draftStore.list(account: account)) ?? []).filter {
            $0.intent.topicID == topic && $0.submission == .editing && composer?.id != $0.id && windows?.editor(for: $0.id) == nil
        }
    }
    func reconcileDraftFiles() throws {
        try draftStore.reconcileFiles(account: account, preserving: windows?.openDrafts ?? ownedDrafts)
    }
    func discardDraft(_ draft: Draft) throws {
        guard draft.account == account else { throw RepositoryError.unauthorized }
        guard windows?.editor(for: draft.id) == nil, composer?.id != draft.id else {
            throw RepositoryError.invalid(String(localized: "Close this draft in its window before discarding it."))
        }
        try draftStore.delete(draft.id); draftsRevision += 1
    }
    func receiveAccount(_ account: AccountID, username: String?, displayName: String?, signingOut: Bool, preserveIntent: Bool) {
        identityRevision += 1
        if signingOut || self.account != account {
            if !signingOut, let composer { _ = composer.save() }
            composer = nil; suspendedComposer = nil
            safety = nil; safetyError = nil; safetyChanging = []; pendingNotice = nil
            pendingIntent = nil; intentNeedsComposerDecision = false; webDestination = nil
            if windows == nil { Self.rebind(notifications, device, to: account, signingOut: signingOut); if signingOut { localTaps.clear() } }
            invalidateBrowseViewer()
            if signingOut { tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) }) }
        }
        self.account = account; self.username = username; self.displayName = displayName
        // A tap held for sign-in opens only in the window that signed in.
        if !preserveIntent || signingOut { pendingAction = nil; pendingIntent = nil; suspendedComposer = nil; gate = .signIn; authRequested = false }
        if signingOut { guestNoteDismissed = false }
    }
    /// `anchor` is the window presenting the sign-in UI; live authorization is shown over it.
    /// Fixture sign-in ignores it, so unit tests can omit the argument.
    func signIn(anchor: UIWindow? = nil) async {
        let epoch = windows?.identityRevision ?? identityRevision
        var acceptedEpoch = epoch
        do {
            let member: String
            if let fixture { member = Self.fixtureMember; fixture.credentialExpired = false }
            else if let auth { member = try await auth.signIn(anchor: anchor) }
            else { throw RepositoryError.configuration }
            guard epoch == (windows?.identityRevision ?? identityRevision) else { return }
            let next: AccountID = fixture != nil ? .fixture : .init(rawValue: "\(configuration!.baseURL.absoluteString):\(member)")
            let action = pendingAction, gate = self.gate, intent = pendingIntent
            if let windows { windows.publish(account: next, username: member, displayName: fixture != nil ? "Jonah Wells" : nil, from: self) }
            else { receiveAccount(next, username: member, displayName: fixture != nil ? "Jonah Wells" : nil, signingOut: false, preserveIntent: true) }
            acceptedEpoch = windows?.identityRevision ?? identityRevision
            completingAuthentication = true
            defer { completingAuthentication = false; suspendedComposer = nil }
            pendingAction = nil; pendingIntent = nil; authRequested = false
            try draftStore.migrateGuest(to: account); draftsRevision += 1
            try reconcileDraftFiles()
            let revision = identityRevision
            await refreshSafety(); await loadTheme(); await loadCommunities()
            guard identityRevision == revision else { return }
            await action?()
            guard identityRevision == revision else { return }
            switch gate {
            case .reply, .quote: toast("Signed in as \(member). Your reply is ready.")
            case .like: toast("Signed in as \(member). Tap again to like the post.")
            case .save: toast("Signed in as \(member). Tap again to save.")
            default: toast("Signed in as \(member).")
            }
            self.gate = .signIn
            await refreshNotificationTotals()
            if let intent, identityRevision == revision { forgetIntent(intent); await receive(intent) }
        } catch { if acceptedEpoch == (windows?.identityRevision ?? identityRevision) { banner = error.localizedDescription } }
    }
    func restoreAccount() async {
        guard fixture == nil, let auth, let configuration else { return }
        let epoch = windows?.identityRevision ?? identityRevision
        do {
            if try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString) != nil {
                let name = try await auth.currentUsername()
                guard epoch == (windows?.identityRevision ?? identityRevision) else { return }
                let next = AccountID(rawValue: "\(configuration.baseURL.absoluteString):\(name)")
                if next != account || username != name {
                    if let windows { windows.publish(account: next, username: name, displayName: nil, from: self) }
                    else { receiveAccount(next, username: name, displayName: nil, signingOut: false, preserveIntent: true) }
                }
            }
            try reconcileDraftFiles()
        } catch { if epoch == (windows?.identityRevision ?? identityRevision) { banner = error.localizedDescription } }
    }
    func receiveExpiredAuthentication() {
        identityRevision += 1
        username = nil; safety = nil; pendingAction = nil
        composer?.expired = true
        invalidateBrowseViewer()
    }
    func authenticationExpired() {
        if let windows { windows.expireAuthentication() } else { receiveExpiredAuthentication() }
    }
    func signOut() {
        do { try draftStore.clear(account: account); try auth?.signOut() }
        catch { banner = "Sign-out could not finish: \(error.localizedDescription)"; return }
        // Synchronous broadcast cancels every editor before another autosave can run.
        if let windows { windows.publish(account: .guest, username: nil, displayName: nil, from: self, signingOut: true) }
        else { receiveAccount(.guest, username: nil, displayName: nil, signingOut: true, preserveIntent: false) }
        draftsRevision += 1
        fixture?.bookmarks = [:]
        toast("Signed out")
        Task { await loadCommunities() }
    }
    private func invalidateBrowseViewer(pauseSearch: Bool = false, needsSignIn: Bool = false) {
        service.invalidateViewerCaches()
        resolvedCategories = [:]; resolvingCategories = []; categoryRequests = [:]; categoryResolutionErrors = [:]
        catalogRequest = nil; communities = []; communitiesLoaded = false; communityError = nil; catalogRevision += 1
        for tab in tabs.values {
            if pauseSearch { tab.discussionSearch.pauseForAccessChange(viewer: searchViewer, scope: tab.browseScope, needsSignIn: needsSignIn) }
            else { tab.discussionSearch.invalidateViewer() }
            tab.feeds = [:]; tab.discussions = [:]
        }
    }
    func invalidateSearchAccess(in origin: AppTab) {
        guard let search = tabs[origin]?.discussionSearch, search.consumeAccessInvalidation() else { return }
        let needsSignIn = search.failure?.needsSignIn == true
        service.invalidateViewerCaches()
        resolvedCategories = [:]; resolvingCategories = []; categoryRequests = [:]; categoryResolutionErrors = [:]
        catalogRequest = nil; communities = []; communitiesLoaded = false
        communityError = "Community access changed. Reload communities to check current access."
        catalogRevision += 1
        for (tab, state) in tabs {
            state.feeds = [:]; state.discussions = [:]
            if tab != origin { state.discussionSearch.pauseForAccessChange(viewer: searchViewer, scope: state.browseScope, needsSignIn: needsSignIn) }
        }
        for other in windows?.states ?? [] where other !== self {
            other.invalidateBrowseViewer(pauseSearch: true, needsSignIn: needsSignIn)
            other.communityError = "Community access changed. Reload communities to check current access."
        }
        // Keep the original visible recovery action, rebased to the new permission revision.
        // The view's schedule task then sees the same input rather than automatically retrying.
        search.rebaseAccessFailure(viewer: searchViewer)
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
        for tab in tabs.values { tab.feeds = [:]; tab.discussions = [:]; tab.discussionSearch.invalidateViewer() }
        toast(blocked ? "Member blocked" : "Member unblocked")
    }
    func published(topic: TopicID, number: PostNumber, origin: AppTab, isReply: Bool, categoryID: CategoryID?) {
        composer = nil; selectedTab = origin
        // Publication is an explicit destination, even if the list's scope changed while writing.
        if let selected = tabs[origin]?.browseScope.categoryID,
           categoryID != selected && !browseCatalog.contains(where: { $0.id == categoryID && $0.parentID == selected }) {
            selectScope(.all, in: origin)
        }
        tabs[origin]?.discussions = [:]; tabs[origin]?.feeds = [:]
        let route = Route.discussion(topic, number)
        // Replace the discussion the reply was written from, so Back does not return to a stale copy.
        if isReply, case let .discussion(current, _)? = tabs[origin]?.path.last, current == topic { tabs[origin]?.path.removeLast() }
        navigate(route, in: origin, focus: isReply ? .published : nil); draftsRevision += 1
        toast(isReply ? "Reply posted" : "Discussion posted in \(categoryID.flatMap { category($0)?.name } ?? "the community")")
    }
    func discussionState(_ route: Route, in origin: AppTab? = nil) -> DiscussionState {
        let tab = tabs[origin ?? selectedTab]!
        if let state = tab.discussions[route] { return state }
        let state = DiscussionState(route: route, service: service)
        state.focus = tab.focus[route]
        tab.discussions[route] = state; return state
    }
    func forgetIntent(_ intent: NotificationIntent) { taps.forget(intent) }
    func handleLink(_ url: URL) {
        if auth?.receiveCallback(url) == true { return }
        guard let configuration, let route = LinkRouter.route(url, baseURL: configuration.baseURL) else { banner = "This link is not a supported community destination."; return }
        // A public link names an explicit target whose category is not yet known. Display it
        // in All rather than hiding it behind the previous list's unrelated category filter.
        switch route {
        case .discussion, .thread: selectScope(.all)
        default: break
        }
        navigate(route)
    }
}
