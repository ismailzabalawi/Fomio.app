import SwiftUI
import SafariServices

/// Notifications inbox: server history with an All/Unread read filter, truthful continuation and recovery.
struct NotificationsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let store = app.notifications
        Group {
            if app.username == nil {
                ScrollView {
                    InfoCard(title: "Sign in to see notifications", message: "Replies, quotes and mentions from the community show up here after you sign in.") {
                        Button("Sign in") { app.requestSignIn() }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44)
                    }.padding(20)
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        Picker("Show", selection: Binding(get: { store.filter }, set: { value in Task { await store.select(value) } })) {
                            Text("All").tag(NotificationFilter.all); Text("Unread").tag(NotificationFilter.unread)
                        }.pickerStyle(.segmented).controlSize(.large).frame(minHeight: 44).listRowSeparator(.hidden).accessibilityIdentifier("notification-filter")
                        if let note = statusNote { StatusNote(note: note).listRowSeparator(.hidden) }
                        content(store)
                    }
                    .listStyle(.plain)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                    .refreshable { await store.refresh() }
                    .onAppear { if let anchor = store.anchor { proxy.scrollTo(anchor, anchor: .center) } }
                }
            }
        }
        .background(Color.fomioBackground).navigationTitle("Notifications")
        .toolbar {
            RootToolbar(app: app)
            if app.username != nil {
                ToolbarItem(placement: .topBarTrailing) { Button { app.navigate(.notificationSettings, in: .notifications) } label: { Image(systemName: "gearshape") }.accessibilityLabel("Notification settings").accessibilityIdentifier("notification-settings") }
            }
        }
        .task(id: app.account) { guard app.username != nil else { return }; await store.loadIfNeeded(); await store.refreshTotals() }
    }
    private var statusNote: StatusNote.Note? {
        let store = app.notifications
        if app.isOffline, store.feed.loaded { return .init(symbol: "wifi.slash", text: "You’re offline. Showing notifications from \(updated).", action: nil) }
        if let error = store.refreshError, store.feed.loaded { return .init(symbol: "exclamationmark.circle", text: "Couldn’t refresh. Showing notifications from \(updated).", detail: error, action: { Task { await store.refresh() } }, isError: true) }
        if let note = store.syncNote { return .init(symbol: "arrow.triangle.2.circlepath", text: note, action: nil) }
        return nil
    }
    private var updated: String { app.notifications.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "earlier" }
    @ViewBuilder private func content(_ store: NotificationStore) -> some View {
        let all = store.rows()
        let visible = all.filter { !hidden($0) }
        let hiddenCount = all.count - visible.count
        let feed = store.feed
        if !feed.loaded && feed.loading {
            ForEach(0..<4, id: \.self) { _ in NotificationSkeleton() }.accessibilityElement(children: .ignore).accessibilityLabel("Loading notifications")
        } else if !feed.loaded, let error = feed.pageError {
            ScreenMessage(title: "Couldn’t load notifications", message: error, action: { Task { await store.loadMore(hiding: hidden) } }).listRowSeparator(.hidden)
        } else if feed.loaded && visible.isEmpty && feed.nextOffset == nil {
            emptyState(store).listRowSeparator(.hidden)
        } else {
            ForEach(visible) { item in
                NotificationRow(item: item, acknowledgment: store.acknowledgments[item.id]) { store.anchor = item.id; app.open(notification: item) }
                    .id(item.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16))
            }
            if hiddenCount > 0 { Text(hiddenCount == 1 ? "1 notification from a member you blocked is hidden." : "\(hiddenCount) notifications from members you blocked are hidden.").font(.footnote).foregroundStyle(Color.fomioSecondaryText).listRowSeparator(.hidden) }
            footer(store, visible: visible)
        }
    }
    @ViewBuilder private func footer(_ store: NotificationStore, visible: [NotificationItem]) -> some View {
        let feed = store.feed
        Group {
            if feed.loading {
                HStack(spacing: 8) { ProgressView(); Text("Loading older notifications").foregroundStyle(Color.fomioSecondaryText) }.frame(maxWidth: .infinity, minHeight: 44)
            } else if let error = feed.pageError {
                VStack(spacing: 6) {
                    Text("Couldn’t load older notifications.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                    Text(error).font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                    Button("Try again") { Task { await store.loadMore(hiding: hidden) } }.frame(minHeight: 44)
                }.frame(maxWidth: .infinity)
            } else if feed.nextOffset != nil {
                if feed.lastPageEmpty || (store.filter == .unread && visible.isEmpty) {
                    VStack(spacing: 6) {
                        Text(store.filter == .unread ? "Nothing unread in this batch. Older notifications may still be unread." : "Nothing to show in this batch. Older notifications may still be available.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText).multilineTextAlignment(.center)
                        Button("Keep looking") { Task { await store.loadMore(hiding: hidden) } }.frame(minHeight: 44).accessibilityIdentifier("notification-keep-looking")
                    }.frame(maxWidth: .infinity)
                } else {
                    Button("Show older") { Task { await store.loadMore(hiding: hidden) } }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("notification-show-older")
                        .onAppear { if store.filter == .all { Task { await store.loadMore(hiding: hidden) } } }
                }
            } else {
                Text("That’s everything").font(.subheadline).foregroundStyle(Color.fomioSecondaryText).frame(maxWidth: .infinity, minHeight: 44)
            }
        }.listRowSeparator(.hidden).padding(.bottom, 8)
    }
    @ViewBuilder private func emptyState(_ store: NotificationStore) -> some View {
        if store.filter == .unread {
            InfoCard(title: "No unread notifications", message: "You’ve seen everything. Earlier notifications are still in All.") {
                Button("Show all") { Task { await store.select(.all) } }.frame(minHeight: 44)
            }.padding(.vertical, 12)
        } else {
            InfoCard(title: "No notifications yet", message: "When someone replies to you, quotes you or mentions you, it shows up here.") { EmptyView() }.padding(.vertical, 12)
        }
    }
    private func hidden(_ item: NotificationItem) -> Bool { item.filterNames.contains { app.isBlocked($0) } }
}

struct StatusNote: View {
    struct Note { var symbol: String; var text: String; var detail: String? = nil; var action: (() -> Void)?; var isError = false }
    let note: Note
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: note.symbol).foregroundStyle(note.isError ? Color.fomioDanger : Color.fomioSecondaryText).accessibilityHidden(true)
            Text(note.text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            if let action = note.action { Button("Try again", action: action).font(.subheadline.weight(.semibold)).frame(minHeight: 44) }
        }.padding(.horizontal, 12).padding(.vertical, 4).background(Color.fomioFill, in: .rect(cornerRadius: 12)).accessibilityElement(children: .combine)
    }
}

