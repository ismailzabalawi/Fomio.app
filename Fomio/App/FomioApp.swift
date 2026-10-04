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
        let fixtureMode = arguments.contains("--fixture") || (!arguments.contains("--live") && configuration == nil)
        #else
        let fixtureMode = false
        #endif
        if fixtureMode {
            let fixture = FixtureService()
            #if DEBUG
            if let index = arguments.firstIndex(of: "--post-outcome"), arguments.indices.contains(index + 1), let scenario = FixtureService.Scenario(rawValue: arguments[index + 1]) { fixture.scenario = scenario }
            fixture.uploadFails = arguments.contains("--upload-fails")
            if DevelopmentPresets.requested == "loading" { fixture.feedDelay = .seconds(120) }
            #endif
            var store = DraftStore()
            #if DEBUG
            if arguments.contains("--ui-testing"), let raw = ProcessInfo.processInfo.environment["FOMIO_UI_TEST_NAMESPACE"], let namespace = UUID(uuidString: raw) {
                store = DraftStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UITests/" + namespace.uuidString))
            }
            #endif
            _state = State(initialValue: AppState(service: fixture, fixture: fixture, configuration: nil, store: store))
        } else {
            _state = State(initialValue: AppState(service: DiscourseService(configuration: configuration), fixture: nil, configuration: configuration))
        }
    }
    var body: some Scene {
        WindowGroup { AppShell(app: state).tint(.fomioAccent).modifier(DevelopmentDisplaySettings()).onOpenURL { state.handleLink($0) } }
    }
}
struct AppShell: View {
    @Bindable var app: AppState
    var body: some View {
        Group {
            if app.isConfigured {
                TabView(selection: $app.selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        Tab(tab.title, systemImage: tab.symbol, value: tab) { TabRoot(app: app, tab: tab, state: app.tabs[tab]!) }
                            .badge(tab == .notifications ? app.unreadCount : 0)
                    }
                }.tabViewStyle(.sidebarAdaptable)
                .modifier(ToastHost(message: app.composer == nil ? app.toastMessage : nil))
                .sheet(item: $app.composer) { composer in ComposerView(state: composer).environment(app).presentationDetents([.large]).presentationSizing(.form) }
                .sheet(isPresented: $app.authRequested, onDismiss: { app.pendingAction = nil; app.gate = .signIn }) { SignInView(app: app).presentationDetents([.medium, .large]) }
                .sheet(isPresented: $app.choosingDestination) { DestinationChooser(selected: nil) { app.openComposer(category: $0) }.environment(app) }
                .task {
                    await app.restoreAccount(); await app.loadCommunities(); await app.refreshUnread()
                    #if DEBUG
                    if let preset = DevelopmentPresets.requested { await DevelopmentPresets.apply(preset, to: app) }
                    #endif
                }
            } else {
                ScreenMessage(title: "Community configuration needed", message: "The live site URL and per-user authorization configuration have not been supplied. Development builds can run the fixture milestone.", symbol: "network")
            }
        }
        .environment(app)
        .background(Color.fomioBackground)
        .alert("Fomio", isPresented: Binding(get: { app.banner != nil }, set: { if !$0 { app.banner = nil } })) { Button("OK") { app.banner = nil } } message: { Text(app.banner ?? "") }
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
            if app.fixture != nil { Text("FIXTURE PREVIEW · fictional community content").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 3).background(.regularMaterial, in: .capsule).padding(.bottom, 4).dynamicTypeSize(...DynamicTypeSize.large).allowsHitTesting(false).accessibilityIdentifier("fixture-banner") }
        }
    }
    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case let .community(id):
            if let category = app.category(id) {
                if category.restricted { AccessDeniedView(name: category.name) } else { FeedView(state: state.feed(key: "category-\(id.rawValue)"), category: category) }
            }
            else { ScreenMessage(title: "Community unavailable", message: "This community could not be resolved or is inaccessible.", action: { Task { await app.loadCommunities() } }) }
        case .discussion, .thread: DiscussionView(state: app.discussionState(route))
        case .search: SearchView(state: state)
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
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.primary).frame(height: 34).accessibilityLabel("Fomio").padding(.top, 28)
                Text(app.gate.title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(app.gate.message).multilineTextAlignment(.center).foregroundStyle(Color.fomioSecondaryText)
                Button {
                    busy = true; Task { await app.signIn(); busy = false }
                } label: { Text("Sign in").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).disabled(busy).accessibilityIdentifier("signin-continue")
                if app.fixture != nil { Text("Fixture preview signs in as the fictional member jonah.w.").font(.caption).foregroundStyle(.secondary) }
                Button { dismiss() } label: { Text("Not now").frame(maxWidth: .infinity, minHeight: 44) }
                if busy { ProgressView() }
            }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }.onChange(of: app.username) { _, username in if username != nil { dismiss() } }
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
