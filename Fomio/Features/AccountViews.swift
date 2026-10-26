import SwiftUI

/// Search and (where shown) Create stay toolbar actions on root screens.
struct RootToolbar: ToolbarContent {
    let app: AppState
    var compose = false
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search discussions")
            if compose { Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New discussion") }
        }
    }
}
struct MeView: View {
    @Environment(AppState.self) private var app
    @State private var signOutWarning = false
    @State private var savedCount: Int?
    @State private var draftCount = 0
    @State private var deletingAccount = false
    var body: some View {
        List {
            if let username = app.username {
                Section {
                    Button { app.navigate(.profile(username)) } label: {
                        HStack(spacing: 14) {
                            Avatar(name: app.displayName ?? username, size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.displayName ?? username).font(.headline).foregroundStyle(.primary)
                                Text("@\(username) · View profile").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 6).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel("View your profile, \(app.displayName ?? username)")
                }
                Section {
                    row("Saved", symbol: "bookmark", count: savedCount) { app.navigate(.saved) }.accessibilityIdentifier("me-saved")
                    row("Drafts", symbol: "doc.text", count: draftCount) { app.navigate(.drafts) }.accessibilityIdentifier("me-drafts")
                    NavigationLink { BlockedMembersView() } label: { Label("Blocked members", systemImage: "person.crop.circle.badge.xmark").frame(minHeight: 44) }
                    if let configuration = app.configuration {
                        Link(destination: configuration.url("u/\(username)/preferences/account")) {
                            Label("Account settings on website", systemImage: "person.crop.circle")
                        }.frame(minHeight: 44)
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) { signOutWarning = true }.foregroundStyle(Color.fomioDanger).frame(minHeight: 44)
                    Button("Delete account…", role: .destructive) { deletingAccount = true }.foregroundStyle(Color.fomioDanger).frame(minHeight: 44)
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in to see your profile").font(.headline)
                        Text("Your saved discussions and drafts live here once you're signed in.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                        Button("Sign in") { app.requestSignIn() }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44)
                    }.padding(.vertical, 8)
                }
            }
            Section("Support and policies") {
                Link(destination: URL(string: "mailto:support@fomio.app")!) { Label("Email support", systemImage: "envelope") }.frame(minHeight: 44)
                if let configuration = app.configuration {
                    Link(destination: configuration.url("about")) { Label("Help and contact", systemImage: "questionmark.circle") }.frame(minHeight: 44)
                    Link(destination: configuration.url("privacy")) { Label("Privacy policy", systemImage: "hand.raised") }.frame(minHeight: 44)
                    Link(destination: configuration.url("tos")) { Label("Terms of service", systemImage: "doc.text") }.frame(minHeight: 44)
                }
            }
            if app.fixture != nil {
                Section("Development preview") {
                    Button { app.navigate(.diagnostics) } label: { Label("Fixture scenarios", systemImage: "slider.horizontal.3") }.frame(minHeight: 44)
                    Button { app.navigate(.credits) } label: { Label("Photo credits", systemImage: "photo") }.frame(minHeight: 44)
                }
            }
        }.scrollContentBackground(.hidden).background(Color.fomioGrouped).navigationTitle("Me")
        .toolbar { RootToolbar(app: app) }
        .task(id: "\(app.username ?? "")-\(app.draftsRevision)") { await loadCounts() }
        .sheet(isPresented: $deletingAccount) {
            if let username = app.username { DeleteAccountView(username: username) }
        }
        .alert("Sign out of \(app.username ?? "this account")?", isPresented: $signOutWarning) { Button("Cancel", role: .cancel) {}; Button("Sign out", role: .destructive) { app.signOut() } } message: { Text("You can sign in again at any time. Drafts for this account will be removed from this device.") }
    }
    private func row(_ title: String, symbol: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol).foregroundStyle(.primary)
                Spacer()
                if let count { Text("\(count)").foregroundStyle(Color.fomioSecondaryText) }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }.frame(minHeight: 44).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
    }
    private func loadCounts() async {
        draftCount = (try? app.draftStore.list(account: app.account).count) ?? 0
        if let username = app.username, let page = try? await app.service.saved(username: username, page: 0), page.nextPage == nil { savedCount = page.items.count } else { savedCount = nil }
    }
}

