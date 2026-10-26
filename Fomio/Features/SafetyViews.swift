import SwiftUI

struct ReportPostView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let post: Post
    @State private var reasons: [ReportReason] = []
    @State private var selected: Int?
    @State private var message = ""
    @State private var loaded = false
    @State private var submitting = false
    @State private var uncertain = false
    @State private var error: String?
    private var reason: ReportReason? { reasons.first { $0.id == selected } }
    private var excerpt: String { (post.cooked.map(HTMLContent.plainText) ?? post.body).trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Avatar(name: post.authorName ?? post.author, size: 28)
                            Text(post.authorName ?? "@\(post.author)").font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            Text("#\(post.number.rawValue)").font(.caption).foregroundStyle(Color.fomioSecondaryText)
                        }
                        if !excerpt.isEmpty { Text(excerpt).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(3) }
                    }.padding(.vertical, 4).accessibilityElement(children: .combine)
                } footer: { Text("Your report goes to the community’s moderators.") }
                if !loaded { ProgressView("Checking reporting options…") }
                else if reasons.isEmpty && error == nil { Text("You can’t report this post with your current account. Contact support if you need help.") }
                if !reasons.isEmpty {
                    Section("Why are you reporting it?") {
                        ForEach(reasons) { option in
                            Button { selected = option.id } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.title).foregroundStyle(Color.fomioText)
                                        if !option.description.isEmpty { Text(option.description).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.fomioAccent).opacity(selected == option.id ? 1 : 0).accessibilityHidden(true)
                                }.frame(minHeight: 44).contentShape(.rect)
                            }.buttonStyle(.plain)
                            .accessibilityElement(children: .ignore).accessibilityLabel(option.title).accessibilityHint(option.description)
                            .accessibilityAddTraits(selected == option.id ? [.isButton, .isSelected] : .isButton)
                            .accessibilityIdentifier("report-reason-\(option.id)")
                        }
                    }
                    if reason != nil {
                        Section {
                            TextField(reason?.requiresMessage == true ? "Explain your concern" : "Explain your concern (optional)", text: $message, axis: .vertical).lineLimit(4...10)
                                .accessibilityIdentifier("report-details")
                        } header: { Text("Details") } footer: { if reason?.requiresMessage == true { Text("Required for this reason.") } }
                    }
                }
                if uncertain {
                    Label("Your report may have been received, but it wasn’t confirmed. Close this screen and check the post before reporting again.", systemImage: "questionmark.circle")
                }
                if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Color.fomioDanger) }
                if error != nil && reasons.isEmpty && !uncertain { Button("Try again") { Task { await load() } }.foregroundStyle(Color.fomioAccent) }
                if submitting { ProgressView("Sending report…") }
            }
            .disabled(submitting || uncertain)
            .navigationTitle("Report post").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.disabled(submitting) }
                ToolbarItem(placement: .confirmationAction) {
                    // A symbol lets the item stay in a compressed vertical bar, such as iPhone Duo's with the keyboard up.
                    Button("Send report", systemImage: "paperplane") { Task { await send() } }.buttonStyle(.glassProminent).tint(Color.fomioAccent)
                        .disabled(submitting || uncertain || reason == nil || (reason?.requiresMessage == true && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }.task { await load() }
        }.interactiveDismissDisabled(submitting)
    }
    private func load() async {
        guard !submitting, !uncertain else { return }
        loaded = false
        do { reasons = try await app.service.reportReasons(post: post); error = nil }
        catch { self.error = error.localizedDescription }
        loaded = true
    }
    private func send() async {
        guard let reason, !submitting, !uncertain, let username = app.username else { return }
        submitting = true; error = nil
        do {
            try await app.service.report(post: post, reason: reason.id, message: message)
            if app.username == username { dismiss(); app.toast("Report received") }
        } catch {
            self.error = error.localizedDescription
            let kind = error as? RepositoryError
            uncertain = kind == .offline || kind == .unconfirmed || kind == nil
            if case .server = kind { uncertain = true }
        }
        submitting = false
    }
}

struct BlockingButton: View {
    @Environment(AppState.self) private var app
    let username: String
    @State private var confirming = false
    private var blocked: Bool { app.isBlocked(username) }
    var body: some View {
        if let current = app.username, current.caseInsensitiveCompare(username) != .orderedSame, !username.isEmpty {
            Button { confirming = true } label: {
                Label(blocked ? "Unblock member" : "Block member…", systemImage: blocked ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
            }.disabled(app.safetyChanging.contains(username.lowercased()))
                .modifier(BlockingConfirmation(username: username, confirming: $confirming))
        }
    }
}

struct BlockingConfirmation: ViewModifier {
    @Environment(AppState.self) private var app
    let username: String
    @Binding var confirming: Bool
    @State private var error: String?
    private var blocked: Bool { app.isBlocked(username) }
    func body(content: Content) -> some View {
        content.confirmationDialog(blocked ? "Unblock @\(username)?" : "Block @\(username)?", isPresented: $confirming, titleVisibility: .visible) {
                    Button(blocked ? "Unblock member" : "Block member", role: blocked ? nil : .destructive) {
                        let desired = !blocked
                        Task { do { try await app.changeBlocking(username, blocked: desired) } catch { self.error = error.localizedDescription } }
                    }
                } message: {
                    Text(blocked ? "Their content will be visible again." : "Their posts and notifications will be hidden using the community’s Ignore setting. You can unblock them at any time in Me. Community permissions still apply.")
                }
                .alert("Couldn’t change blocking", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("Refresh blocked members") { error = nil; Task { await app.refreshSafety() } }
                    Button("Close", role: .cancel) { error = nil }
                } message: { Text((error ?? "") + " Check the blocked-members list before trying again.") }
    }
}

struct BlockedMemberRow: View {
    @Environment(AppState.self) private var app
    let username: String
    @State private var confirming = false
    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: username, size: 36)
            Text("@\(username)").font(.body.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 8)
            Button("Unblock") { confirming = true }
                .buttonStyle(.bordered).foregroundStyle(Color.fomioAccent).frame(minHeight: 44)
                .disabled(app.safetyChanging.contains(username.lowercased()))
                .accessibilityLabel("Unblock @\(username)").accessibilityIdentifier("unblock-\(username)")
        }.modifier(BlockingConfirmation(username: username, confirming: $confirming))
    }
}

struct BlockedMembersView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        List {
            if let error = app.safetyError {
                Section {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Color.fomioDanger)
                    Button("Refresh") { Task { await app.refreshSafety() } }.foregroundStyle(Color.fomioAccent).frame(minHeight: 44)
                }
            }
            if let session = app.safety, session.username == app.username {
                let names = session.ignoredUsers
                Section {
                    if names.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No blocked members").font(.headline)
                            Text("Block someone from a post’s More menu or their profile.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                        }.padding(.vertical, 6)
                    }
                    ForEach(names, id: \.self) { name in BlockedMemberRow(username: name) }
                } footer: {
                    Text("Blocking hides a member’s posts and notifications from you on every device signed in to this account. It uses the community’s Ignore setting and lasts until you unblock.")
                }
            } else if app.safetyError == nil { ProgressView("Loading blocked members…") }
        }.navigationTitle("Blocked members").task { await app.refreshSafety() }
            .refreshable { await app.refreshSafety() }
    }
}
