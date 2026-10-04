import SwiftUI
import Observation

@MainActor @Observable final class FeedState {
    var items: [DiscussionSummary] = []
    var nextPage: Int? = 0
    var loading = false
    var loaded = false
    var error: String?
    var anchor: TopicID?
    func load(service: any CommunityService, category: Community?, refresh: Bool = false) async {
        guard !loading, refresh || nextPage != nil else { return }
        loading = true; defer { loading = false }
        do {
            let page = try await service.feed(category: category, page: refresh ? 0 : nextPage ?? 0)
            items = refresh ? page.items : items + page.items.filter { item in !items.contains { $0.id == item.id } }
            nextPage = page.nextPage; error = nil; loaded = true
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
func repliesText(_ count: Int) -> String { count == 1 ? "1 reply" : "\(count) replies" }

struct FeedView: View {
    @Environment(AppState.self) private var app
    @Bindable var state: FeedState
    let category: Community?
    var body: some View {
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PendingNoticeSlot()
                    if let category { communityHeader(category) }
                    else { Text("Home").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal, 20).padding(.top, 4) }
                    if category == nil && app.username == nil && !app.guestNoteDismissed { guestNote }
                    SectionLabel(category == nil ? "Latest" : "Latest discussions").padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
                    if state.loading && !state.loaded { SkeletonRows() }
                    ForEach(state.items) { topic in TopicRow(topic: topic, showCategory: category == nil || topic.categoryID != category?.id).id(topic.id) }
                    if state.loading && state.loaded { ProgressView().frame(maxWidth: .infinity).padding(24) }
                    if let error = state.error {
                        InfoCard(title: state.loaded ? "Couldn’t load more" : "Discussions unavailable", message: error) { Button("Try again") { Task { await load() } }.frame(minHeight: 44) }.padding(20)
                    } else if state.loaded && state.items.isEmpty {
                        InfoCard(title: "No discussions yet", message: category.map { "Start the first discussion in \($0.name)." } ?? "Start a discussion in a community you can post to.").padding(20)
                    }
                    if state.nextPage != nil && state.loaded && !state.loading && state.error == nil {
                        Button("More discussions") { Task { await load() } }.frame(maxWidth: .infinity, minHeight: 44).padding()
                    }
                }.padding(.bottom, 20).scrollTargetLayout()
            }
        }
        .scrollPosition(id: $state.anchor)
        .background(Color.fomioBackground)
        .navigationTitle(category?.name ?? "Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if category == nil {
                ToolbarItem(placement: .topBarLeading) { Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.primary).frame(width: 76, height: 28).accessibilityLabel("Fomio") }.sharedBackgroundVisibility(.hidden)
            }
            // The page heading carries the title; the bar stays clear.
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search discussions")
                if category == nil { Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New discussion") }
            }
        }
        .task { if !state.loaded { await load() } }
        .refreshable { await state.load(service: app.service, category: category, refresh: true) }
    }
    private func load() async { await state.load(service: app.service, category: category) }
    private var guestNote: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're reading as a guest. Sign in to reply and save discussions.").font(.subheadline)
                Button("Sign in") { app.requestSignIn() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            Spacer(minLength: 0)
            Button { app.guestNoteDismissed = true } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss guest note")
        }.padding(.leading, 16).padding(.top, 10).background(Color.fomioSelected, in: .rect(cornerRadius: 16)).padding(.horizontal, 20).padding(.top, 8)
    }
    @ViewBuilder private func communityHeader(_ category: Community) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let parent = category.parentID.flatMap(app.category) {
                Button("in \(parent.name)") { app.navigate(.community(parent.id)) }.font(.subheadline.weight(.medium)).frame(minHeight: 44).padding(.vertical, -8)
            }
            HStack(spacing: 12) {
                Monogram(name: category.name, size: 48)
                Text(category.name).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            }
            if !category.description.isEmpty { Text(category.description).foregroundStyle(Color.fomioSecondaryText) }
            if category.canCreate || app.username == nil {
                Button { app.create(category: category.id) } label: { Label("New discussion", systemImage: "square.and.pencil").font(.body.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 6) }
                    .buttonStyle(.glassProminent).accessibilityLabel("New discussion in \(category.name)")
            }
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        let children = app.communities.filter { $0.parentID == category.id }
        if !children.isEmpty {
            SectionLabel("Subcommunities").padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    if index > 0 { Divider().padding(.leading, 16) }
                    Button { app.navigate(.community(child.id)) } label: {
                        HStack { Text(child.name).foregroundStyle(.primary); Spacer(); Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                            .padding(.horizontal, 16).frame(minHeight: 48).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel("\(child.name), in \(category.name)")
                }
            }.background(Color.fomioFill, in: .rect(cornerRadius: 16)).padding(.horizontal, 20)
        }
    }
}
struct TopicRow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    let topic: DiscussionSummary
    var showCategory = true
    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        VStack(alignment: .leading, spacing: 0) {
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    if showCategory {
                        Button(app.categoryName(topic.categoryID)) { app.navigate(.community(topic.categoryID)) }
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent).frame(minHeight: 44, alignment: .leading).padding(.vertical, -10)
                            .accessibilityLabel("Open community \(app.categoryName(topic.categoryID))")
                    }
                    Button(action: open) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            if !topic.excerpt.isEmpty { Text(topic.excerpt).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(stacked ? 4 : 2).multilineTextAlignment(.leading) }
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 5) { metadata }
                                VStack(alignment: .leading, spacing: 2) { metadata }
                            }.font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityIdentifier("topic-\(topic.id.rawValue)")
                    .accessibilityLabel("\(topic.title), in \(app.categoryName(topic.categoryID))\(topic.author.isEmpty ? "" : ", by \(topic.author)"), \(repliesText(topic.replyCount))\(topic.activity.isEmpty ? "" : ", active \(topic.activity)")")
                }
                if let image = topic.image {
                    Button(action: open) {
                        Image(image).resizable().scaledToFill().frame(width: stacked ? nil : 72, height: stacked ? 180 : 72).frame(maxWidth: stacked ? .infinity : 72).clipShape(.rect(cornerRadius: 12))
                    }.buttonStyle(.plain).padding(.top, stacked ? 0 : 22).accessibilityLabel(SamplePhoto.description(image)).accessibilityHidden(true)
                }
            }.padding(.horizontal, 20).padding(.vertical, 14)
            Divider().overlay(Color.fomioSeparator).padding(.leading, 20)
        }
    }
    private func open() { app.navigate(.discussion(topic.id, topic.targetPostNumber)) }
    @ViewBuilder private var metadata: some View {
        if !topic.author.isEmpty { Text(topic.author).lineLimit(1); Text("·").accessibilityHidden(true) }
        Label(repliesText(topic.replyCount), systemImage: "bubble.left").labelStyle(CompactIconLabel())
        if !topic.activity.isEmpty { Text("·").accessibilityHidden(true); Text(topic.activity) }
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
    private struct DirectoryGroup: Identifiable { var root: Community; var kids: [Community]; var visible: [Community]; var more: Int; var canCollapse: Bool; var id: CategoryID { root.id } }
    var body: some View {
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PendingNoticeSlot()
                    if let error = app.communityError { ScreenMessage(title: "Communities unavailable", message: error, action: { Task { await app.loadCommunities() } }) }
                    else if app.communities.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(40).accessibilityLabel("Loading communities") }
                    else {
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
                            Divider().overlay(Color.fomioSeparator).padding(.leading, 20)
                        }
                    }
                }.padding(.bottom, 20)
            }
        }.scrollDismissesKeyboard(.interactively).background(Color.fomioBackground).navigationTitle("Communities")
        .searchable(text: $state.communityQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find communities")
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { searchFocused = false }
        .onDisappear { searchFocused = false }
        .toolbar {
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
            let open = state.expandedCommunities.contains(root.id) || (!query.isEmpty && !selfHit)
            let visible = open ? pool : Array(pool.prefix(2))
            return DirectoryGroup(root: root, kids: pool, visible: visible, more: pool.count - visible.count, canCollapse: query.isEmpty && state.expandedCommunities.contains(root.id) && pool.count > 2)
        }
    }
    private func groupView(_ group: DirectoryGroup) -> some View {
        let root = group.root, indent: CGFloat = typeSize.isAccessibilitySize ? 0 : 56
        return VStack(alignment: .leading, spacing: 10) {
            Button { app.navigate(root.restricted ? .denied(root.id) : .community(root.id)) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Monogram(name: root.name, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { Text(root.name).font(.headline).foregroundStyle(.primary); if root.restricted { restrictedBadge } }
                            VStack(alignment: .leading, spacing: 2) { Text(root.name).font(.headline).foregroundStyle(.primary); if root.restricted { restrictedBadge } }
                        }
                        Text(root.description).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(typeSize.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 12)
                }.contentShape(.rect)
            }.buttonStyle(.plain).accessibilityLabel("\(root.name)\(root.restricted ? ", restricted" : ""). \(root.description)").accessibilityIdentifier("community-\(root.id.rawValue)")
            if !root.restricted, let latest = root.latest {
                Button { app.navigate(.discussion(latest.topicID, nil)) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Latest · \(app.category(latest.categoryID)?.name ?? root.name) · \(latest.activity)").font(.caption).foregroundStyle(Color.fomioSecondaryText)
                        Text(latest.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 12)).contentShape(.rect)
                }.buttonStyle(.plain).padding(.leading, indent).accessibilityLabel("Latest in \(root.name): \(latest.title), active \(latest.activity)")
            }
            if !group.kids.isEmpty {
                FlowLayout {
                    ForEach(group.visible) { child in Chip(title: child.name) { app.navigate(.community(child.id)) }.accessibilityLabel("\(child.name), subcommunity of \(root.name)") }
                    if group.more > 0 { Chip(title: "\(group.more) more") { state.expandedCommunities.insert(root.id) }.accessibilityLabel("Show all \(group.kids.count) subcommunities of \(root.name)") }
                    if group.canCollapse { Chip(title: "Show fewer") { state.expandedCommunities.remove(root.id) } }
                }.padding(.leading, indent)
            }
        }.padding(.horizontal, 20).padding(.vertical, 16)
    }
    private var restrictedBadge: some View { Label("Restricted", systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText).labelStyle(CompactIconLabel()) }
}
