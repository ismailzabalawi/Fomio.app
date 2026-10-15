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
func repliesText(_ count: Int) -> String { L("discussion.replies", count: count) }

struct FeedView: View {
    @Environment(AppState.self) private var app
    @Bindable var state: FeedState
    let category: Community?
    @State private var showingAbout = false
    @AppStorage(FeedAppearance.storageKey) private var appearance: FeedAppearance = .compact
    @State private var geometry = FeedGeometry()
    @State private var pendingRestore: FeedGeometry.Anchor?
    var body: some View {
        let _ = app.siteTheme
        ScrollViewReader { proxy in
        ScrollView {
            ReadingColumn {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PendingNoticeSlot()
                    if let category { communityHeader(category) }
                    else { ScaledTitle(L("tab.home"), size: 26).padding(.horizontal, 20).padding(.top, 4) }
                    if category == nil && app.username == nil && !app.guestNoteDismissed { guestNote }
                    VStack(alignment: .leading, spacing: 6) {
                        ScaledTitle(L("feed.latest"), size: 20)
                        if let category, category.parentID == nil, app.communities.contains(where: { $0.parentID == category.id }) {
                            Label(L("feed.includes_subcommunities"), systemImage: "square.stack.3d.up").font(.caption.weight(.medium)).foregroundStyle(Color.fomioSecondaryText)
                        }
                    }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)
                    if state.loading && !state.loaded { SkeletonRows() }
                    if appearance == .cards && !state.items.isEmpty { Color.clear.frame(height: 6).accessibilityHidden(true) }
                    ForEach(state.items) { topic in
                        TopicCard(topic: topic, appearance: appearance, showCategory: category == nil || topic.categoryID != category?.id,
                                  onOpen: { app.navigate(.discussion(topic.id, topic.targetPostNumber)) },
                                  onCategory: { app.navigate(.community($0)) })
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView) } action: { geometry.frames[topic.id] = $0 }
                            .id(topic.id)
                    }
                    if state.loading && state.loaded { ProgressView().frame(maxWidth: .infinity).padding(24) }
                    if let error = state.error {
                        InfoCard(title: state.loaded ? L("common.load_more_failed") : L("feed.unavailable"), message: error) { Button(L("common.try_again")) { Task { await load() } }.frame(minHeight: 44) }.padding(20)
                    } else if state.loaded && state.items.isEmpty {
                        InfoCard(title: L("feed.empty.title"), message: category.map { L("feed.empty.community_message", ["community": $0.name]) } ?? L("feed.empty.home_message")).padding(20)
                    }
                    if state.nextPage != nil && state.loaded && !state.loading && state.error == nil {
                        Button(L("feed.more")) { Task { await load() } }.frame(maxWidth: .infinity, minHeight: 44).padding()
                    }
                }.padding(.bottom, 20).scrollTargetLayout()
            }
        }
        .scrollPosition(id: $state.anchor)
        .accessibilityIdentifier("feed-\(appearance.rawValue)")
        // Card frames are read in the scroll view's space, whose origin is the inset-adjusted visible top.
        .onScrollGeometryChange(for: FeedGeometry.Viewport.self) { .init(top: 0, height: $0.containerSize.height) } action: { geometry.viewport = $1 }
        .onChange(of: appearance) { restore(proxy) }
        }
        .background(Color.fomioBackground)
        .navigationTitle(category?.name ?? L("tab.home"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if category == nil {
                ToolbarItem(placement: .topBarLeading) { Image("wordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color.fomioText).frame(width: 76, height: 28).accessibilityLabel(L("app.name")) }.sharedBackgroundVisibility(.hidden)
            }
            // The page heading carries the title; the bar stays clear.
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel(L("search.discussions"))
                if category == nil { Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel(L("composer.new_discussion")) }
                optionsMenu
            }
        }
        .sheet(isPresented: $showingAbout) {
            if let category { CommunityAboutView(category: category) }
        }
        .task { if !state.loaded { await load() } }
        .refreshable { await state.load(service: app.service, category: category, refresh: true) }
    }
    private func load() async { await state.load(service: app.service, category: category) }
    private var optionsMenu: some View {
        Menu {
            Section(L("feed.appearance")) {
                Picker(selection: Binding(get: { appearance }, set: select)) {
                    ForEach(FeedAppearance.allCases) { option in Label(option.title, systemImage: option.symbol).tag(option) }
                } label: { Text(L("feed.appearance")) }
                .pickerStyle(.inline)
            }
        } label: {
            // Titled so the item stays named when the toolbar overflows (iPad, accessibility text sizes).
            Label(category == nil ? L("feed.options.home") : L("feed.options.community"), systemImage: "ellipsis")
        }
        .accessibilityIdentifier("feed-options")
    }
    /// Captures the topmost visible topic and how far into it the reader is, before row heights change.
    private func select(_ value: FeedAppearance) {
        guard value != appearance else { return }
        pendingRestore = geometry.topAnchor(in: state.items)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { appearance = value }
    }
    /// Keeps the same topic at the same relative reading position after the switch. No animated scrolling.
    private func restore(_ proxy: ScrollViewProxy) {
        // Another feed may change the shared preference; this feed then restores its own last-known reading position.
        guard let anchor = pendingRestore ?? geometry.topAnchor(in: state.items) else { return }
        pendingRestore = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(anchor.id, anchor: .top) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            let next = state.items.firstIndex { $0.id == anchor.id }.flatMap { state.items.indices.contains($0 + 1) ? state.items[$0 + 1].id : nil }
            if let (id, point) = geometry.placement(for: anchor, next: next) { withTransaction(transaction) { proxy.scrollTo(id, anchor: point) } }
        }
    }
    private var guestNote: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("feed.guest_note")).font(.subheadline)
                Button(L("auth.sign_in")) { app.requestSignIn() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            Spacer(minLength: 0)
            Button { app.guestNoteDismissed = true } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel(L("feed.guest_note.dismiss"))
        }.padding(.leading, 16).padding(.top, 10).background(Color.fomioSelected, in: .rect(cornerRadius: 16)).padding(.horizontal, 20).padding(.top, 8)
    }
    @ViewBuilder private func communityHeader(_ category: Community) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let parent = category.parentID.flatMap(app.category) {
                Button { app.navigate(.community(parent.id)) } label: { Label { Text(parent.name) } icon: { Image(systemName: "arrow.turn.up.left").flipsForRightToLeftLayoutDirection(true) } }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
            CategoryHeading(category: category)
            if !category.description.isEmpty { Text(category.description).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).fixedSize(horizontal: false, vertical: true).contentDirection(category.description) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { headerActions(category) }
                VStack(alignment: .leading, spacing: 8) { headerActions(category) }
            }
            let children = category.parentID == nil ? app.communities.filter { $0.parentID == category.id } : []
            if !children.isEmpty {
                SectionLabel(L("community.subcommunities")).padding(.top, 4)
                FlowLayout { ForEach(children) { child in CategoryChip(category: child) } }
            }
        }.padding(20)
        .background(Color.fomioAccent.opacity(0.045))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.fomioSeparator).frame(height: 1) }
    }
    @ViewBuilder private func headerActions(_ category: Community) -> some View {
        Button { showingAbout = true } label: { Label(L("community.about"), systemImage: "info.circle").font(.subheadline.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 12) }
            .buttonStyle(.glass).accessibilityIdentifier("community-about")
        if category.canCreate || app.username == nil {
            Button { app.create(category: category.id) } label: { Label(L("composer.new_discussion"), systemImage: "square.and.pencil").font(.subheadline.weight(.semibold)).frame(minHeight: 44).padding(.horizontal, 6) }
                .buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).accessibilityLabel(L("composer.new_discussion_in", ["community": category.name]))
        }
    }

}
/// Non-observed layout readings used only when the appearance changes; updating them never re-renders the feed.
@MainActor final class FeedGeometry {
    struct Viewport: Equatable { var top: CGFloat = 0; var height: CGFloat = 0 }
    struct Anchor: Equatable { var id: TopicID; var offset: CGFloat; var height: CGFloat }
    var frames: [TopicID: CGRect] = [:]
    var viewport = Viewport()
    /// The first topic whose bottom is below the visible top, with its offset from that top.
    func topAnchor(in items: [DiscussionSummary]) -> Anchor? {
        let current = Set(items.map(\.id))
        frames = frames.filter { current.contains($0.key) }
        let visible = frames.filter { $0.value.maxY > viewport.top + 1 && $0.value.minY < viewport.top + viewport.height }
        guard let (id, frame) = visible.min(by: { $0.value.minY < $1.value.minY }) else { return nil }
        return Anchor(id: id, offset: frame.minY - viewport.top, height: max(frame.height, 1))
    }
    /// Called after the topic was scrolled to the top in the new appearance. Returns a scroll target that keeps
    /// the same fraction of the topic above the visible top, or the same distance below it when it was fully visible.
    /// Scroll anchors are clamped to 0...1, so a partly hidden topic is placed by positioning the topic after it.
    func placement(for anchor: Anchor, next: TopicID?) -> (TopicID, UnitPoint)? {
        guard let frame = frames[anchor.id], viewport.height > 0 else { return nil }
        let target = anchor.offset < 0 ? anchor.offset * frame.height / anchor.height : min(anchor.offset, viewport.height * 0.6)
        guard abs(target) > 0.5 else { return nil }
        let reference = target < 0 ? next : anchor.id
        guard let reference, let referenceFrame = frames[reference] else { return nil }
        let desired = target + referenceFrame.minY - frame.minY
        let span = viewport.height - referenceFrame.height
        guard abs(span) > 1 else { return nil }
        let value = desired / span
        guard (0...1).contains(value) else { return nil }
        return (reference, UnitPoint(x: 0, y: value))
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
                    ScaledTitle(L("tab.communities"), size: 26).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 14)
                    if let error = app.communityError, app.communities.isEmpty { ScreenMessage(title: L("communities.unavailable"), message: error, action: { Task { await app.loadCommunities() } }) }
                    else if app.communities.isEmpty && app.communitiesLoaded { InfoCard(title: L("communities.empty.title"), message: L("communities.empty.message")).padding(20) }
                    else if app.communities.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(40).accessibilityLabel(L("communities.loading")) }
                    else {
                        if let error = app.communityError {
                            InfoCard(title: L("communities.refresh_failed"), message: error) { Button(L("common.try_again")) { Task { await app.loadCommunities() } }.frame(minHeight: 44) }.padding(20)
                        }
                        let groups = self.groups
                        if !query.isEmpty && !groups.isEmpty {
                            Text(L("communities.filter.matches", count: groups.count, ["query": query]))
                                .font(.footnote).foregroundStyle(Color.fomioSecondaryText).padding(.horizontal, 20).padding(.top, 8).accessibilityAddTraits(.updatesFrequently)
                        }
                        if !query.isEmpty && groups.isEmpty {
                            InfoCard(title: L("communities.filter.none", ["query": query]), message: L("communities.filter.scope")) {
                                Button(L("communities.filter.search_discussions", ["query": query])) { app.search(query) }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                            }.padding(20)
                        }
                        ForEach(groups) { group in
                            groupView(group)

                        }
                    }
                }.padding(.bottom, 20)
            }
        }.scrollDismissesKeyboard(.interactively).background(Color.fomioBackground).navigationTitle(L("tab.communities")).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $state.communityQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(L("communities.find")))
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { searchFocused = false }
        .onDisappear { searchFocused = false }
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { app.navigate(.search) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel(L("search.discussions"))
                Button { app.create() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel(L("composer.new_discussion"))
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
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading).contentDirection(root.descriptionExcerpt ?? root.description)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel(root.restricted ? L("communities.row.restricted", ["name": root.name, "description": root.description]) : L("communities.row", ["name": root.name, "description": root.description])).accessibilityIdentifier("community-\(root.id.rawValue)")
                if !group.kids.isEmpty && query.isEmpty {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            if state.expandedCommunities.contains(root.id) { state.expandedCommunities.remove(root.id) }
                            else { state.expandedCommunities.insert(root.id) }
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold))
                            .foregroundStyle(Color.fomioText).frame(width: 44, height: 44).background(color.opacity(0.16), in: .rect(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityLabel(expanded ? L("communities.hide_children", ["name": root.name]) : L("communities.show_children", ["name": root.name])).accessibilityIdentifier("category-expand-\(root.id.rawValue)")
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
                                Image(systemName: "chevron.forward").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
                            }.frame(minHeight: 44).padding(.vertical, 3).contentShape(.rect)
                        }.buttonStyle(.plain).accessibilityLabel(L("communities.child_row", ["name": child.name, "parent": root.name])).accessibilityIdentifier("community-\(child.id.rawValue)")
                    }
                }.padding(.leading, typeSize.isAccessibilitySize ? 0 : 24).padding(.top, 8)
                .overlay(alignment: .leading) { if !typeSize.isAccessibilitySize { Capsule().fill(color.opacity(0.2)).frame(width: 2).padding(.leading, 20).padding(.vertical, 14).accessibilityHidden(true) } }
            }
        }.padding(14).background(expanded ? color.opacity(0.055) : Color.clear, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 20).padding(.bottom, 8)
    }
    private var restrictedBadge: some View { Label(L("communities.restricted"), systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText).labelStyle(CompactIconLabel()) }
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
                        Text(category.description.isEmpty ? L("community.about.no_description") : category.description).textSelection(.enabled).contentDirection(category.description.isEmpty ? L("community.about.no_description") : category.description)
                        if let value = category.aboutURL, let base = app.configuration?.baseURL,
                           let url = URL(string: value, relativeTo: base)?.absoluteURL, url.scheme == "https", url.host == base.host {
                            Link(L("community.about.introduction"), destination: url).frame(minHeight: 44)
                        }
                    }.padding(20)
                }
            }.background(Color.fomioBackground).navigationTitle(L("community.about")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("common.done")) { dismiss() } } }
        }
    }
}