struct NotificationSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color.fomioFill).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 8) { Capsule().fill(Color.fomioFill).frame(height: 12).frame(maxWidth: 220); Capsule().fill(Color.fomioFill).frame(height: 12).frame(maxWidth: 160) }
        }.padding(.vertical, 12).redacted(reason: .placeholder)
    }
}

/// One inbox row. Unread uses a dot, weight and the word “Unread”, never colour alone. Retry is outside the row button.
struct NotificationRow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: NotificationItem
    let acknowledgment: AcknowledgmentState?
    let open: () -> Void
    var body: some View {
        let copy = NotificationCopy(item)
        let destination = NotificationResolver.destination(item, site: app.notificationSite, username: app.username)
        let community = item.categoryID.flatMap(app.category)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.fomioAccent).frame(width: 8, height: 8).padding(.top, 15).opacity(item.read ? 0 : 1).accessibilityHidden(true)
                    lead
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(Text(copy.lead).fontWeight(item.read ? .semibold : .bold))\(Text(copy.action).foregroundStyle(item.read ? Color.fomioSecondaryText : Color.fomioText))")
                            .font(.subheadline)
                        if let title = item.topicTitle, !title.isEmpty {
                            Text(title).font(.body.weight(item.read ? .regular : .semibold)).foregroundStyle(Color.fomioText).lineLimit(typeSize.isAccessibilitySize ? 3 : 2).multilineTextAlignment(.leading)
                        }
                        meta(community: community, destination: destination)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 10).frame(minHeight: 44).contentShape(.rect)
            }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility(copy: copy, community: community, destination: destination))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("notification-\(item.id.rawValue)")
            if let acknowledgment { AcknowledgmentLine(id: item.id, state: acknowledgment).padding(.leading, 54).padding(.bottom, 8) }
        }
    }
    @ViewBuilder private var lead: some View {
        let size: CGFloat = typeSize.isAccessibilitySize ? 46 : 36
        if item.isGroupedReplies || item.actor == nil || item.isUnknownKind {
            Image(systemName: item.isGroupedReplies ? "bubble.left.and.bubble.right" : "info.circle").font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isGroupedReplies ? Color.fomioAccent : Color.fomioSecondaryText)
                .frame(width: size, height: size).background(item.isGroupedReplies ? Color.fomioHighlight : Color.fomioFill, in: .circle).accessibilityHidden(true)
        } else { Avatar(name: item.actor ?? "", size: size) }
    }
    private func meta(community: Community?, destination: NotificationDestination) -> some View {
        FlowLayout(spacing: 6) {
            if let community { HStack(spacing: 4) { CategoryMark(category: community, size: 16); Text(community.name).lineLimit(1) } }
            if case .website = destination { Label("Opens on the website", systemImage: "arrow.up.right.square") }
            if case .unsupported = destination { Label("Not available in the app", systemImage: "nosign") }
            if !item.age.isEmpty { Text(item.age) }
            if !item.read { Text("Unread").fontWeight(.semibold).foregroundStyle(Color.fomioAccent) }
        }.font(.footnote).foregroundStyle(Color.fomioSecondaryText)
    }
    private func accessibility(copy: NotificationCopy, community: Community?, destination: NotificationDestination) -> String {
        var parts = [item.read ? nil : "Unread", copy.full, item.topicTitle, community.map { "In \($0.name)" }]
        if case .website = destination { parts.append("Opens on the website") }
        if case .unsupported = destination { parts.append("Not available in the app") }
        parts.append(item.age.isEmpty ? nil : item.age)
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

/// Exact-ID acknowledgment outcome, with an explicit retry or server recheck.
struct AcknowledgmentLine: View {
    @Environment(AppState.self) private var app
    let id: NotificationID
    let state: AcknowledgmentState
    /// Distinguishes the inbox row from the destination copy that is on screen above it.
    var context = "row"
    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .pending: ProgressView().controlSize(.small); Text("Marking as read…")
            case .checking: ProgressView().controlSize(.small); Text("Checking with the community…")
            case .failed:
                Image(systemName: "exclamationmark.circle").foregroundStyle(Color.fomioDanger).accessibilityHidden(true)
                Text("Not marked as read. It stays unread.")
                Button("Try again") { Task { await app.notifications.acknowledge(id) } }.fontWeight(.semibold).frame(minHeight: 44).accessibilityIdentifier("ack-retry-\(context)-\(id.rawValue)")
            case .unknown:
                Image(systemName: "questionmark.circle").accessibilityHidden(true)
                Text("Couldn’t confirm it was marked read.")
                Button("Check again") { Task { await app.notifications.recheck(id) } }.fontWeight(.semibold).frame(minHeight: 44).accessibilityIdentifier("ack-check-\(context)-\(id.rawValue)")
            }
        }.font(.footnote).foregroundStyle(Color.fomioSecondaryText).accessibilityElement(children: .contain)
    }
}
/// Status shown on a destination opened from a notification.
struct NotificationAcknowledgmentStatus: View {
    @Environment(AppState.self) private var app
    let id: NotificationID
    var body: some View {
        if let state = app.notifications.acknowledgments[id] { AcknowledgmentLine(id: id, state: state, context: "target").padding(10).background(Color.fomioFill, in: .rect(cornerRadius: 12)) }
    }
}

