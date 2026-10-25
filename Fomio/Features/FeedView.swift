import SwiftUI
import Observation

@MainActor @Observable final class FeedState {
    var items: [DiscussionSummary] = []
    var nextPage: Int? = 0
    var loading = false
    var loaded = false
    var error: String?
    var anchor: TopicID?
    var scrollPosition = ScrollPosition(idType: BrowseRowAnchor.self)
    @ObservationIgnored let geometry = FeedGeometry()
    @ObservationIgnored var savedPosition: FeedGeometry.Anchor?
    @ObservationIgnored var needsPositionRestore = false
    @ObservationIgnored var restoreAttempt: UUID?
    func capturePosition() {
        savedPosition = geometry.topAnchor(in: items)
        if let savedPosition { anchor = savedPosition.id }
        restoreAttempt = nil
    }
    @ObservationIgnored private var viewer: SearchViewer?
    @ObservationIgnored private var generation = 0
    func updateViewer(_ value: SearchViewer) {
        guard value != viewer else { return }
        viewer = value; generation += 1
        items = []; nextPage = 0; loading = false; loaded = false; error = nil; anchor = nil
        geometry.frames = [:]; geometry.contentOffset = 0; savedPosition = nil; needsPositionRestore = false; restoreAttempt = nil
        scrollPosition = ScrollPosition(idType: BrowseRowAnchor.self)
    }
    func load(service: any CommunityService, category: Community?, refresh: Bool = false) async {
        guard !loading, refresh || nextPage != nil else { return }
        let generation = self.generation
        loading = true; defer { if generation == self.generation { loading = false } }
        do {
            let page = try await service.feed(category: category, page: refresh ? 0 : nextPage ?? 0)
            try Task.checkCancellation()
            guard generation == self.generation else { return }
            items = refresh ? page.items : items + page.items.filter { item in !items.contains { $0.id == item.id } }
            nextPage = page.nextPage; error = nil; loaded = true
        } catch is CancellationError {} catch {
            guard generation == self.generation else { return }
            if let repositoryError = error as? RepositoryError, [.denied, .unauthorized, .unavailable].contains(repositoryError) {
                items = []; nextPage = nil; loaded = false; anchor = nil
            }
            self.error = error.localizedDescription
        }
    }
}
func repliesText(_ count: Int) -> String { count == 1 ? "1 reply" : "\(count) replies" }

private enum BrowseRowAnchor: Hashable, Sendable { case topic(TopicID), hit(PostID) }
/// Feed commands have one native position owner. An ID binding and a separate proxy
/// otherwise compete when a partially visible row changes height between appearances.
private struct BrowseScrollPosition: ViewModifier {
    let searching: Bool
    @Binding var feed: ScrollPosition
    let search: Binding<BrowseRowAnchor?>
    @ViewBuilder func body(content: Content) -> some View {
        if searching { content.scrollPosition(id: search) }
        else { content.scrollPosition($feed) }
    }
}
private struct SearchScheduleKey: Hashable { var query: String; var scope: BrowseScope; var viewer: SearchViewer }
private struct FeedLoadKey: Hashable { var scope: BrowseScope; var viewer: SearchViewer; var state: ObjectIdentifier }

