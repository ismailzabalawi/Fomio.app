import SwiftUI

/// Search and (where shown) Create stay toolbar actions on root screens.
struct RootToolbar: ToolbarContent {
    let app: AppState
    var compose = false
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel(L("search.discussions"))
            if compose { Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel(L("composer.new_discussion")) }
        }
    }
}
struct MeView: View {
    @Environment(AppState.self) private var app
    @State private var signOutWarning = false
    @State private var savedCount: Int?
    @State private var draftCount = 0
    var body: some View {
        List {
            if let username = app.username {
                Section {
                    Button { app.navigate(.profile(username)) } label: {
                        HStack(spacing: 14) {
                            Avatar(name: app.displayName ?? username, size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.displayName ?? username).font(.headline).foregroundStyle(.primary)
                                Text(L("me.handle_view_profile", ["username": username])).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 6).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel(L("me.view_your_profile", ["name": app.displayName ?? username]))
                }
                Section {
                    row(L("me.saved"), symbol: "bookmark", count: savedCount) { app.navigate(.saved) }.accessibilityIdentifier("me-saved")
                    row(L("me.drafts"), symbol: "doc.text", count: draftCount) { app.navigate(.drafts) }.accessibilityIdentifier("me-drafts")
                }
                Section { Button(L("auth.sign_out"), role: .destructive) { signOutWarning = true }.frame(minHeight: 44) }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("me.guest.title")).font(.headline)
                        Text(L("me.guest.message")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                        Button(L("auth.sign_in")) { app.requestSignIn() }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44)
                    }.padding(.vertical, 8)
                }
            }
            Section {
                Button { app.navigate(.language) } label: {
                    HStack {
                        Label(L("language.title"), systemImage: "globe").foregroundStyle(.primary)
                        Spacer()
                        Text(app.localization.currentName).foregroundStyle(Color.fomioSecondaryText)
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel(L("language.row_a11y", ["language": app.localization.currentName])).accessibilityIdentifier("me-language")
            }
            if app.fixture != nil {
                Section(DevText("Development preview")) {
                    Button { app.navigate(.diagnostics) } label: { Label(DevText("Fixture scenarios"), systemImage: "slider.horizontal.3") }.frame(minHeight: 44)
                    Button { app.navigate(.credits) } label: { Label(L("me.photo_credits"), systemImage: "photo") }.frame(minHeight: 44)
                }
            }
        }.scrollContentBackground(.hidden).background(Color.fomioGrouped).navigationTitle(L("tab.me"))
        .toolbar { RootToolbar(app: app) }
        .task(id: "\(app.username ?? "")-\(app.draftsRevision)") { await loadCounts() }
        .alert(app.username.map { L("auth.sign_out.confirm_title", ["name": $0]) } ?? L("auth.sign_out.confirm_title_generic"), isPresented: $signOutWarning) { Button(L("common.cancel"), role: .cancel) {}; Button(L("auth.sign_out"), role: .destructive) { app.signOut() } } message: { Text(L("auth.sign_out.confirm_message")) }
    }
    private func row(_ title: String, symbol: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol).foregroundStyle(.primary)
                Spacer()
                if let count { Text(count, format: .number).foregroundStyle(Color.fomioSecondaryText) }
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }.frame(minHeight: 44).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel(count.map { L("me.row_count", ["title": title, "count": $0.formatted(.number.locale(Localizer.shared.formattingLocale))]) } ?? title)
    }
    private func loadCounts() async {
        draftCount = (try? app.draftStore.list(account: app.account).count) ?? 0
        if let username = app.username, let page = try? await app.service.saved(username: username, page: 0), page.nextPage == nil { savedCount = page.items.count } else { savedCount = nil }
    }
}
struct ProfileView: View {
    @Environment(AppState.self) private var app
    let username: String
    @State private var member: Member?
    @State private var error: DisplayError?
    var body: some View {
        ScrollView {
            ReadingColumn {
                VStack(alignment: .leading, spacing: 16) {
                    if let member {
                        HStack(spacing: 14) {
                            Avatar(name: member.name ?? member.username, size: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.name ?? member.username).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                                Text(member.joined.map { L("profile.handle_joined", ["username": member.username, "joined": $0]) } ?? L("profile.handle", ["username": member.username])).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                            }
                        }
                        if !member.bio.isEmpty { Text(member.bio).textSelection(.enabled).contentDirection(member.bio) }
                        SectionLabel(L("profile.recent")).padding(.top, 8)
                        if member.recent.isEmpty { Text(L("profile.no_recent")).foregroundStyle(Color.fomioSecondaryText) }
                        VStack(spacing: 0) {
                            ForEach(member.recent) { topic in
                                Button { app.navigate(.discussion(topic.id, nil)) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(app.categoryName(topic.categoryID)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                                        Text(topic.title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).contentDirection(topic.title)
                                        Text([repliesText(topic.replyCount), topic.activity.compact].filter { !$0.isEmpty }.joined(separator: L("common.meta_separator"))).font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12).contentShape(.rect)
                                }.buttonStyle(.plain).accessibilityLabel(L("profile.topic_a11y", ["title": topic.title, "community": app.categoryName(topic.categoryID)]))
                                Divider().overlay(Color.fomioSeparator)
                            }
                        }
                    } else if let error { ScreenMessage(title: L("profile.unavailable"), message: error.text, action: { Task { await load() } }) }
                    else { ProgressView().frame(maxWidth: .infinity).padding(40) }
                }.padding(20)
            }
        }.background(Color.fomioBackground).navigationTitle(username == app.username ? L("profile.title") : username).navigationBarTitleDisplayMode(.inline).task { await load() }
    }
    private func load() async { do { member = try await app.service.profile(username); error = nil } catch { self.error = DisplayError(error) } }
}
struct DraftsView: View {
    @Environment(AppState.self) private var app
    @State private var drafts: [Draft] = []
    @State private var error: DisplayError?
    @State private var deleting: Draft?
    @State private var titles: [TopicID: String] = [:]
    var body: some View {
        List {
            if let error { Text(error.text).foregroundStyle(Color.fomioDanger) }
            if drafts.isEmpty && error == nil {
                VStack(alignment: .leading, spacing: 6) { Text(L("drafts.empty.title")).font(.headline); Text(L("drafts.empty.message")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }.padding(.vertical, 8)
            }
            ForEach(drafts) { draft in
                VStack(alignment: .leading, spacing: 6) {
                    Button { app.resume(draft) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(kind(draft)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                            Text(title(draft)).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(draft.body.isEmpty ? L("drafts.no_text") : draft.body).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(2)
                            if draft.missingPhoto {
                                Label(L("drafts.photo_not_included"), systemImage: "photo.badge.exclamationmark").font(.footnote).foregroundStyle(.primary)
                            }
                            if draft.submission == .pending { Label(L("drafts.pending"), systemImage: "clock").font(.footnote) }
                            if draft.submission == .unconfirmed { Label(L("drafts.unconfirmed"), systemImage: "questionmark.circle").font(.footnote) }
                            Text(RelativeAge.edited(draft.updatedAt)).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                    }.buttonStyle(.plain).frame(minHeight: 44).accessibilityLabel(L("drafts.resume_a11y", ["kind": kind(draft), "title": title(draft)]))
                    HStack(spacing: 20) {
                        Button(L("drafts.resume")) { app.resume(draft) }.font(.subheadline.weight(.semibold)).buttonStyle(.borderless)
                        Button(L("composer.discard"), role: .destructive) { deleting = draft }.font(.subheadline.weight(.semibold)).buttonStyle(.borderless).accessibilityLabel(L("drafts.discard_a11y", ["title": title(draft)]))
                    }.frame(minHeight: 44)
                }.padding(.vertical, 6)
            }
        }.navigationTitle(L("me.drafts")).task(id: app.draftsRevision) { reload(); await loadTitles() }
        .alert(L("drafts.discard.title"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(L("common.cancel"), role: .cancel) { deleting = nil }
            Button(L("composer.discard"), role: .destructive) { if let deleting { do { try app.draftStore.delete(deleting.id); reload(); app.toast(L("composer.draft_discarded")) } catch { self.error = DisplayError(error) } }; deleting = nil }
        } message: { Text(deleting?.submission == .editing ? L("drafts.discard.message") : L("drafts.discard.message_submitted")) }
    }
    private func kind(_ draft: Draft) -> String {
        if case let .reply(topic, _) = draft.intent {
            let category = (draft.contextCategory ?? app.fixture?.summaries.first { $0.id == topic }?.categoryID).map(app.categoryName)
            let kind = draft.quote != nil ? L("drafts.kind.quote_reply") : L("drafts.kind.reply")
            return category.map { L("drafts.kind_in", ["kind": kind, "community": $0]) } ?? kind
        }
        return L("drafts.kind_in", ["kind": L("composer.new_discussion"), "community": draft.categoryID.map(app.categoryName) ?? L("drafts.no_community")])
    }
    private func title(_ draft: Draft) -> String {
        if case let .reply(topic, _) = draft.intent { return draft.contextTitle ?? titles[topic] ?? L("composer.discussion_number", ["number": String(topic.rawValue)]) }
        return draft.title.isEmpty ? L("drafts.untitled") : draft.title
    }
    private func reload() { do { drafts = try app.draftStore.list(account: app.account); error = nil } catch { self.error = DisplayError(error) } }
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
    @State private var error: DisplayError?
    @State private var loading = false
    @State private var loaded = false
    var body: some View {
        List {
            ForEach(items) { item in
                let reply = item.number.map { $0.rawValue > 1 } ?? false
                Button { app.navigate(.discussion(item.topicID, reply ? item.number : nil), focus: reply ? .saved : nil) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply ? (item.postAuthor.map { L("saved.reply_by", ["number": String(item.number!.rawValue), "name": $0]) } ?? L("saved.reply", ["number": String(item.number!.rawValue)])) : L("discussion.nav_title")).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                        Text(item.title.isEmpty ? L("saved.untitled") : item.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading).contentDirection(item.title)
                        if let category = item.categoryID { Text(app.categoryName(category)).font(.footnote).foregroundStyle(Color.fomioSecondaryText) }
                    }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel(reply ? L("saved.reply_a11y", ["number": String(item.number!.rawValue), "title": item.title]) : L("saved.discussion_a11y", ["title": item.title]))
            }
            if loading { ProgressView() }
            if let error { Text(error.text); Button(L("common.try_again")) { Task { await load() } } }
            else if nextPage != nil && loaded { Button(L("saved.more")) { Task { await load() } } }
            else if items.isEmpty && loaded {
                VStack(alignment: .leading, spacing: 6) { Text(L("saved.empty.title")).font(.headline); Text(L("saved.empty.message")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }.padding(.vertical, 8)
            }
        }.navigationTitle(L("me.saved")).task { await load() }
    }
    private func load() async {
        guard !loading, let page = nextPage, let username = app.username else { return }; loading = true; defer { loading = false }
        do { let result = try await app.service.saved(username: username, page: page); items += result.items.filter { item in !items.contains { $0.id == item.id } }; nextPage = result.nextPage; error = nil; loaded = true } catch { self.error = DisplayError(error) }
    }
}
struct NotificationsView: View {
    @Environment(AppState.self) private var app
    @State private var items: [Notice] = []
    @State private var nextPage: Int? = 0
    @State private var error: DisplayError?
    @State private var loading = false
    var body: some View {
        Group {
            if app.username == nil {
                ScrollView {
                    InfoCard(title: L("notifications.guest.title"), message: L("notifications.guest.message")) {
                        Button(L("auth.sign_in")) { app.requestSignIn() }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).frame(minHeight: 44)
                    }.padding(20)
                }
            } else {
                List {
                    ForEach(items) { notice in
                        Button { open(notice) } label: { row(notice) }.buttonStyle(.plain)
                            .accessibilityLabel(accessibilityText(notice))
                    }
                    if loading { ProgressView() }
                    if let error { Text(error.text); Button(L("common.try_again")) { Task { await load() } } }
                    else if nextPage != nil && !items.isEmpty { Button(L("notifications.more")) { Task { await load() } } }
                    else if items.isEmpty && !loading { Text(L("notifications.empty")).foregroundStyle(Color.fomioSecondaryText) }
                }.listStyle(.plain)
            }
        }.background(Color.fomioBackground).navigationTitle(L("tab.notifications"))
        .toolbar { RootToolbar(app: app) }
        .task(id: app.username) { items = []; nextPage = 0; await load() }
    }
    private func row(_ notice: Notice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(notice.read ? Color.clear : Color.fomioAccent).frame(width: 8, height: 8).padding(.top, 15)
            Image(systemName: notice.kind == .reply ? "arrowshape.turn.up.backward.fill" : "at").font(.footnote.weight(.bold)).accessibilityHidden(true).foregroundStyle(Color.fomioAccent).frame(width: 34, height: 34).background(Color.fomioHighlight, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(notice.text).font(.body.weight(notice.read ? .regular : .semibold)).foregroundStyle(.primary)
                Text(notice.title).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(2).contentDirection(notice.title)
                Text(([notice.read ? nil : L("notifications.unread"), notice.number.map { L("post.number", ["number": String($0.rawValue)]) }, notice.age.isEmpty ? nil : notice.age.compact] as [String?]).compactMap { $0 }.joined(separator: L("common.meta_separator")))
                    .font(.footnote.weight(notice.read ? .regular : .semibold)).foregroundStyle(notice.read ? Color.fomioSecondaryText : Color.fomioAccent)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 8).frame(minHeight: 44).contentShape(.rect)
    }
    private func accessibilityText(_ notice: Notice) -> String {
        let base = L("notifications.row_a11y", ["text": notice.text, "title": notice.title, "number": String(notice.number?.rawValue ?? 0)])
        let aged = notice.age.isEmpty ? base : L("notifications.row_a11y_age", ["row": base, "age": notice.age.compact])
        return notice.read ? aged : L("notifications.row_a11y_unread", ["row": aged])
    }
    private func open(_ notice: Notice) {
        if let index = items.firstIndex(where: { $0.id == notice.id }), !items[index].read { items[index].read = true; app.unreadCount = max(0, app.unreadCount - 1) }
        Task { do { try await app.service.markRead(notice) } catch { app.banner = error.localizedDescription } }
        guard let topic = notice.topicID else { app.navigate(.unavailable); return }
        app.navigate(.discussion(topic, notice.number), focus: notice.number.map { $0.rawValue > 1 } == true ? .notification : nil)
    }
    private func load() async {
        guard !loading, app.username != nil, let page = nextPage else { return }; loading = true; defer { loading = false }
        do {
            let result = try await app.service.notifications(page: page); items += result.items.filter { notice in !items.contains { $0.id == notice.id } }; nextPage = result.nextPage; error = nil
            app.unreadCount = items.filter { !$0.read }.count
        } catch { self.error = DisplayError(error) }
    }
}
struct SearchView: View {
    @Environment(AppState.self) private var app
    @Bindable var state: TabState
    @FocusState private var searchFocused: Bool
    @State private var loading = false
    @State private var error: DisplayError?
    var body: some View {
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let error { ScreenMessage(title: L("search.unavailable"), message: error.text, action: { Task { await search(reset: true) } }) }
                    else if state.searchCompletedQuery == nil && !loading {
                        Text(L("search.intro")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).padding(20)
                    } else if let query = state.searchCompletedQuery, state.searchResults.isEmpty && !loading {
                        InfoCard(title: L("search.no_results", ["query": query]), message: L("search.no_results.message")).padding(20)
                    }
                    if !state.searchResults.isEmpty { SectionLabel(L("search.results_heading")).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4) }
                    ForEach(state.searchResults) { result in SearchResultRow(result: result, query: state.searchCompletedQuery ?? "").id(result.id) }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding(30).accessibilityLabel(L("search.searching")) }
                    if state.searchNextPage != nil && !loading { Button(L("search.more")) { Task { await search(reset: false) } }.frame(maxWidth: .infinity, minHeight: 44) }
                }.scrollTargetLayout().padding(.bottom, 20)
            }
        }.scrollDismissesKeyboard(.interactively).scrollPosition(id: $state.searchAnchor).background(Color.fomioBackground).navigationTitle(L("search.title")).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $state.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(L("search.discussions")))
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { searchFocused = false }
        .onDisappear { searchFocused = false }
        .task(id: state.searchQuery) { do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation(); if state.searchCompletedQuery != state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) { await search(reset: true) } } catch {} }
    }
    private func search(reset: Bool) async {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.count < 2 { state.searchResults = []; state.searchCompletedQuery = nil; state.searchNextPage = nil; error = nil; return }
        let requestQuery = query
        loading = true; defer { loading = false }
        do { let result = try await app.service.search(query, page: reset ? 1 : state.searchNextPage ?? 1); guard !Task.isCancelled, state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == requestQuery else { return }; state.searchResults = reset ? result.items : state.searchResults + result.items.filter { item in !state.searchResults.contains { $0.id == item.id } }; state.searchNextPage = result.nextPage; error = nil; state.searchCompletedQuery = requestQuery }
        catch is CancellationError {} catch { self.error = DisplayError(error) }
    }
}
/// A match inside a reply opens that exact post; the label says where the match is.
struct SearchResultRow: View {
    @Environment(AppState.self) private var app
    let result: DiscussionSummary
    let query: String
    private var inReply: Bool { (result.targetPostNumber?.rawValue ?? 1) > 1 }
    var body: some View {
        Button { app.navigate(.discussion(result.id, inReply ? result.targetPostNumber : nil), focus: inReply ? .search : nil) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.categoryName(result.categoryID)).font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent)
                Text(result.title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).contentDirection(result.title)
                if !result.excerpt.isEmpty { Text(snippet).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(3).multilineTextAlignment(.leading).contentDirection(result.excerpt) }
                Text(location)
                    .font(.footnote).foregroundStyle(Color.fomioSecondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 12).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityIdentifier("topic-\(result.id.rawValue)")
        .accessibilityLabel(inReply ? L("search.result_a11y.reply", ["title": result.title, "number": String(result.targetPostNumber!.rawValue)]) : L("search.result_a11y.discussion", ["title": result.title]))
        Divider().overlay(Color.fomioSeparator).padding(.leading, 20)
    }
    private var location: String {
        if inReply {
            let number = String(result.targetPostNumber!.rawValue), author = result.matchAuthor ?? result.author
            return author.isEmpty ? L("saved.reply", ["number": number]) : L("saved.reply_by", ["number": number, "name": author])
        }
        return result.author.isEmpty ? L("search.opening_post") : L("search.opening_post_by", ["name": result.author])
    }
    private var snippet: AttributedString {
        let text = result.excerpt
        guard !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) else { return AttributedString(text) }
        let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        var value = AttributedString((start > text.startIndex ? L("common.ellipsis") : "") + text[start..<range.lowerBound])
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
            Section(DevText("Development only")) { Text(DevText("These controls simulate outcomes. Nothing is sent to a live community.")).foregroundStyle(.secondary) }
            Picker(DevText("Next post outcome"), selection: $fixture.scenario) { ForEach(FixtureService.Scenario.allCases, id: \.self) { Text(DevText($0.rawValue.capitalized)).tag($0) } }
            Toggle(DevText("Offline"), isOn: $fixture.offline)
            Toggle(DevText("Photo fails at 60%"), isOn: $fixture.uploadFails)
            Toggle(DevText("Nested replies available"), isOn: $fixture.nestedEnabled)
            Section {
                Button(DevText("Add sample drafts")) {
                    do { for draft in FixtureService.sampleDrafts(account: app.account) { try app.draftStore.save(draft) }; app.draftsRevision += 1; app.toast(DevText("Sample drafts added to Me › Drafts.")) }
                    catch { app.banner = error.localizedDescription }
                }
            } footer: { Text(DevText("Adds the mockup’s reply, new-discussion and photo-not-included drafts for this account.")) }
        }.navigationTitle(DevText("Fixture scenarios"))
    }
}