/// Unsupported types: a verified same-site website handoff when one exists, otherwise an honest dead end.
/// Neither path marks the notification read.
struct NotificationInfoView: View {
    @Environment(AppState.self) private var app
    let id: NotificationID
    var body: some View {
        let item = app.notifications.item(id)
        let destination = item.map { NotificationResolver.destination($0, site: app.notificationSite, username: app.username) } ?? .unsupported
        ScrollView {
            ReadingColumn {
                if case let .website(url) = destination {
                    InfoCard(title: "Open this on the website", message: "This kind of notification isn’t supported in the app yet. You can view it on the community’s website. It stays unread here until it’s read on the website.", symbol: "safari") {
                        Button("Open website") { app.webDestination = url }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44).accessibilityIdentifier("notification-open-website")
                        Text(url.host ?? "").font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                    }.padding(20)
                } else {
                    InfoCard(title: "Fomio can’t show this notification", message: "There’s no link for this kind of activity yet. It stays in your inbox.", symbol: "info.circle") { EmptyView() }.padding(20)
                }
            }
        }.background(Color.fomioBackground).navigationTitle(item.map { NotificationCopy($0).full } ?? "Notification").navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationMismatchView: View {
    @Environment(AppState.self) private var app
    let intended: String
    var body: some View {
        ScreenMessage(title: "This notification is for another account", message: "It was sent to @\(intended). You’re signed in as @\(app.username ?? "another member"), so Fomio won’t open it here.", symbol: "person.crop.circle.badge.exclamationmark", actionTitle: "Go to Notifications") {
            app.tabs[.notifications]?.path = []
        }.background(Color.fomioBackground).navigationTitle("Notification").navigationBarTitleDisplayMode(.inline)
    }
}

/// Device alert status (OS permission plus enrollment) and the community's website preferences.
struct NotificationSettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let device = app.device, words = device.wording
        let status = Self.describe(device.status, words: words)
        List {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Alerts").font(.body.weight(.semibold))
                    Spacer()
                    Label(status.label, systemImage: status.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(status.isError ? Color.fomioDanger : status.label == "On" ? Color.fomioAccent : Color.fomioSecondaryText)
                }.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }.accessibilityElement(children: .combine).accessibilityIdentifier("alert-status")
                Text(status.detail).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                switch device.status {
                case .off, .detached:
                    Button("Turn on alerts") { device.explaining = true }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44).accessibilityIdentifier("alerts-turn-on")
                case .notAllowed:
                    Button("Open \(words.system) Settings") { openSettings() }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44).accessibilityIdentifier("alerts-open-settings")
                case .failed, .allowed:
                    Button(device.status == .failed ? "Try again" : "Finish setup") { Task { await device.enroll(account: app.account) } }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44).accessibilityIdentifier("alerts-retry")
                case .on:
                    Button("Manage in \(words.system) Settings") { openSettings() }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44)
                case .finishing, .updating:
                    ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                case .unavailable: EmptyView()
                }
            } header: { Text("This \(words.device)") }
            Section {
                Text("Which activity notifies you, email notifications and quiet hours are set on the community’s website. They apply on every device.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                Button { if let url = app.notificationSite.map({ LiveConfiguration(baseURL: $0, callbackURL: $0, scopes: "").url("my/preferences/notifications") }) { app.webDestination = url } } label: { Label("Open preferences on website", systemImage: "arrow.up.right.square") }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44)
            } header: { Text("Community") } footer: {
                Text("Alerts can be delayed, grouped or held by Focus, Do Not Disturb and your community settings. You can still check activity in your inbox when alerts are off.")
            }
        }
        .navigationTitle("Notification settings").navigationBarTitleDisplayMode(.inline)
        .task { await device.refreshPermission() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await device.refreshPermission() } } }
        .sheet(isPresented: Binding(get: { device.explaining }, set: { device.explaining = $0 })) { AlertExplanationSheet() }
        .sheet(isPresented: Binding(get: { device.simulatedSettings }, set: { device.simulatedSettings = $0 })) { SimulatedSystemSettings() }
        .alert(app.device.isSimulated ? "“Fomio” Would Like to Send You Notifications (simulated)" : "", isPresented: Binding(get: { app.device.simulatedPrompt != nil }, set: { if !$0, app.device.simulatedPrompt != nil { app.device.answerSimulatedPrompt(false) } })) {
            Button("Don’t Allow", role: .cancel) { app.device.answerSimulatedPrompt(false) }
            Button("Allow") { app.device.answerSimulatedPrompt(true) }
        } message: { Text("Fixture preview: this stands in for the system prompt. Notifications may include alerts, sounds and icon badges.") }
    }
    private func openSettings() {
        if app.device.isSimulated { app.device.simulatedSettings = true } else if let url = app.device.permissions.settingsURL { openURL(url) }
    }
    struct Description { var label: String; var symbol: String; var detail: String; var isError = false }
    static func describe(_ status: NotificationDevice.Status, words: DeviceWording) -> Description {
        let device = words.device, system = words.system
        switch status {
        case .unavailable: return .init(label: "Not available yet", symbol: "bell.slash", detail: "Alerts on this \(device) aren’t available yet: the community hasn’t connected an alert service for the app. Your inbox still updates whenever you open Fomio.")
        case .detached: return .init(label: "Off", symbol: "bell.slash", detail: "Signed out, so this \(device) no longer receives alerts for that account.")
        case .notAllowed: return .init(label: "Not allowed", symbol: "bell.slash", detail: "Alerts are turned off for Fomio in \(system) Settings. Your inbox still updates whenever you open the app.")
        case .finishing: return .init(label: "Finishing setup", symbol: "hourglass", detail: "\(system) allows alerts. Fomio is still connecting this \(device) to the community, so alerts can’t arrive yet.")
        case .failed: return .init(label: "Setup didn’t finish", symbol: "exclamationmark.circle", detail: "\(system) allows alerts, but this \(device) isn’t connected for alerts yet. Your inbox still works.", isError: true)
        case .updating: return .init(label: "Updating", symbol: "arrow.triangle.2.circlepath", detail: "Refreshing this \(device)’s alert setup. Alerts may pause until it finishes.")
        case .on: return .init(label: "On", symbol: "checkmark.circle", detail: "Alerts can arrive for replies, quotes and mentions. Timing depends on Focus and your community settings.")
        case .allowed: return .init(label: "Allowed", symbol: "bell", detail: "\(system) allows alerts. Setup hasn’t started on this \(device).")
        case .off: return .init(label: "Off", symbol: "bell.slash", detail: "Get alerts on this \(device) when someone replies to you, quotes you or mentions you.")
        }
    }
}