struct FeedView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.readingSidebarVisible) private var sidebarVisible
    @Environment(\.readingShowSidebar) private var showSidebar
    @Bindable var state: FeedState
    let category: Community?
    let originTab: AppTab
    @State private var showingAbout = false
    @State private var chooserRequest = 0
    @FocusState private var searchFocused: Bool
    @AppStorage(FeedAppearance.storageKey) private var appearance: FeedAppearance = .compact
    private var geometry: FeedGeometry { state.geometry }
    @State private var pendingRestore: FeedGeometry.Anchor?
    @State private var columnWidth: CGFloat = 0
    @State private var headerCornerInsets = RectangleCornerInsets()
    @State private var userScrolling = false
    @ScaledMetric(relativeTo: .body) private var controlSymbolSize = 20.0
    private var roomyToolbar: Bool { columnWidth >= 560 && !textSize.isAccessibilitySize }
    private var needsNativeBack: Bool {
        !browse.path.prefix { route in
            switch route { case .discussion, .thread: false; default: true }
        }.isEmpty
    }
    private var showsDirectCreate: Bool { roomyToolbar && needsNativeBack }
    private var browse: TabState { app.tabs[originTab]! }
    private var search: DiscussionSearchState { browse.discussionSearch }
    private var selectedTopic: TopicID? {
        for route in browse.path.reversed() {
            if case let .discussion(id, _) = route { return id }
            if case let .thread(id, _) = route { return id }
        }
        return nil
    }
    private var viewer: SearchViewer { var value = app.searchViewer; value.locale = locale.identifier; return value }
    private var rowAnchor: Binding<BrowseRowAnchor?> {
        Binding(get: { search.active ? search.anchor.map(BrowseRowAnchor.hit) : state.anchor.map(BrowseRowAnchor.topic) }, set: { value in
            switch value { case let .topic(id): state.anchor = id; case let .hit(id): search.anchor = id; case nil: break }
        })
    }
    var body: some View {
        let _ = app.siteTheme
        Group {
            ScrollView {
                ReadingColumn {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        PendingNoticeSlot()
                        if browse.browseScope.categoryID != nil && category == nil && search.failure == nil {
                            if let id = browse.browseScope.categoryID, app.resolvingCategories.contains(id) {
                                ProgressView().frame(maxWidth: .infinity).padding(24).accessibilityLabel("Loading community")
                            } else {
                                ScreenMessage(title: localized("Community unavailable"), message: localized("This community could not be resolved or is inaccessible."), actionTitle: localized("All communities")) { app.selectScope(.all, in: originTab) }
                            }
                        } else if search.active {
                            searchResults
                        } else {
                            if state.loading && !state.loaded { SkeletonRows() }
                            ForEach(state.items.filter { !app.isBlocked($0.author) }) { topic in
                                TopicCard(topic: topic, appearance: appearance, showCategory: category == nil || topic.categoryID != category?.id,
                                          onOpen: { app.navigate(.discussion(topic.id, topic.targetPostNumber), in: originTab) },
                                          onCategory: { app.navigate(.community($0), in: originTab) })
                                    .background(selectedTopic == topic.id ? Color.fomioSelected : .clear)
                                    .accessibilityAddTraits(selectedTopic == topic.id ? .isSelected : [])
                                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { geometry.frames[topic.id] = $0 }
                                    .id(BrowseRowAnchor.topic(topic.id))
                            }
                            if state.loading && state.loaded { ProgressView().frame(maxWidth: .infinity).padding(24) }
                            if let error = state.error {
                                InfoCard(title: localized(state.loaded ? "Couldn’t load more" : "Discussions unavailable"), message: error) {
                                    Button("Retry") { Task { await load() } }.frame(minHeight: 44)
                                }.padding(20)
                            } else if state.loaded && state.items.isEmpty {
                                if let category {
                                    ScreenMessage(title: BrowseLocalization.format("No discussions in %@ yet", locale: locale, category.name), message: localized("Choose another community, or All communities."), symbol: "tray", actionTitle: localized("Choose a community")) { chooserRequest += 1 }
                                        .padding(.vertical, 24).accessibilityIdentifier("empty-scope")
                                } else {
                                    InfoCard(title: localized("No discussions yet"), message: localized("Start a discussion in a community you can post to.")).padding(20)
                                }
                            }
                            if state.nextPage != nil && state.loaded && !state.loading && state.error == nil {
                                Button("More discussions") { Task { await load() } }.frame(maxWidth: .infinity, minHeight: 44).padding()
                            }
                        }
                    }.padding(.bottom, 20).scrollTargetLayout()
                }
            }
            .scrollBounceBehavior(.always)
            .scrollDismissesKeyboard(.interactively)
            .modifier(BrowseScrollPosition(searching: search.active, feed: $state.scrollPosition, search: rowAnchor))
            .id(ObjectIdentifier(state))
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { geometry.originY = $0 }
            .accessibilityIdentifier(search.active ? "scoped-search-results" : "feed-\(appearance.rawValue)")
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { old, offset in
                geometry.contentOffset = offset
                guard userScrolling else { return }
                if offset < -36 && !search.revealed { state.capturePosition(); search.revealed = true }
                // Adding the field changes the safe-area inset. Only an upward user scroll
                // already inside the content may hide it; layout/bounce cleanup cannot.
                if old > 0 && offset > 64 && offset > old && search.revealed && !searchFocused && !search.active { search.revealed = false }
            }
            .onScrollPhaseChange { _, phase in userScrolling = phase == .interacting }
            .onScrollGeometryChange(for: FeedGeometry.Viewport.self) {
                .init(top: 0, height: $0.containerSize.height)
            } action: { geometry.viewport = .init(top: geometry.originY, height: $1.height) }
            .onChange(of: appearance) { restore() }
            .onChange(of: search.active) { _, active in
                if !active {
                    if let anchor = state.savedPosition { restore(anchor: anchor) }
                    else if let id = state.anchor { state.scrollPosition.scrollTo(id: BrowseRowAnchor.topic(id), anchor: .top) }
                }
            }
            .onDisappear {
                if !search.active { state.capturePosition(); state.needsPositionRestore = true }
            }
            .task(id: ObjectIdentifier(state)) {
                if state.needsPositionRestore, let anchor = state.savedPosition {
                    state.needsPositionRestore = false
                    await Task.yield()
                    restore(anchor: anchor)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                browseHeader
                if search.revealed || search.active { searchField }
            }
        }
        .background(Color.fomioBackground)
        .toolbar(removing: .sidebarToggle)
        .toolbar(needsNativeBack ? .visible : .hidden, for: .navigationBar)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if showsDirectCreate {
                    Button { app.create(category: category?.id) } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel(category.map { BrowseLocalization.format("New discussion in %@", locale: locale, $0.name) } ?? localized("New discussion"))
                        .disabled(browse.browseScope.categoryID != nil && category == nil)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { columnWidth = $0 }
        .sheet(isPresented: $showingAbout) { if let category { CommunityAboutView(category: category) } }
        .task(id: FeedLoadKey(scope: browse.browseScope, viewer: viewer, state: ObjectIdentifier(state))) {
            state.updateViewer(viewer)
            if let id = browse.browseScope.categoryID, category == nil, search.failure == nil { await app.resolveCategory(id) }
            if !state.loaded { await load() }
        }
        .task(id: SearchScheduleKey(query: search.query, scope: browse.browseScope, viewer: viewer)) {
            search.schedule(service: app.service, viewer: viewer, scope: browse.browseScope, catalog: app.browseCatalog)
        }
        .onChange(of: search.failure?.attemptID) { _, attempt in
            if attempt != nil, app.selectedTab == originTab, scenePhase == .active, let failure = search.failure {
                UIAccessibility.post(notification: .announcement, argument: failureMessage(failure))
            }
        }
        .onChange(of: app.safetyRevision) { _, _ in Task { await state.load(service: app.service, category: category, refresh: true) } }
        .onKeyPress(.escape) { cancelSearch(); return .handled }
    }
    private var browseHeader: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        let searchShown = search.revealed || search.active
        let hidesSearch = searchShown && search.query.isEmpty
        return VStack(alignment: .leading, spacing: 4) {
            // Home shows the wordmark above its title unless the sidebar already carries it.
            // A hidden sidebar is restored from this top-leading corner, as in the reviewed layout.
            let showsLogo = originTab == .home && !sidebarVisible && !needsNativeBack
            if showsLogo || showSidebar != nil {
                HStack(spacing: 12) {
                    if let showSidebar {
                        Button(action: showSidebar) {
                            Image(systemName: "sidebar.squares.leading").font(.system(size: min(controlSymbolSize, 28)))
                                .frame(width: 44, height: 44).contentShape(.circle).glassEffect(.regular.interactive(), in: .circle)
                        }.buttonStyle(.plain).accessibilityLabel("Show sidebar").accessibilityIdentifier("show-sidebar")
                    }
                    if showsLogo { FomioWordmark() }
                }.frame(minHeight: 44, alignment: .leading)
            }
            layout {
                // Keep this one chooser mounted while the header changes layout. Native
                // toolbar title slots can silently clip or drop long/large scope labels.
                CommunityScopePicker(scope: browse.browseScope, request: chooserRequest) { app.selectScope($0, in: originTab) }
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    if textSize.isAccessibilitySize { Spacer(minLength: 0) }
                    // Reveals and focuses search; with search open and empty it hides it again.
                    Button { toggleSearch(hiding: hidesSearch) } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: min(controlSymbolSize, 28)))
                            .foregroundStyle(searchShown ? Color.fomioAccent : Color.fomioText).frame(width: 44, height: 44)
                            .contentShape(.circle)
                            .glassEffect(searchShown ? .regular.tint(Color.fomioAccent.opacity(0.14)).interactive() : .regular.interactive(), in: .circle)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(LocalizedStringKey(hidesSearch ? "Hide search" : "Search discussions"))
                        .accessibilityIdentifier("reveal-topic-search")
                    optionsMenu.labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 16).padding(.vertical, 6)
            // Padding participates in multiline measurement and hit testing.
            // A visual corner offset can reflow this header without reserving
            // the resulting extra text height in the safe-area inset.
            .padding(.leading, headerCornerInsets.topLeading.width)
            .padding(.trailing, headerCornerInsets.topTrailing.width)
            .background(Color.fomioBackground)
            .onGeometryChange(for: RectangleCornerInsets.self) { $0.containerCornerInsets } action: { headerCornerInsets = $0 }
            .accessibilityElement(children: .contain).accessibilityIdentifier("browse-header")
    }
    private var searchField: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: min(controlSymbolSize, 28)))
                    .foregroundStyle(Color.fomioSecondaryText).accessibilityHidden(true)
                // A vertical field sizes with Dynamic Type and lets a long query wrap at large text; the
                // single-line field's UIKit backing fails the text-clipping audit. Return still means Search.
                TextField(category.map { BrowseLocalization.format("Search in %@", locale: locale, $0.name) } ?? localized("Search discussions"), text: Binding(get: { search.query }, set: { value in
                    if value.contains("\n") { search.query = value.replacingOccurrences(of: "\n", with: ""); Task { @MainActor in searchFocused = false } }
                    else { search.query = value }
                }), axis: .vertical)
                    .lineLimit(1...3).font(.body).frame(minHeight: 44)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).focused($searchFocused)
                    .accessibilityIdentifier("topic-search-field")
                    .onSubmit { searchFocused = false }
                if !search.query.isEmpty {
                    Button { search.query = ""; searchFocused = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: min(controlSymbolSize, 28))).frame(minWidth: 44, minHeight: 44)
                    }
                        .accessibilityLabel("Clear search")
                }
            }.padding(.leading, 12).frame(minHeight: 44).background(Color.fomioFill, in: .rect(cornerRadius: 14))
            Button { cancelSearch() } label: { Text("Cancel").frame(minHeight: 48).contentShape(.rect) }.accessibilityIdentifier("cancel-topic-search")
        }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.fomioBackground)
    }
    @ViewBuilder private var searchResults: some View {
        if let failure = search.failure, !isPagingFailure { searchFailure(failure) }
        if search.showingPreviousResults { Text("Showing previous results").font(.caption).foregroundStyle(Color.fomioSecondaryText).padding(.horizontal, 20) }
        if search.showsNoResults {
            ScreenMessage(title: category.map { BrowseLocalization.format("No topics in %@ match “%@”", locale: locale, $0.name, search.trimmedQuery) } ?? BrowseLocalization.format("No topics match “%@”", locale: locale, search.trimmedQuery),
                          message: localized(category == nil ? "Try another word." : "Try another word, or search all communities."),
                          symbol: "magnifyingglass", actionTitle: localized("Clear search")) { search.query = ""; searchFocused = true }
                .padding(.vertical, 24)
                .accessibilityElement(children: .contain).accessibilityIdentifier("search-no-results")
        }
        ForEach(search.hits.filter { !app.isBlocked($0.discussion.matchAuthor ?? $0.discussion.author) }) { hit in
            SearchResultRow(result: hit.discussion, query: search.trimmedQuery)
                .background(selectedTopic == hit.discussion.id ? Color.fomioSelected : .clear)
                .accessibilityAddTraits(selectedTopic == hit.discussion.id ? .isSelected : [])
                .id(BrowseRowAnchor.hit(hit.id))
        }
        if search.loading { ProgressView().frame(maxWidth: .infinity).padding(24).accessibilityLabel("Searching") }
        if let failure = search.failure, isPagingFailure { searchFailure(failure) }
        if search.nextPage != nil && !search.loading && search.failure == nil {
            Button { search.more(service: app.service, viewer: viewer, scope: browse.browseScope, catalog: app.browseCatalog) } label: {
                Text("More results").frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
            }
        }
        if search.reachedPageLimit { Text("Refine your search to see more results.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText).padding(20) }
    }
    private var isPagingFailure: Bool { if case .more = search.failure?.operation { true } else { false } }
    private func searchFailure(_ failure: DiscussionSearchState.Failure) -> some View {
        InfoCard(title: localized(isPagingFailure ? "More results couldn’t be loaded" : "Search unavailable"), message: failureMessage(failure)) {
            if failure.needsSignIn { Button { app.requestSignIn() } label: { Text("Sign in").frame(minHeight: 44).contentShape(.rect) } }
            else if failure.retryable {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        if let until = failure.retryAfter, until > context.date {
                            Text(BrowseLocalization.retryCountdown(until: until, now: context.date, locale: locale)).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                        }
                        Button { search.retry(service: app.service, viewer: viewer, scope: browse.browseScope, catalog: app.browseCatalog) } label: {
                            Text("Retry").frame(minHeight: 44).contentShape(.rect)
                        }.disabled(search.loading || failure.retryAfter.map { $0 > context.date } == true).accessibilityIdentifier("retry-topic-search")
                    }
                }
            }
        }.padding(20).accessibilityElement(children: .contain)
            .accessibilityIdentifier(isPagingFailure ? "search-page-error" : "search-error")
    }
    private func localized(_ key: String) -> String { BrowseLocalization.string(key, locale: locale) }
    private func failureMessage(_ failure: DiscussionSearchState.Failure) -> String {
        failure.kind?.localizedMessage(locale: locale) ?? localized(failure.message)
    }
    private func cancelSearch() { searchFocused = false; search.cancel() }
    private func toggleSearch(hiding: Bool) {
        if hiding { cancelSearch(); return }
        if !search.revealed && !search.active { state.capturePosition() }
        search.revealed = true; searchFocused = true
    }
    private func load() async {
        guard browse.browseScope.categoryID == nil || category?.id == browse.browseScope.categoryID else { return }
        await state.load(service: app.service, category: category)
    }
    private var optionsMenu: some View {
        Menu {
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button { openWindow(id: "browse") } label: { Label("New window", systemImage: "macwindow.badge.plus") }
                    .accessibilityIdentifier("new-browsing-window")
            }
            if !showsDirectCreate {
                Button { app.create(category: category?.id) } label: { Label("New discussion", systemImage: "square.and.pencil") }
                    .disabled(browse.browseScope.categoryID != nil && category == nil)
            }
            if category != nil { Button { showingAbout = true } label: { Label("About", systemImage: "info.circle") }.accessibilityIdentifier("community-about") }
            Button {
                if search.active { search.refresh(service: app.service, viewer: viewer, scope: browse.browseScope, catalog: app.browseCatalog) }
                else if let id = browse.browseScope.categoryID, category == nil { Task { await app.resolveCategory(id, retry: true) } }
                else { Task { await state.load(service: app.service, category: category, refresh: true) } }
            } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Section("Feed appearance") {
                Picker(selection: Binding(get: { appearance }, set: select)) {
                    ForEach(FeedAppearance.allCases) { option in Label(option.title, systemImage: option.symbol).tag(option) }
                } label: { Text("Feed appearance") }.pickerStyle(.inline)
            }
        } label: { Label(localized(category == nil ? "Home options" : "Feed options"), systemImage: "ellipsis")
                .font(.system(size: min(controlSymbolSize, 28))).frame(width: 44, height: 44).contentShape(.circle).glassEffect(.regular.interactive(), in: .circle) }
        .accessibilityIdentifier("feed-options")
    }
    private func select(_ value: FeedAppearance) {
        guard value != appearance else { return }
        pendingRestore = geometry.topAnchor(in: state.items)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { appearance = value }
    }
    private func restore(anchor requested: FeedGeometry.Anchor? = nil) {
        guard !search.active, let anchor = requested ?? pendingRestore ?? geometry.topAnchor(in: state.items) else { return }
        pendingRestore = nil
        let scope = browse.browseScope, viewer = viewer, attempt = UUID()
        state.restoreAttempt = attempt
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { state.scrollPosition.scrollTo(id: BrowseRowAnchor.topic(anchor.id), anchor: .top) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, !search.active, browse.browseScope == scope,
                  self.viewer == viewer, browse.feeds[scope.feedKey] === state, state.restoreAttempt == attempt else { return }
            let offset = geometry.restoredOffset(for: anchor)
            if let offset { withTransaction(transaction) { state.scrollPosition.scrollTo(y: offset) } }
        }
    }
}
/// Non-observed layout readings used only when the appearance changes; updating them never re-renders the feed.
@MainActor final class FeedGeometry {
    struct Viewport: Equatable { var top: CGFloat = 0; var height: CGFloat = 0 }
    struct Anchor: Equatable { var id: TopicID; var offset: CGFloat; var height: CGFloat }
    var frames: [TopicID: CGRect] = [:]
    var viewport = Viewport()
    var originY: CGFloat = 0 { didSet { viewport.top += originY - oldValue } }
    /// The first topic whose bottom is below the visible top, with its offset from that top.
    func topAnchor(in items: [DiscussionSummary]) -> Anchor? {
        let current = Set(items.map(\.id))
        frames = frames.filter { current.contains($0.key) }
        let visible = frames.filter { $0.value.maxY > viewport.top + 1 && $0.value.minY < viewport.top + viewport.height }
        guard let (id, frame) = visible.min(by: { $0.value.minY < $1.value.minY }) else { return nil }
        return Anchor(id: id, offset: frame.minY - viewport.top, height: max(frame.height, 1))
    }
    /// Correct the measured native content offset after reflow. Pixel positioning also handles
    /// tall neighboring cards whose required UnitPoint would fall outside the supported 0...1 range.
    var contentOffset: CGFloat = 0
    func restoredOffset(for anchor: Anchor) -> CGFloat? {
        guard let frame = frames[anchor.id], viewport.height > 0 else { return nil }
        let target = anchor.offset < 0 ? anchor.offset * frame.height / anchor.height : min(anchor.offset, viewport.height * 0.6)
        return max(0, contentOffset + frame.minY - viewport.top - target)
    }
}
struct CompactIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View { HStack(spacing: 3) { configuration.icon.imageScale(.small); configuration.title } }
}
struct CommunitiesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var state: TabState
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var descriptionSize: CGFloat = 14
    private struct DirectoryGroup: Identifiable { var root: Community; var kids: [Community]; var visible: [Community]; var id: CategoryID { root.id } }
    var body: some View {
        let _ = app.siteTheme
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PendingNoticeSlot()
                    ScaledTitle("Communities", size: 26).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 14)
                    if let error = app.communityError, app.communities.isEmpty { ScreenMessage(title: "Communities unavailable", message: error, action: { Task { await app.loadCommunities() } }) }
                    else if app.communities.isEmpty && app.communitiesLoaded { InfoCard(title: "No communities available", message: "There are no communities visible to this account.").padding(20) }
                    else if app.communities.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(40).accessibilityLabel("Loading communities") }
                    else {
                        if let error = app.communityError {
                            InfoCard(title: "Couldn’t refresh communities", message: error) { Button("Try again") { Task { await app.loadCommunities() } }.frame(minHeight: 44) }.padding(20)
                        }
                        let groups = self.groups
                        if !query.isEmpty && !groups.isEmpty {
                            Text("\(groups.count) \(groups.count == 1 ? "community matches" : "communities match") “\(query)”. This filters the list below only.")
                                .font(.footnote).foregroundStyle(Color.fomioSecondaryText).padding(.horizontal, 20).padding(.top, 8).accessibilityAddTraits(.updatesFrequently)
                        }
                        if !query.isEmpty && groups.isEmpty {
                            InfoCard(title: "No communities match “\(query)”", message: "This box only filters the communities listed here.") {
                                Button("Search discussions for “\(query)”") { app.search(query) }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                            }.padding(20)
                        }
                        ForEach(groups) { group in
                            groupView(group)

                        }
                    }
                }.padding(.bottom, 20)
            }
        }.scrollDismissesKeyboard(.interactively).background(Color.fomioBackground).navigationTitle("Communities").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $state.communityQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find communities")
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { searchFocused = false }
        .onDisappear { searchFocused = false }
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search discussions")
                Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New discussion")
            }
        }
        .refreshable { await app.loadCommunities() }
    }
    private var query: String { state.communityQuery.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func hit(_ category: Community) -> Bool { category.name.localizedCaseInsensitiveContains(query) || category.description.localizedCaseInsensitiveContains(query) }
    /// Filters names and descriptions already loaded; matching subcommunities show under their parent.
    private var groups: [DirectoryGroup] {
        app.communities.filter { $0.parentID == nil }.compactMap { root in
            let kids = app.communities.filter { $0.parentID == root.id }
            let selfHit = query.isEmpty || hit(root), kidHits = query.isEmpty ? kids : kids.filter(hit)
            if !query.isEmpty && !selfHit && kidHits.isEmpty { return nil }
            let pool = !query.isEmpty && !selfHit ? kidHits : kids
            let open = state.expandedCommunities.contains(root.id) || !query.isEmpty
            let visible = open ? pool : []
            return DirectoryGroup(root: root, kids: pool, visible: visible)
        }
    }
    private func groupView(_ group: DirectoryGroup) -> some View {
        let root = group.root
        let color = Color.hexValue(root.identity.color).map(Color.init(hex:)) ?? .fomioAccent
        let expanded = !group.visible.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Button { app.navigate(root.restricted ? .denied(root.id) : .community(root.id)) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CategoryMark(category: root)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(root.name).font(.headline).foregroundStyle(Color.fomioText).multilineTextAlignment(.leading)
                            if root.restricted { restrictedBadge }
                            else if !root.description.isEmpty {
                                Text(root.descriptionExcerpt ?? root.description).font(.system(size: descriptionSize)).foregroundStyle(Color.fomioSecondaryText)
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel("\(root.name)\(root.restricted ? ", restricted" : ""). \(root.description)").accessibilityIdentifier("community-\(root.id.rawValue)")
                if !group.kids.isEmpty && query.isEmpty {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            if state.expandedCommunities.contains(root.id) { state.expandedCommunities.remove(root.id) }
                            else { state.expandedCommunities.insert(root.id) }
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold))
                            .foregroundStyle(Color.fomioText).frame(width: 44, height: 44).background(color.opacity(0.16), in: .rect(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityLabel("\(expanded ? "Hide" : "Show") subcommunities of \(root.name)").accessibilityIdentifier("category-expand-\(root.id.rawValue)")
                }
            }
            if expanded {
                VStack(spacing: 0) {
                    ForEach(group.visible) { child in
                        Button { app.navigate(child.restricted ? .denied(child.id) : .community(child.id)) } label: {
                            HStack(spacing: 10) {
                                CategoryMark(category: child, size: 28)
                                Text(child.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioText).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
                            }.frame(minHeight: 44).padding(.vertical, 3).contentShape(.rect)
                        }.buttonStyle(.plain).accessibilityLabel("\(child.name), subcommunity of \(root.name)").accessibilityIdentifier("community-\(child.id.rawValue)")
                    }
                }.padding(.leading, typeSize.isAccessibilitySize ? 0 : 24).padding(.top, 8)
                .overlay(alignment: .leading) { if !typeSize.isAccessibilitySize { Capsule().fill(color.opacity(0.2)).frame(width: 2).padding(.leading, 20).padding(.vertical, 14).accessibilityHidden(true) } }
            }
        }.padding(14).background(expanded ? color.opacity(0.055) : Color.clear, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 20).padding(.bottom, 8)
    }
    private var restrictedBadge: some View { Label("Restricted", systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText).labelStyle(CompactIconLabel()) }
}

struct CommunityAboutView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let category: Community
    var body: some View {
        let _ = app.siteTheme
        NavigationStack {
            ScrollView {
                ReadingColumn {
                    VStack(alignment: .leading, spacing: 16) {
                        CategoryHeading(category: category)
                        Text(category.description.isEmpty ? "No community description is available." : category.description).textSelection(.enabled)
                        if let value = category.aboutURL, let base = app.configuration?.baseURL,
                           let url = LinkRouter.communityIntroductionURL(value, baseURL: base) {
                            Link("Read the community introduction", destination: url).frame(minHeight: 44)
                        }
                    }.padding(20)
                }
            }.background(Color.fomioBackground).navigationTitle("About").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
