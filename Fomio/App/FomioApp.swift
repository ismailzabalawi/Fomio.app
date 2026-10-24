import SwiftUI

@main struct FomioApp: App {
    @State private var windows: AppWindows
    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // `--unconfigured` ignores bundled live settings so the missing-configuration screen stays testable.
        let configuration = arguments.contains("--unconfigured") ? nil : LiveConfiguration.fromBundle()
        #else
        let configuration = LiveConfiguration.fromBundle()
        #endif
        #if DEBUG
        // UI tests start from the default appearance unless they are checking relaunch persistence.
        if arguments.contains("--ui-testing") && !arguments.contains("--keep-preferences") { UserDefaults.standard.removeObject(forKey: FeedAppearance.storageKey) }
        let fixtureMode = arguments.contains("--rich-editor-prototype") || arguments.contains("--store-preview") || arguments.contains("--fixture") || (!arguments.contains("--live") && configuration == nil)
        #else
        let fixtureMode = false
        #endif
        if fixtureMode {
            let fixture = FixtureService()
            var fixtureConfiguration: LiveConfiguration?
            #if DEBUG
            if DevelopmentPresets.requested == "public-link" {
                // Reserved host: exercise app-level link routing with fictional data.
                // The repository remains FixtureService; no live request is made.
                fixtureConfiguration = LiveConfiguration(baseURL: URL(string: "https://fixture.fomio.invalid/forum")!, callbackURL: URL(string: "fomio://auth")!, scopes: "read")
            }
            if let index = arguments.firstIndex(of: "--post-outcome"), arguments.indices.contains(index + 1), let scenario = FixtureService.Scenario(rawValue: arguments[index + 1]) { fixture.scenario = scenario }
            fixture.uploadFails = arguments.contains("--upload-fails")
            fixture.failNextPage = arguments.contains("--feed-more-fails")
            fixture.failNextCommunityLoad = arguments.contains("--community-load-fails")
            if arguments.contains("--card-cases") { fixture.addCardCases() }
            if arguments.contains("--adaptive-search-cases") { fixture.prepareAdaptiveSearchPreview() }
            if arguments.contains("--search-initial-fails") { fixture.searchFailurePages.insert(1) }
            if arguments.contains("--search-more-fails") { fixture.searchFailurePages.insert(2) }
            if arguments.contains("--search-refresh-fails") { fixture.searchRefreshFailure = true }
            if arguments.contains("--search-more-denied") { fixture.searchDeniedPages.insert(2) }
            if arguments.contains("--store-preview") { fixture.prepareStorePreview() }
            if DevelopmentPresets.requested == "loading" { fixture.feedDelay = .seconds(120) }
            if DevelopmentPresets.requested == "partial-community" { fixture.omittedCommunityIDs.insert(.init(9)) }
            #endif
            var store = DraftStore()
            #if DEBUG
            if arguments.contains("--ui-testing"), let raw = ProcessInfo.processInfo.environment["FOMIO_UI_TEST_NAMESPACE"], let namespace = UUID(uuidString: raw) {
                store = DraftStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UITests/" + namespace.uuidString))
            }
            #endif
            _windows = State(initialValue: AppWindows(service: fixture, fixture: fixture, configuration: fixtureConfiguration, store: store))
        } else {
            _windows = State(initialValue: AppWindows(service: DiscourseService(configuration: configuration), fixture: nil, configuration: configuration))
        }
    }
    var body: some Scene {
        WindowGroup("Fomio", id: "browse") {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--rich-editor-prototype") {
                SwiftUIRichComposerPrototype().tint(.fomioAccent).modifier(DevelopmentDisplaySettings())
            } else {
                FomioWindow(windows: windows)
            }
            #else
            FomioWindow(windows: windows)
            #endif
        }
    }
}
/// State is installed once in each WindowGroup scene, rather than once in the App.
private struct FomioWindow: View {
    let windows: AppWindows
    @State private var state: AppState?
    @State private var pendingLinks: [URL] = []
    @State private var sceneSessionID: String?
    var body: some View {
        Group {
            if let state {
                AppShell(app: state).tint(.fomioAccent).modifier(DevelopmentDisplaySettings())
            } else {
                ProgressView().accessibilityLabel("Opening window")
            }
        }.onOpenURL { url in
            if let state { state.handleLink(url) } else { pendingLinks.append(url) }
        }.task {
            if state == nil { state = windows.makeWindow() }
            for url in pendingLinks { state?.handleLink(url) }
            pendingLinks.removeAll()
        }
        .background(PresentingWindowReader { window in
            if let identifier = window?.windowScene?.session.persistentIdentifier { sceneSessionID = identifier }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { notification in
            guard let scene = notification.object as? UIScene, scene.session.persistentIdentifier == sceneSessionID else { return }
            state?.closeWindow()
        }
    }
}
struct AppShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var app: AppState
    var body: some View {
        let _ = app.siteTheme
        Group {
            if app.isConfigured {
                TabView(selection: $app.selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        Tab(LocalizedStringKey(tab.title), systemImage: tab.symbol, value: tab) { TabRoot(app: app, tab: tab, state: app.tabs[tab]!) }
                            .badge(tab == .notifications ? app.unreadCount : 0)
                    }
                }.tabViewStyle(.tabBarOnly)
                .modifier(ToastHost(message: app.composer == nil ? app.toastMessage : nil))
                .sheet(item: $app.composer) { composer in
                    ComposerView(state: composer)
                        .presentationSizing(ComposerPresentationSizing(isRegularWidth: horizontalSizeClass == .regular))
                        .environment(app).modifier(DevelopmentDisplaySettings()).presentationDetents([.large]).presentationCompactAdaptation(.sheet).statusBarHidden(false)
                }
                .sheet(isPresented: $app.authRequested, onDismiss: { app.cancelAuthenticationIntent() }) { SignInView(app: app) }
                .task {
                    await app.restoreAccount(); await app.refreshSafety(); await app.loadTheme(); do { try app.reconcileDraftFiles() } catch { app.banner = error.localizedDescription }; await app.loadCommunities(); await app.refreshUnread()
                    #if DEBUG
                    if let preset = DevelopmentPresets.requested { await DevelopmentPresets.apply(preset, to: app) }
                    #endif
                }
            } else {
                ScreenMessage(title: "Community configuration needed", message: "The live site URL and per-user authorization configuration have not been supplied. Development builds can run the fixture milestone.", symbol: "network")
            }
        }
        .environment(app)
        .tint(Color.fomioAccent)
        .foregroundStyle(Color.fomioText)
        .background(Color.fomioBackground)
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await app.refreshSafety() } } }
        .alert("Fomio", isPresented: Binding(get: { app.banner != nil }, set: { if !$0 { app.banner = nil } })) { Button("OK") { app.banner = nil } } message: { Text(app.banner ?? "") }
    }
}
/// Keep the editor's structural identity as the presenting window changes size.
/// Choosing between two ComposerView branches would reset local caret and editor state.
struct ComposerPresentationSizing: PresentationSizing {
    var isRegularWidth: Bool
    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        if isRegularWidth { return FormPresentationSizing.form.proposedSize(for: root, context: context) }
        return PagePresentationSizing.page.proposedSize(for: root, context: context)
    }
}
struct TabRoot: View {
    @Environment(\.locale) private var locale
    let app: AppState
    let tab: AppTab
    @Bindable var state: TabState
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var focusedReading = false
    /// A discussion opened only because two panes appeared with nothing selected.
    /// It is withdrawn again if the window narrows before the reader chooses anything.
    @State private var autoSelected: Route?
    private var readingIndex: Int? {
        state.path.firstIndex { if case .discussion = $0 { true } else if case .thread = $0 { true } else { false } }
    }
    private var readingRoute: Route? { readingIndex.map { state.path[$0] } }
    private var listPath: Binding<[Route]> {
        Binding(get: { readingIndex.map { Array(state.path[..<$0]) } ?? state.path }, set: { new in
            let suffix = readingIndex.map { Array(state.path[$0...]) } ?? []
            state.path = new + suffix
        })
    }
    private var detailPath: Binding<[Route]> {
        Binding(get: { readingIndex.map { Array(state.path.dropFirst($0 + 1)) } ?? [] }, set: { new in
            guard let index = readingIndex else { return }
            state.path = Array(state.path.prefix(index + 1)) + new
        })
    }
    var body: some View {
        // A row of its own: the split's columns ignore container insets, so an inset banner floated over content.
        VStack(spacing: 0) {
            if showsFixtureBanner {
                Text("Sample content")
                    .font(.caption.weight(.medium)).foregroundStyle(Color.fomioSecondaryText)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity).padding(.vertical, 2).background(Color.fomioBackground)
                    .accessibilityLabel("Sample community content. This is a preview.")
                    .accessibilityIdentifier("fixture-banner")
            }
            reading
        }
    }
    private var reading: some View {
        GeometryReader { geometry in
            let layout = ReadingLayout(width: geometry.size.width, scale: ReadingLayout.scale(for: textSize))
            let showsSidebar = layout.sidebar && !focusedReading && !app.sidebarHidden
            HStack(spacing: 0) {
                if showsSidebar {
                    CommunitySidebar(scope: state.browseScope) { scope in app.selectScope(scope, in: tab) }
                        .frame(width: ReadingLayout.sidebarWidth)
                }
                NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $compactColumn) {
                    NavigationStack(path: listPath) {
                        root.navigationDestination(for: Route.self) { destination($0) }
                    }
                    .navigationSplitViewColumnWidth(min: layout.listMinimum, ideal: layout.listIdeal, max: layout.listMaximum)
                } detail: {
                    NavigationStack(path: detailPath) {
                        detail
                            .navigationDestination(for: Route.self) { destination($0) }
                            .navigationBarBackButtonHidden(!layout.twoPanes && readingRoute != nil && detailPath.wrappedValue.isEmpty)
                            .toolbar {
                                if !layout.twoPanes && readingRoute != nil && detailPath.wrappedValue.isEmpty {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button { compactColumn = .sidebar } label: { Label("Back to topic list", systemImage: "chevron.backward") }
                                            .accessibilityIdentifier("back-to-topic-list")
                                    }
                                } else if layout.twoPanes {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button {
                                            focusedReading.toggle(); visibility = focusedReading ? .detailOnly : .all
                                        } label: { Label(LocalizedStringKey(focusedReading ? "Show topic list" : "Focus on discussion"), systemImage: "sidebar.leading") }
                                        .accessibilityIdentifier("toggle-topic-list")
                                    }
                                }
                            }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                // Duo can offer sufficient physical width with compact traits. Only the reading
                // split receives this presentation hint; the app's composer keeps real window traits.
                .environment(\.horizontalSizeClass, layout.twoPanes ? .regular : .compact)
                .environment(\.readingSidebarVisible, showsSidebar)
                .environment(\.readingShowSidebar, layout.sidebar && app.sidebarHidden && !focusedReading ? { app.sidebarHidden = false } : nil)
            }
            .toolbar(showsSidebar ? .hidden : .visible, for: .tabBar)
            .onChange(of: readingRoute, initial: true) { _, route in
                compactColumn = route == nil ? .sidebar : .detail
                if route != autoSelected { autoSelected = nil }
            }
            .onChange(of: AutoSelectKey(twoPanes: layout.twoPanes, path: state.path, first: firstFeedTopic), initial: true) { _, key in
                guard key.twoPanes, key.path.isEmpty, let topic = key.first else { return }
                let route = Route.discussion(topic, nil)
                autoSelected = route; state.path = [route]
            }
            .onChange(of: state.readingSelectionRevision) { _, _ in compactColumn = .detail }
            .onChange(of: state.discussionSearch.failure) { _, failure in
                if failure != nil { app.invalidateSearchAccess(in: tab) }
            }
            .onChange(of: layout.twoPanes) { _, two in
                visibility = two && focusedReading ? .detailOnly : .all
                // Folding returns to the list, not to a discussion the reader never chose.
                if !two, let auto = autoSelected, state.path == [auto] { state.path = []; autoSelected = nil }
            }
            // A containing element keeps this identifier from replacing the sidebar header controls' own.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(focusedReading && layout.twoPanes ? "reading-focused" : showsSidebar ? "reading-three-pane" : layout.twoPanes ? "reading-two-pane" : "reading-one-pane")
        }
    }
    private struct AutoSelectKey: Equatable { var twoPanes: Bool; var path: [Route]; var first: TopicID? }
    /// The Home feed's first readable topic, while it is the list on screen and no search is open.
    private var firstFeedTopic: TopicID? {
        guard tab == .home, !state.discussionSearch.active else { return nil }
        return state.feed(key: state.browseScope.feedKey).items.first { !app.isBlocked($0.author) }?.id
    }
    @ViewBuilder private var root: some View {
        switch tab {
        case .home: scopedFeed
        case .communities: CommunitiesView(state: state)
        case .notifications: NotificationsView()
        case .me: MeView()
        }
    }
    private var scopedFeed: some View {
        FeedView(state: state.feed(key: state.browseScope.feedKey), category: state.browseScope.categoryID.flatMap(app.category), originTab: tab)
    }
    @ViewBuilder private var detail: some View {
        if let route = readingRoute {
            let reading = app.discussionState(route, in: tab)
            if (tab == .home || tab == .communities), let selected = state.browseScope.categoryID,
               let category = reading.page?.summary.categoryID,
               category != selected && !app.browseCatalog.contains(where: { $0.id == category && $0.parentID == selected }) {
                ScreenMessage(title: BrowseLocalization.string("Discussion outside this community", locale: locale), message: BrowseLocalization.string("Choose All communities to return to this discussion. Its reading position and your draft are kept.", locale: locale), symbol: "rectangle.split.2x1", actionTitle: BrowseLocalization.string("All communities", locale: locale)) { app.selectScope(.all, in: tab) }
            } else { DiscussionView(state: reading).id(route) }
        } else {
            ContentUnavailableView {
                Label("Choose a discussion", systemImage: "text.bubble")
            } description: {
                Text("Select a topic to read it alongside the list.").font(.body).fixedSize(horizontal: false, vertical: true)
            }.background(Color.fomioBackground)
        }
    }
    private var showsFixtureBanner: Bool {
        #if DEBUG
        return app.fixture != nil && !ProcessInfo.processInfo.arguments.contains("--store-preview")
        #else
        return app.fixture != nil
        #endif
    }
    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case let .community(id):
            if let category = app.category(id) {
                if category.restricted { AccessDeniedView(name: category.name) }
                else { FeedView(state: state.feed(key: BrowseScope.category(id).feedKey), category: category, originTab: tab) }
            } else { ScreenMessage(title: "Community unavailable", message: "This community could not be resolved or is inaccessible.", action: { Task { await app.loadCommunities() } }) }
        case .discussion, .thread: DiscussionView(state: app.discussionState(route, in: tab))
        case .search: scopedFeed
        case let .profile(name): ProfileView(username: name)
        case .saved: SavedView()
        case .drafts: DraftsView()
        case .credits: PhotoCreditsView()
        case .diagnostics: DiagnosticsView()
        case let .denied(id): AccessDeniedView(name: app.category(id)?.name ?? "This community")
        case .unavailable: UnavailableTargetView()
        }
    }
}
/// No metadata about a restricted community is shown beyond its name.
struct AccessDeniedView: View {
    @Environment(AppState.self) private var app
    let name: String
    var body: some View {
        ScreenMessage(title: "You don't have access", message: "\(name) is only open to some members.", symbol: "lock", actionTitle: "Back to Communities") {
            app.tabs[app.selectedTab]?.path.removeLast()
        }.background(Color.fomioBackground).navigationTitle(name).navigationBarTitleDisplayMode(.inline)
    }
}
struct UnavailableTargetView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        ScreenMessage(title: "This post isn't available", message: "It may have been deleted, or moved somewhere you can't see.", symbol: "bubble.left.and.exclamationmark.bubble.right", actionTitle: "Back to \(app.selectedTab.title)") {
            app.tabs[app.selectedTab]?.path.removeLast()
        }.background(Color.fomioBackground).navigationTitle("Unavailable").navigationBarTitleDisplayMode(.inline)
    }
}
/// Submitted-for-review notice on the screen the post was written from.
struct PendingNoticeSlot: View {
    @Environment(AppState.self) private var app
    var body: some View {
        if let notice = app.pendingNotice, notice.tab == app.selectedTab, notice.depth == app.tabs[app.selectedTab]?.path.count {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock").foregroundStyle(Color.fomioAccent).padding(.top, 2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) { Text("Submitted for review").font(.subheadline.weight(.semibold)); Text(notice.message).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                Spacer(minLength: 0)
                Button { app.pendingNotice = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss")
            }.padding(.leading, 16).padding(.vertical, 6).background(Color.fomioSelected, in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .contain).padding(.horizontal, 20).padding(.top, 8)
        }
    }
}
struct SignInView: View {
    @Bindable var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var contentHeight: CGFloat = 380
    /// The window this sheet is shown in. The web authorization session is anchored here rather
    /// than to a globally looked-up key window, so it follows this scene as it resizes.
    @State private var window: UIWindow?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.primary).frame(height: 34).accessibilityLabel("Fomio").padding(.top, 28)
                Text(app.gate.title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(app.gate.message).multilineTextAlignment(.center).foregroundStyle(Color.fomioSecondaryText)
                Button {
                    busy = true; Task { await app.signIn(anchor: window); busy = false }
                } label: { Text("Sign in").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).disabled(busy).accessibilityIdentifier("signin-continue")
                if app.fixture != nil { Text("Fixture preview signs in as the fictional member jonah.w.").font(.caption).foregroundStyle(.secondary) }
                Button { dismiss() } label: { Text("Not now").frame(maxWidth: .infinity, minHeight: 44) }
                if busy { ProgressView() }
            }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }.scrollBounceBehavior(.basedOnSize)
        .background(PresentingWindowReader { window = $0 })
        // Fit the sheet to its content; the system caps it at full height for large text sizes.
        .presentationDetents([.height(contentHeight)]).presentationDragIndicator(.visible)
        .onChange(of: app.username) { _, username in if username != nil { dismiss() } }
    }
}
/// Reports the UIKit window hosting a SwiftUI view, from the view itself rather than from
/// application-wide scene state. Zero-sized and hidden from interaction and accessibility.
struct PresentingWindowReader: UIViewRepresentable {
    var onWindowChange: (UIWindow?) -> Void
    func makeUIView(context: Context) -> WindowView { WindowView(onWindowChange: onWindowChange) }
    func updateUIView(_ view: WindowView, context: Context) { view.onWindowChange = onWindowChange }
    final class WindowView: UIView {
        var onWindowChange: (UIWindow?) -> Void
        init(onWindowChange: @escaping (UIWindow?) -> Void) {
            self.onWindowChange = onWindowChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            let window = self.window
            DispatchQueue.main.async { [weak self] in self?.onWindowChange(window) }
        }
    }
}

struct DevelopmentDisplaySettings: ViewModifier {
    @Environment(\.layoutDirection) private var direction
    @Environment(\.locale) private var locale
    func body(content: Content) -> some View {
        #if DEBUG
        Group {
            if ProcessInfo.processInfo.arguments.contains("--accessibility-text") {
                content.environment(\.dynamicTypeSize, .accessibility3)
            } else {
                // Leave native trait changes intact, including accessibility audits.
                content
            }
        }.preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil)
            .environment(\.layoutDirection, ProcessInfo.processInfo.arguments.contains("--rtl") ? .rightToLeft : direction)
            .environment(\.locale, ProcessInfo.processInfo.arguments.contains("--rtl") ? Locale(identifier: "ar") : locale)
        #else
        content
        #endif
    }
}