/// Contextual explanation before any system prompt. Not now never prompts.
struct AlertExplanationSheet: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let words = app.device.wording
        VStack(spacing: 16) {
            Image(systemName: "bell.badge").font(.largeTitle).foregroundStyle(Color.fomioAccent).accessibilityHidden(true).padding(.top, 24)
            Text("Get alerts for replies and mentions").font(.title3.bold()).multilineTextAlignment(.center)
            Text("Fomio can alert you on this \(words.device) when someone replies to you, quotes you or mentions you. Alerts follow your community settings and Focus, and can arrive late. You can turn them off any time in \(words.system) Settings.").multilineTextAlignment(.center).foregroundStyle(Color.fomioSecondaryText)
            Button { Task { await app.device.requestPermission(account: app.account) } } label: { Text("Continue").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).accessibilityIdentifier("alerts-continue")
            Button { app.device.explaining = false } label: { Text("Not now").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("alerts-not-now")
        }.padding(24).frame(maxWidth: 480).presentationDetents([.medium, .large])
    }
}
/// Fixture-only stand-in for the system Settings screen.
struct SimulatedSystemSettings: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let words = app.device.wording
        NavigationStack {
            Form {
                Section { Toggle("Allow Notifications", isOn: Binding(get: { app.device.permission == .authorized }, set: { app.device.setSimulatedPermission($0) })) }
                footer: { Text(app.device.permission == .authorized ? "Return to Fomio to finish setting up alerts." : "Allow Notifications is off. Fomio can’t show alerts on this \(words.device).") }
            }.navigationTitle("\(words.system) Settings (simulated)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Back to Fomio") {
                dismiss()
                if app.device.permission == .authorized, app.device.status != .on { Task { await app.device.enroll(account: app.account) } }
            } } }
        }
    }
}

/// In-app browser for verified same-site links only. Fixtures show a labelled simulation.
struct WebDestinationSheet: View {
    @Environment(AppState.self) private var app
    let url: URL
    var body: some View {
        if app.fixture != nil {
            NavigationStack {
                ScreenMessage(title: "Website (simulated)", message: "Fixture preview. A live build opens \(url.host ?? "the community")\(url.path) in an in-app browser.", symbol: "safari", actionTitle: "Done") { app.webDestination = nil }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { app.webDestination = nil } } }
            }
        } else { SafariView(url: url).ignoresSafeArea() }
    }
}
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Composer protection: a tapped notification waits while a changed draft is open.
struct PendingNotificationChip: View {
    @Environment(AppState.self) private var app
    var body: some View {
        if app.pendingIntent != nil, app.composer != nil {
            HStack(spacing: 8) {
                Image(systemName: "bell").accessibilityHidden(true)
                Text("Notification waiting. Open it when you’re ready.").font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                Button("Open") { app.intentNeedsComposerDecision = true }.font(.footnote.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("pending-notification-open")
            }.padding(.horizontal, 14).background(Color.fomioFill, in: .capsule).padding(.horizontal, 16).padding(.top, 6)
        }
    }
}
