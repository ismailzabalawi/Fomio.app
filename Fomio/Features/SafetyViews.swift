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
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Report post #\(post.number.rawValue) by @\(post.author). Your report goes to the community’s moderators.") }
                if !loaded { ProgressView("Checking reporting options…") }
                else if reasons.isEmpty && error == nil { Text("Reporting is not available for this post with your current account.") }
                if !reasons.isEmpty {
                    Section("Reason") {
                        Picker("Reason", selection: $selected) {
                            Text("Choose a reason").tag(nil as Int?)
                            ForEach(reasons) { Text($0.title).tag(Optional($0.id)) }
                        }.accessibilityIdentifier("report-reason")
                        if let reason, !reason.description.isEmpty { Text(reason.description).foregroundStyle(.secondary) }
                    }
                    Section(reason?.requiresMessage == true ? "Details (required)" : "Details (optional)") {
                        TextField("Explain your concern", text: $message, axis: .vertical).lineLimit(4...10)
                    }
                }
                if uncertain { Text("Your report may have been received. It has not been confirmed. Close this screen and check the post before reporting again.") }
                if let error { Text(error).foregroundStyle(Color.fomioDanger) }
                if error != nil && reasons.isEmpty && !uncertain { Button("Try again") { Task { await load() } } }
                if submitting { ProgressView("Sending report…") }
            }
            .disabled(submitting || uncertain)
            .navigationTitle("Report post").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(submitting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send report") { Task { await send() } }
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
            if app.username == username { dismiss(); app.toast("Report sent to moderators") }
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

struct BlockedMembersView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        List {
            if let error = app.safetyError { Section { Text(error); Button("Refresh") { Task { await app.refreshSafety() } } } }
            if let session = app.safety, session.username == app.username {
                let names = session.ignoredUsers
                if names.isEmpty { Text("No blocked members") }
                ForEach(names, id: \.self) { name in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(name)").font(.headline)
                        BlockingButton(username: name)
                    }.padding(.vertical, 4)
                }
            } else if app.safetyError == nil { ProgressView("Loading blocked members…") }
            Section { Text("Blocks are saved to your community account using Ignore with the Forever option. You can unblock a member at any time.").foregroundStyle(.secondary) }
        }.navigationTitle("Blocked members").task { await app.refreshSafety() }
            .refreshable { await app.refreshSafety() }
    }
}