struct DeleteAccountView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let username: String
    @State private var permitted: Bool?
    @State private var confirmation = ""
    @State private var confirming = false
    @State private var submitting = false
    @State private var deleted = false
    @State private var uncertain = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Permanently delete your account and its posts. This cannot be undone.")
                    Text("Local drafts and sign-in details will be removed from this device after the community confirms deletion.").foregroundStyle(.secondary)
                }
                if deleted {
                    Section {
                        Text("Your account was deleted. Local sign-out still needs to finish.")
                        Button("Finish sign-out") { app.signOut(); if app.username == nil { dismiss() } }.foregroundStyle(Color.fomioAccent)
                    }
                } else if uncertain {
                    Section {
                        Text("Deletion could not be confirmed. Check your account on the website or contact support before trying again.")
                        if let configuration = app.configuration {
                            Link("Check account on website", destination: configuration.url("u/\(username)/preferences/account"))
                        }
                    }
                } else if permitted == true {
                    Section {
                        TextField("Type \(username) to confirm", text: $confirmation)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityLabel("Type your username to confirm account deletion")
                        Button("Delete account permanently", role: .destructive) { confirming = true }
                            .foregroundStyle(confirmation == username ? Color.fomioDanger : Color.fomioSecondaryText)
                            .disabled(confirmation != username || submitting)
                    } footer: { Text("You are deleting @\(username).") }
                } else if permitted == false {
                    Section { Text("This account cannot be deleted automatically. Contact support for help deleting your account and associated data.") }
                } else if error == nil {
                    ProgressView("Checking account…")
                }
                if let error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Color.fomioDanger) } }
                if !deleted {
                    Section {
                        Link("Contact support", destination: URL(string: "mailto:support@fomio.app")!).foregroundStyle(Color.fomioAccent)
                        if permitted == nil && error != nil { Button("Check again") { Task { await check() } }.foregroundStyle(Color.fomioAccent).disabled(submitting) }
                    }
                }
                if submitting { ProgressView("Deleting account…") }
            }
            .disabled(submitting)
            .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.disabled(submitting) } }
            .task { await check() }
            .alert("Permanently delete @\(username)?", isPresented: $confirming) {
                Button("Cancel", role: .cancel) {}
                Button("Delete account", role: .destructive) { Task { await delete() } }
            } message: { Text("Your account and its posts will be deleted. This cannot be undone.") }
        }.interactiveDismissDisabled(submitting)
    }
    private func check() async {
        guard app.username == username else { error = "Sign in to this account again."; return }
        do { permitted = try await app.service.canDeleteAccount(username: username); error = nil }
        catch { self.error = error.localizedDescription }
    }
    private func delete() async {
        guard !submitting, !deleted, !uncertain, confirmation == username, app.username == username else { return }
        submitting = true; error = nil
        do {
            try await app.service.deleteAccount(username: username)
            deleted = true
            app.signOut()
            if app.username == nil { dismiss(); app.toast("Account deleted") }
            else { error = app.banner }
        } catch {
            self.error = error.localizedDescription
            // A transport failure may occur after deletion. Never offer a blind destructive retry.
            let kind = error as? RepositoryError
            uncertain = kind == .offline || kind == .unconfirmed || kind == nil
            if case .server = kind { uncertain = true }
        }
        submitting = false
    }
}
struct ProfileView: View {
    @Environment(AppState.self) private var app
    let username: String
    @State private var member: Member?
    @State private var error: String?
    @State private var blocking = false
    var body: some View {
        ScrollView {
            ReadingColumn {
                VStack(alignment: .leading, spacing: 16) {
                    if let member {
                        HStack(spacing: 14) {
                            Avatar(name: member.name ?? member.username, size: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.name ?? member.username).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                                Text("@\(member.username)\(member.joined.map { " · Joined \($0)" } ?? "")").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                            }
                        }
                        if app.isBlocked(username) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("You blocked this member", systemImage: "person.crop.circle.badge.xmark").font(.subheadline.weight(.semibold))
                                Text("Their bio, discussions and replies are hidden from you.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                                BlockingButton(username: username).font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
                        } else {
                            if !member.bio.isEmpty { Text(member.bio).textSelection(.enabled) }
                            SectionLabel("Recent discussions").padding(.top, 8)
                            if member.recent.isEmpty { Text("No discussions started yet.").foregroundStyle(Color.fomioSecondaryText) }
                            VStack(spacing: 0) {
                                ForEach(member.recent.filter { !app.isBlocked($0.author) }) { topic in
                                    Button { app.navigate(.discussion(topic.id, nil)) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(app.categoryName(topic.categoryID)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                                            Text(topic.title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                            Text([repliesText(topic.replyCount), topic.activity].filter { !$0.isEmpty }.joined(separator: " · ")).font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12).contentShape(.rect)
                                    }.buttonStyle(.plain).accessibilityLabel("\(topic.title), in \(app.categoryName(topic.categoryID))")
                                    Divider().overlay(Color.fomioSeparator)
                                }
                            }
                        }
                    } else if let error { ScreenMessage(title: "Profile unavailable", message: error, action: { Task { await load() } }) }
                    else { ProgressView().frame(maxWidth: .infinity).padding(40) }
                }.padding(20)
            }
        }.background(Color.fomioBackground).navigationTitle(username == app.username ? "Profile" : username).navigationBarTitleDisplayMode(.inline).task { await load() }
        .toolbar {
            if member != nil, !app.isBlocked(username), let current = app.username, current.caseInsensitiveCompare(username) != .orderedSame {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { blocking = true } label: { Label("Block member…", systemImage: "person.crop.circle.badge.xmark") }
                            .disabled(app.safetyChanging.contains(username.lowercased()))
                    } label: { Image(systemName: "ellipsis") }.accessibilityLabel("More for @\(username)")
                }
            }
        }
        .modifier(BlockingConfirmation(username: username, confirming: $blocking))
    }
    private func load() async { do { member = try await app.service.profile(username); error = nil } catch { self.error = error.localizedDescription } }
}
struct DraftsView: View {
    @Environment(AppState.self) private var app
    @State private var drafts: [Draft] = []
    @State private var error: String?
    @State private var deleting: Draft?
    @State private var titles: [TopicID: String] = [:]
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(Color.fomioDanger) }
            if drafts.isEmpty && error == nil {
                VStack(alignment: .leading, spacing: 6) { Text("No drafts").font(.headline); Text("When you keep unfinished writing, it waits here.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }.padding(.vertical, 8)
            }
            ForEach(drafts) { draft in
                VStack(alignment: .leading, spacing: 6) {
                    Button { app.resume(draft) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(kind(draft)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                            Text(title(draft)).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(draft.body.isEmpty ? "No text yet" : draft.body).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(2)
                            if draft.missingPhoto {
                                Label("Photo not included. It hadn’t finished uploading. Add it again after you resume.", systemImage: "photo.badge.exclamationmark").font(.footnote).foregroundStyle(.primary)
                            }
                            if draft.submission == .pending { Label("Pending review · posting locked", systemImage: "clock").font(.footnote) }
                            if draft.submission == .unconfirmed { Label("Not confirmed · check before posting again", systemImage: "questionmark.circle").font(.footnote) }
                            Text(RelativeAge.edited(draft.updatedAt)).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                    }.buttonStyle(.plain).frame(minHeight: 44).accessibilityLabel("Resume draft: \(kind(draft)), \(title(draft))")
                    HStack(spacing: 20) {
                        Button("Resume") { app.resume(draft) }.font(.subheadline.weight(.semibold)).buttonStyle(.borderless)
                        Button("Discard", role: .destructive) { deleting = draft }.font(.subheadline.weight(.semibold)).buttonStyle(.borderless).accessibilityLabel("Discard draft: \(title(draft))")
                    }.frame(minHeight: 44)
                }.padding(.vertical, 6)
            }
        }.navigationTitle("Drafts").task(id: app.draftsRevision) { reload(); await loadTitles() }
        .alert("Discard this draft?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Discard", role: .destructive) { if let deleting { do { try app.discardDraft(deleting); reload(); app.toast("Draft discarded") } catch { self.error = error.localizedDescription } }; deleting = nil }
        } message: { Text(deleting?.submission == .editing ? "This can’t be undone." : "This can’t be undone. It removes the local record only, not a post the community already received.") }
    }
    private func kind(_ draft: Draft) -> String {
        if case let .reply(topic, _) = draft.intent {
            let category = (draft.contextCategory ?? app.fixture?.summaries.first { $0.id == topic }?.categoryID).map(app.categoryName)
            return (draft.quote != nil ? "Quote reply" : "Reply") + (category.map { " · \($0)" } ?? "")
        }
        return "New discussion · " + (draft.categoryID.map(app.categoryName) ?? "No community chosen")
    }
    private func title(_ draft: Draft) -> String {
        if case let .reply(topic, _) = draft.intent { return draft.contextTitle ?? titles[topic] ?? "Discussion \(topic.rawValue)" }
        return draft.title.isEmpty ? "Untitled discussion" : draft.title
    }
    private func reload() { do { drafts = try app.draftStore.list(account: app.account); error = nil } catch { self.error = error.localizedDescription } }
    private func loadTitles() async {
        for case let .reply(topic, _) in drafts.filter({ $0.contextTitle == nil }).map(\.intent) where titles[topic] == nil {
            if let page = try? await app.service.discussion(topic, page: 0) { titles[topic] = page.summary.title }
        }
    }
}
struct SavedView: View {
    @Environment(AppState.self) private var app
    @State private var items: [SavedItem] = []
    @State private var nextPage: Int? = 0
    @State private var error: String?
    @State private var loading = false
    @State private var loaded = false
    var body: some View {
        List {
            ForEach(items.filter { !app.isBlocked($0.postAuthor ?? "") }) { item in
                let reply = item.number.map { $0.rawValue > 1 } ?? false
                Button { app.navigate(.discussion(item.topicID, reply ? item.number : nil), focus: reply ? .saved : nil) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply ? "Reply #\(item.number!.rawValue)\(item.postAuthor.map { " by \($0)" } ?? "")" : "Discussion").font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                        Text(item.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        if let category = item.categoryID { Text(app.categoryName(category)).font(.footnote).foregroundStyle(Color.fomioSecondaryText) }
                    }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel(reply ? "Saved reply \(item.number!.rawValue) in \(item.title)" : "Saved discussion \(item.title)")
            }
            if loading { ProgressView() }
            if let error { Text(error); Button("Try again") { Task { await load() } } }
            else if nextPage != nil && loaded { Button("More saved items") { Task { await load() } } }
            else if items.isEmpty && loaded {
                VStack(alignment: .leading, spacing: 6) { Text("Nothing saved yet").font(.headline); Text("Use Save in a discussion's menu to keep it here.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }.padding(.vertical, 8)
            }
        }.navigationTitle("Saved").task { await load() }
    }
    private func load() async {
        guard !loading, let page = nextPage, let username = app.username else { return }; loading = true; defer { loading = false }
        do { let result = try await app.service.saved(username: username, page: page); items += result.items.filter { item in !items.contains { $0.id == item.id } }; nextPage = result.nextPage; error = nil; loaded = true } catch { self.error = error.localizedDescription }
    }
}
/// A match inside a reply opens that exact post; the label says where the match is.
struct SearchResultRow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var textSize
    let result: DiscussionSummary
    let query: String
    private var inReply: Bool { (result.targetPostNumber?.rawValue ?? 1) > 1 }
    var body: some View {
        Button { app.navigate(.discussion(result.id, result.targetPostNumber), focus: .search) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.categoryName(result.categoryID)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                Text(result.title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).environment(\.layoutDirection, result.title.naturalDirection)
                if !result.excerpt.isEmpty { Text(snippet).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(textSize.isAccessibilitySize ? nil : 3).multilineTextAlignment(.leading).environment(\.layoutDirection, result.excerpt.naturalDirection) }
                Text(inReply ? "Reply #\(result.targetPostNumber!.rawValue)\((result.matchAuthor ?? result.author).isEmpty ? "" : " by \(result.matchAuthor ?? result.author)")" : "Opening post\(result.author.isEmpty ? "" : " by \(result.author)")")
                    .font(.footnote).foregroundStyle(Color.fomioSecondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 12).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityIdentifier("topic-\(result.id.rawValue)")
        .accessibilityLabel("\(result.title), \(inReply ? "match in reply \(result.targetPostNumber!.rawValue)" : "match in discussion")")
        Divider().overlay(Color.fomioSeparator).padding(.leading, 20)
    }
    private var snippet: AttributedString {
        let text = result.excerpt
        guard !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) else { return AttributedString(text) }
        let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        var value = AttributedString((start > text.startIndex ? "…" : "") + text[start..<range.lowerBound])
        var match = AttributedString(text[range]); match.font = .subheadline.weight(.bold); match.foregroundColor = .primary
        value += match; value += AttributedString(text[range.upperBound...])
        return value
    }
}
struct DiagnosticsView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        if let fixture = app.fixture { FixtureControls(fixture: fixture) }
    }
}
struct FixtureControls: View {
    @Environment(AppState.self) private var app
    @Bindable var fixture: FixtureService
    var body: some View {
        Form {
            Section("Development only") { Text("These controls simulate outcomes. Nothing is sent to a live community.").foregroundStyle(.secondary) }
            Picker("Next post outcome", selection: $fixture.scenario) { ForEach(FixtureService.Scenario.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Toggle("Offline", isOn: $fixture.offline)
            Toggle("Photo fails at 60%", isOn: $fixture.uploadFails)
            Toggle("Nested replies available", isOn: $fixture.nestedEnabled)
            Section {
                Button("Add sample drafts") {
                    do { for draft in FixtureService.sampleDrafts(account: app.account) { try app.draftStore.save(draft) }; app.draftsRevision += 1; app.toast("Sample drafts added to Me › Drafts.") }
                    catch { app.banner = error.localizedDescription }
                }
            } footer: { Text("Adds the mockup’s reply, new-discussion and photo-not-included drafts for this account.") }
        }.navigationTitle("Fixture scenarios")
    }
}
