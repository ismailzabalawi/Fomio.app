import SwiftUI

@main struct FomioApp: App {
    @State private var state: AppState
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
        let fixtureMode = arguments.contains("--fixture") || (!arguments.contains("--live") && configuration == nil)
        #else
        let fixtureMode = false
        #endif
        let localizationRoot: URL
        #if DEBUG
        // Hosting unit tests: start from bundled English, independent of this simulator's saved language.
        let unitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if unitTestHost {
            localizationRoot = FileManager.default.temporaryDirectory.appendingPathComponent("UnitTestHost-\(UUID().uuidString)")
            UserDefaults.standard.removeObject(forKey: LocalizationController.preferenceKey)
        } else if arguments.contains("--ui-testing"), let raw = ProcessInfo.processInfo.environment["FOMIO_UI_TEST_NAMESPACE"], let namespace = UUID(uuidString: raw) {
            localizationRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UITests/" + namespace.uuidString + "/Localization")
        } else { localizationRoot = LocalizationStore.defaultRoot() }
        Self.applyLanguageArguments(arguments, root: localizationRoot)
        #else
        localizationRoot = LocalizationStore.defaultRoot()
        #endif
        if fixtureMode {
            let fixture = FixtureService()
            #if DEBUG
            if let index = arguments.firstIndex(of: "--post-outcome"), arguments.indices.contains(index + 1), let scenario = FixtureService.Scenario(rawValue: arguments[index + 1]) { fixture.scenario = scenario }
            fixture.uploadFails = arguments.contains("--upload-fails")
            fixture.failNextPage = arguments.contains("--feed-more-fails")
            if arguments.contains("--card-cases") { fixture.addCardCases() }
            fixture.failFirstFeed = arguments.contains("--feed-fails-once")
            if arguments.contains("--media-recovery"), let photo = Bundle.main.url(forResource: "fixture-photo", withExtension: "jpg") { fixture.enableMediaRecovery(photo: photo) }
            if DevelopmentPresets.requested == "loading" { fixture.feedDelay = .seconds(120) }
            #endif
            var store = DraftStore()
            #if DEBUG
            if arguments.contains("--ui-testing"), let raw = ProcessInfo.processInfo.environment["FOMIO_UI_TEST_NAMESPACE"], let namespace = UUID(uuidString: raw) {
                store = DraftStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UITests/" + namespace.uuidString))
            }
            #endif
            var options = FixtureLocalizationTransport.Options()
            #if DEBUG
            options.offline = arguments.contains("--l10n-offline")
            options.changedOverride = arguments.contains("--l10n-changed-override")
            options.incompleteArabic = arguments.contains("--l10n-incomplete-ar")
            #endif
            #if DEBUG
            let transport: any LocalizationTransport = unitTestHost ? UnavailableLocalizationTransport() : FixtureLocalizationTransport(options: options)
            #else
            let transport: any LocalizationTransport = FixtureLocalizationTransport(options: options)
            #endif
            let localization = LocalizationController(store: LocalizationStore(root: localizationRoot, site: "fixture"), transport: transport)
            _state = State(initialValue: AppState(service: fixture, fixture: fixture, configuration: nil, store: store, localization: localization))
        } else {
            // A catalog transport exists only once the site publishes the contract and its paths are configured.
            let transport: any LocalizationTransport = configuration.flatMap { DiscourseLocalizationTransport.fromBundle($0) } ?? UnavailableLocalizationTransport()
            let site = configuration.map { LocalizationStore.siteKey($0.baseURL) } ?? "unconfigured"
            let localization = LocalizationController(store: LocalizationStore(root: localizationRoot, site: site), transport: transport)
            _state = State(initialValue: AppState(service: DiscourseService(configuration: configuration), fixture: nil, configuration: configuration, localization: localization))
        }
    }
    #if DEBUG
    /// `--language <code|system>` sets the stored interface preference; `--l10n-reset` clears cached catalogs.
    private static func applyLanguageArguments(_ arguments: [String], root: URL) {
        if arguments.contains("--l10n-reset") { try? FileManager.default.removeItem(at: root) }
        if arguments.contains("--ui-testing") && !arguments.contains("--keep-preferences") { UserDefaults.standard.removeObject(forKey: LocalizationController.preferenceKey) }
        guard let index = arguments.firstIndex(of: "--language"), arguments.indices.contains(index + 1) else { return }
        let value = arguments[index + 1]
        if value == "system" { UserDefaults.standard.removeObject(forKey: LocalizationController.preferenceKey) }
        else if LocaleMatcher.isValidCode(value) { UserDefaults.standard.set(value, forKey: LocalizationController.preferenceKey) }
    }
    #endif
    var body: some Scene {
        WindowGroup { AppShell(app: state).tint(.fomioAccent).modifier(DevelopmentDisplaySettings()).modifier(LocalizationEnvironment()).onOpenURL { state.handleLink($0) } }
    }
}
struct AppShell: View {
    @Bindable var app: AppState
    @Environment(\.scenePhase) private var phase
    var body: some View {
        let _ = app.siteTheme
        Group {
            if app.isConfigured {
                TabView(selection: $app.selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        Tab(tab.title, systemImage: tab.symbol, value: tab) { TabRoot(app: app, tab: tab, state: app.tabs[tab]!) }
                            .badge(tab == .notifications ? app.unreadCount : 0)
                    }
                }.tabViewStyle(.sidebarAdaptable)
                // UIKit bar views keep the direction they were created with (seen on the iPad top tab bar).
                // A direction change rebuilds the container; paths, tab selection, feeds and searches live in AppState.
                .id(Localizer.shared.layoutDirection)
                .modifier(ToastHost(message: app.composer == nil ? app.toastMessage : nil))
                .sheet(item: $app.composer) { composer in
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .pad { ComposerView(state: composer).presentationSizing(.form) }
                        else { ComposerView(state: composer).presentationSizing(.page) }
                    }.environment(app).modifier(DevelopmentDisplaySettings()).modifier(LocalizationEnvironment()).presentationDetents([.large]).presentationCompactAdaptation(.sheet).statusBarHidden(false)
                }
                .sheet(isPresented: $app.authRequested, onDismiss: { app.pendingAction = nil; app.gate = .signIn }) { SignInView(app: app).modifier(DevelopmentDisplaySettings()).modifier(LocalizationEnvironment()) }
                .task {
                    await app.restoreAccount(); await app.loadTheme(); do { try app.draftStore.reconcileFiles(account: app.account) } catch { app.banner = error.localizedDescription }; await app.loadCommunities(); await app.refreshUnread()
                    #if DEBUG
                    if let preset = DevelopmentPresets.requested { await DevelopmentPresets.apply(preset, to: app) }
                    #endif
                }
            } else {
                ScreenMessage(title: L("config.needed.title"), message: L("config.needed.message"), symbol: "network")
            }
        }
        // Launch and foreground: revalidate the interface catalog in the background; rendering never waits.
        .task { await app.localization.refresh() }
        .onChange(of: phase) { _, value in if value == .active { Task { await app.localization.refresh() } } }
        .environment(app)
        .tint(Color.fomioAccent)
        .foregroundStyle(Color.fomioText)
        .background(Color.fomioBackground)
        .alert(L("app.name"), isPresented: Binding(get: { app.banner != nil }, set: { if !$0 { app.banner = nil } })) { Button(L("common.ok")) { app.banner = nil } } message: { Text(app.banner ?? "") }
    }
}
struct TabRoot: View {
    let app: AppState
    let tab: AppTab
    @Bindable var state: TabState
    var body: some View {
        NavigationStack(path: $state.path) {
            Group {
                switch tab {
                case .home: FeedView(state: state.feed(key: "home"), category: nil)
                case .communities: CommunitiesView(state: state)
                case .notifications: NotificationsView()
                case .me: MeView()
                }
            }
            .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if app.fixture != nil { Text(DevText("FIXTURE PREVIEW · fictional community content")).font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 3).background(.regularMaterial, in: .capsule).padding(.bottom, 4).dynamicTypeSize(...DynamicTypeSize.large).allowsHitTesting(false).accessibilityIdentifier("fixture-banner") }
        }
    }
    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case let .community(id):
            if let category = app.category(id) {
                if category.restricted { AccessDeniedView(name: category.name) } else { FeedView(state: state.feed(key: "category-\(id.rawValue)"), category: category) }
            }
            else { ScreenMessage(title: L("community.unavailable.title"), message: L("community.unavailable.message"), action: { Task { await app.loadCommunities() } }) }
        case .discussion, .thread: DiscussionView(state: app.discussionState(route))
        case .search: SearchView(state: state)
        case let .profile(name): ProfileView(username: name)
        case .saved: SavedView()
        case .drafts: DraftsView()
        case .credits: PhotoCreditsView()
        case .diagnostics: DiagnosticsView()
        case .language: LanguageSettingsView()
        case let .denied(id): AccessDeniedView(name: app.category(id)?.name)
        case .unavailable: UnavailableTargetView()
        }
    }
}
/// No metadata about a restricted community is shown beyond its name.
struct AccessDeniedView: View {
    @Environment(AppState.self) private var app
    let name: String?
    var body: some View {
        ScreenMessage(title: L("access.denied.title"), message: name.map { L("access.denied.community_message", ["community": $0]) } ?? L("access.denied.unknown_message"), symbol: "lock", actionTitle: L("access.back_to_communities")) {
            app.tabs[app.selectedTab]?.path.removeLast()
        }.background(Color.fomioBackground).navigationTitle(name ?? L("access.denied.unknown_name")).navigationBarTitleDisplayMode(.inline)
    }
}
struct UnavailableTargetView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        ScreenMessage(title: L("post.unavailable.title"), message: L("post.unavailable.message"), symbol: "bubble.left.and.exclamationmark.bubble.right", actionTitle: L("common.back_to", ["place": app.selectedTab.title])) {
            app.tabs[app.selectedTab]?.path.removeLast()
        }.background(Color.fomioBackground).navigationTitle(L("post.unavailable.nav_title")).navigationBarTitleDisplayMode(.inline)
    }
}
/// Submitted-for-review notice on the screen the post was written from.
struct PendingNoticeSlot: View {
    @Environment(AppState.self) private var app
    var body: some View {
        if let notice = app.pendingNotice, notice.tab == app.selectedTab, notice.depth == app.tabs[app.selectedTab]?.path.count {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock").foregroundStyle(Color.fomioAccent).padding(.top, 2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) { Text(L("pending.title")).font(.subheadline.weight(.semibold)); Text(notice.message).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                Spacer(minLength: 0)
                Button { app.pendingNotice = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel(L("common.dismiss"))
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
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.primary).frame(height: 34).accessibilityLabel(L("app.name")).padding(.top, 28)
                Text(app.gate.title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(app.gate.message).multilineTextAlignment(.center).foregroundStyle(Color.fomioSecondaryText)
                Button {
                    busy = true; Task { await app.signIn(); busy = false }
                } label: { Text(L("auth.sign_in")).frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).disabled(busy).accessibilityIdentifier("signin-continue")
                if app.fixture != nil { Text(DevText("Fixture preview signs in as the fictional member jonah.w.")).font(.caption).foregroundStyle(.secondary) }
                Button { dismiss() } label: { Text(L("common.not_now")).frame(maxWidth: .infinity, minHeight: 44) }
                if busy { ProgressView() }
            }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }.scrollBounceBehavior(.basedOnSize)
        // Fit the sheet to its content; the system caps it at full height for large text sizes.
        .presentationDetents([.height(contentHeight)]).presentationDragIndicator(.visible)
        .onChange(of: app.username) { _, username in if username != nil { dismiss() } }
    }
}

struct DevelopmentDisplaySettings: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.layoutDirection) private var direction
    func body(content: Content) -> some View {
        #if DEBUG
        content.preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil)
            .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--accessibility-text") ? .accessibility3 : dynamicType)
            .environment(\.layoutDirection, ProcessInfo.processInfo.arguments.contains("--rtl") ? .rightToLeft : direction)
        #else
        content
        #endif
    }
}
