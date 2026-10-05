import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable { case home, communities, notifications, me; var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { switch self { case .home: "house"; case .communities: "square.grid.2x2"; case .notifications: "bell"; case .me: "person.crop.circle" } }
}
enum Route: Hashable { case community(CategoryID), discussion(TopicID, PostNumber?), thread(TopicID, PostNumber), search, profile(String), saved, drafts, credits, diagnostics, denied(CategoryID), unavailable }
/// Why a discussion opened at a specific post. Shown as a text label on that post.
enum FocusReason: Hashable {
    case notification, search, saved, published
    var label: String { switch self { case .notification: "From your notification"; case .search: "Search match"; case .saved: "Saved reply"; case .published: "Your reply" } }
}
/// The member action that asked for sign-in; it names the action and is restored afterwards, never auto-applied.
enum AuthGate: Equatable {
    case signIn, reply, quote, like, save, create(String?)
    var title: String {
        switch self { case .signIn: "Sign in"; case .reply: "Sign in to reply"; case .quote: "Sign in to quote"; case .like: "Sign in to like posts"; case .save: "Sign in to save discussions"; case .create: "Sign in to start a discussion" }
    }
    var message: String {
        switch self {
        case .reply, .quote: "You’ll come back to this discussion with your reply open. Nothing is posted until you tap Post."
        case let .create(name): name.map { "You’ll come back with a new discussion in \($0) open. Nothing is posted until you tap Post." } ?? "You’ll come back and choose a community. Nothing is posted until you tap Post."
        case .like, .save: "You’ll come back to this post. Nothing is applied until you tap it again."
        case .signIn: "Reply to discussions, save them for later and get notified when someone replies to you."
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
    var expandedCommunities: Set<CategoryID> = []
    var searchQuery = ""
    var searchResults: [DiscussionSummary] = []
    var searchNextPage: Int?
    var searchCompletedQuery: String?
    var searchAnchor: TopicID?
    var feeds: [String: FeedState] = [:]
    var discussions: [Route: DiscussionState] = [:]
    var focus: [Route: FocusReason] = [:]
    func feed(key: String) -> FeedState { if let value = feeds[key] { return value }; let value = FeedState(); feeds[key] = value; return value }
}
@MainActor @Observable final class AppState {
    static let fixtureMember = "jonah.w"
    var selectedTab: AppTab = .home
    var tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) })
    var communities: [Community] = []
    var communityError: String?
    var account: AccountID = .guest
    var username: String?
    var displayName: String?
    var composer: ComposerState?
    var authRequested = false
    var gate: AuthGate = .signIn
    var pendingAction: (@MainActor () async -> Void)?
    var banner: String?
    var toastMessage: String?
    var pendingNotice: PendingNotice?
    var guestNoteDismissed = false
    var unreadCount = 0
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
        if fixture != nil, !ProcessInfo.processInfo.arguments.contains("--guest") { account = .fixture; username = Self.fixtureMember; displayName = "Jonah Wells" }
        do { try draftStore.reconcileFiles(account: account) } catch { banner = error.localizedDescription }
    }
    var isOffline: Bool { fixture?.offline == true || (fixture == nil && connectivity.offline) }
    func loadCommunities() async {
        do { communities = try await service.communities(); communityError = nil } catch { communityError = error.localizedDescription }
    }
    func refreshUnread() async {
        guard username != nil else { unreadCount = 0; return }
        if let page = try? await service.notifications(page: 0) { unreadCount = page.items.filter { !$0.read }.count }
    }
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
            if fixture != nil { username = Self.fixtureMember; displayName = "Jonah Wells"; account = .fixture }
            else if let auth { let member = try await auth.signIn(); username = member; account = .init(rawValue: "\(configuration!.baseURL.absoluteString):\(member)") }
            else { throw RepositoryError.configuration }
            if let composer, composer.draft.account != account { self.composer = nil; banner = "The previous account’s draft remains private to that account." }
            try draftStore.migrateGuest(to: account)
            if composer == nil { try draftStore.reconcileFiles(account: account) }
            let action = pendingAction, gate = self.gate; pendingAction = nil
            authRequested = false; await loadCommunities(); await action?()
            let name = username ?? "member"
            switch gate {
            case .reply, .quote: toast("Signed in as \(name). Your reply is ready.")
            case .like: toast("Signed in as \(name). Tap again to like the post.")
            case .save: toast("Signed in as \(name). Tap again to save.")
            default: toast("Signed in as \(name).")
            }
            self.gate = .signIn
            await refreshUnread()
        } catch { banner = error.localizedDescription }
    }
    func restoreAccount() async {
        guard fixture == nil, let auth, let configuration else { return }
        do {
            if try KeychainCredentialStore.read(site: configuration.baseURL.absoluteString) != nil {
                let name = try await auth.currentUsername(); username = name; account = .init(rawValue: "\(configuration.baseURL.absoluteString):\(name)")
            }
            if composer == nil { try draftStore.reconcileFiles(account: account) }
        } catch { banner = error.localizedDescription }
    }
    func signOut() {
        composer?.stopUploads()
        do { try draftStore.clear(account: account); try auth?.signOut() }
        catch { banner = "Sign-out could not finish: \(error.localizedDescription)"; return }
        account = .guest; username = nil; displayName = nil; pendingAction = nil; composer = nil; pendingNotice = nil; unreadCount = 0; guestNoteDismissed = false
        tabs = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, TabState()) }); draftsRevision += 1
        fixture?.bookmarks = [:]; fixture?.readNotices = []
        toast("Signed out")
        Task { await loadCommunities() }
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
    func handleLink(_ url: URL) {
        if auth?.receiveCallback(url) == true { return }
        guard let configuration, let route = LinkRouter.route(url, baseURL: configuration.baseURL) else { banner = "This link is not a supported community destination."; return }
        navigate(route)
    }
}
