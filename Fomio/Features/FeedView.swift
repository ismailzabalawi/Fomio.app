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
    @State private var showingAbout = false
    var body: some View {
        let _ = app.siteTheme
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PendingNoticeSlot()
                    if let category { communityHeader(category) }
                    else { ScaledTitle("Home", size: 26).padding(.horizontal, 20).padding(.top, 4) }
                    if category == nil && app.username == nil && !app.guestNoteDismissed { guestNote }
                    VStack(alignment: .leading, spacing: 6) {
                        ScaledTitle("Latest", size: 20)
                        if let category, category.parentID == nil, app.communities.contains(where: { $0.parentID == category.id }) {
                            Label("Includes subcommunities", systemImage: "square.stack.3d.up").font(.caption.weight(.medium)).foregroundStyle(Color.fomioSecondaryText)
                        }
                    }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)
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
                ToolbarItem(placement: .topBarLeading) { Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color.fomioText).frame(width: 76, height: 28).accessibilityLabel("Fomio") }.sharedBackgroundVisibility(.hidden)
            }
            // The page heading carries the title; the bar stays clear.
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search discussions")
                if category == nil { Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New discussion") }
            }
        }
        .sheet(isPresented: $showingAbout) {
            if let category { CommunityAboutView(category: category) }
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
        VStack(alignment: .leading, spacing: 10) {
            if let parent = category.parentID.flatMap(app.category) {
                Button { app.navigate(.community(parent.id)) } label: { Label(parent.name, systemImage: "arrow.turn.up.left") }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
            CategoryHeading(category: category)
            if !category.description.isEmpty { Text(category.description).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).fixedSize(horizontal: false, vertical: true) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { headerActions(category) }
                VStack(alignment: .leading, spacing: 8) { headerActions(category) }
            }
            let children = category.parentID == nil ? app.communities.filter { $0.parentID == category.id } : []
            if !children.isEmpty {
                SectionLabel("Subcommunities").padding(.top, 4)
                FlowLayout { ForEach(children) { child in CategoryChip(category: child) } }
            }
        }.padding(20)
        .background(Color.fomioAccent.opacity(0.045))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.fomioSeparator).frame(height: 1) }
    }
    @ViewBuilder private func headerActions(_ category: Community) -> some View {
        Button { showingAbout = true } label: { Label("About", systemImage: "info.circle").font(.subheadline.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 12) }
            .buttonStyle(.glass).accessibilityIdentifier("community-about")
        if category.canCreate || app.username == nil {
            Button { app.create(category: category.id) } label: { Label("New discussion", systemImage: "square.and.pencil").font(.subheadline.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 6) }
                .buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).accessibilityLabel("New discussion in \(category.name)")
        }
    }

}
struct TopicRow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    let topic: DiscussionSummary
    var showCategory = true
    var body: some View {
        let _ = app.siteTheme
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        VStack(alignment: .leading, spacing: 0) {
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    if topic.pinned { Label("Pinned", systemImage: "pin.fill").font(.caption2.weight(.semibold)).foregroundStyle(Color.fomioAccent).padding(.horizontal, 8).padding(.vertical, 3).background(Color.fomioHighlight, in: .capsule) }
                    if showCategory {
                        Button { app.navigate(.community(topic.categoryID)) } label: {
                            HStack(spacing: 5) {
                                if let category = app.category(topic.categoryID) { CategoryMark(category: category, size: 18) }
                                Text(app.categoryName(topic.categoryID))
                            }
                        }
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent).frame(minHeight: 44, alignment: .leading).padding(.vertical, -10)
                            .accessibilityLabel("Open community \(app.categoryName(topic.categoryID))")
                    }
                    Button(action: open) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.title).font(.body.weight(.bold)).foregroundStyle(Color.fomioText).multilineTextAlignment(.leading)
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
        if !topic.author.isEmpty { Avatar(name: topic.author, size: 20); Text(topic.author); Text("·").accessibilityHidden(true) }
        Label(repliesText(topic.replyCount), systemImage: "bubble.left").labelStyle(CompactIconLabel()).padding(.horizontal, 7).padding(.vertical, 3).background(Color.fomioFill, in: .capsule)
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
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
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
                           let url = URL(string: value, relativeTo: base)?.absoluteURL, url.scheme == "https", url.host == base.host {
                            Link("Read the community introduction", destination: url).frame(minHeight: 44)
                        }
                    }.padding(20)
                }
            }.background(Color.fomioBackground).navigationTitle("About").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
