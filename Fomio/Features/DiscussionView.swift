import SwiftUI

struct DiscussionView: View {
    @Environment(AppState.self) private var app
    @Bindable var state: DiscussionState
    var body: some View {
        let _ = app.siteTheme
        ScrollViewReader { proxy in
            ScrollView {
                ReadingColumn {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if app.isOffline && state.page != nil {
                            LText(lead: "offline.lead", rest: "offline.discussion")
                                .font(.subheadline).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14)).padding(.bottom, 12)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        PendingNoticeSlot().padding(.horizontal, -20).padding(.bottom, 8)
                        if let page = state.page {
                            header(page)
                            if case .discussion(_, .some) = state.route, state.focus != .published {
                                Button(L("discussion.show_all_replies")) { app.navigate(.discussion(state.topicID, nil)) }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44).background(Color.fomioFill, in: .capsule).padding(.bottom, 12)
                            }
                            if let opening = state.opening { PostCard(post: opening, state: state).id(opening.id) }
                            HStack(alignment: .firstTextBaseline) {
                                ScaledTitle(L("discussion.replies_heading"), size: 19)
                                Text(page.summary.replyCount, format: .number).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                                Spacer()
                                if let sort = page.effectiveSort {
                                    Text(sort == "new" ? L("discussion.sort.newest") : sort == "old" ? L("discussion.sort.oldest") : L("discussion.sort.community")).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                                }
                            }.padding(.top, 16).padding(.bottom, 10)
                            ForEach(state.roots, id: \.self) { id in
                                Divider().overlay(Color.fomioSeparator)
                                ThreadBranch(id: id, depth: 0, state: state).padding(.top, 14)
                            }
                            if state.roots.isEmpty { Divider().overlay(Color.fomioSeparator); Text(L("discussion.no_replies")).foregroundStyle(Color.fomioSecondaryText).padding(.vertical, 16) }
                            if page.nextPage != nil {
                                Button(L("discussion.more_replies")) { Task { await state.moreRoots() } }.frame(maxWidth: .infinity, minHeight: 44).disabled(state.loading)
                            }
                        }
                        if state.loading { ProgressView().frame(maxWidth: .infinity).padding().accessibilityLabel(L("discussion.loading")) }
                        if let error = state.error { failure(error.text) }
                    }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24).scrollTargetLayout()
                }
            }.scrollPosition(id: $state.anchor)
            .onChange(of: state.highlight) { _, value in if let value { proxy.scrollTo(value, anchor: .center) } }
            .safeAreaInset(edge: .bottom) {
                if let page = state.page, let opening = state.opening, page.canReply || app.username == nil {
                    let target = state.focus == .notification ? state.highlighted ?? opening : opening
                    ReadingColumn {
                        Button { app.reply(to: target) } label: { Label(L("post.reply"), systemImage: "arrowshape.turn.up.backward").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44) }
                            .buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).accessibilityIdentifier("discussion-reply")
                            .accessibilityLabel(target.number.rawValue > 1 ? L("discussion.reply_to_post", ["name": target.author, "number": String(target.number.rawValue)]) : L("discussion.reply_to_discussion", ["title": page.summary.title]))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                    }
                }
            }
        }.background(Color.fomioBackground).navigationTitle(L("discussion.nav_title")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            if let opening = state.opening {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { save(opening) } label: { Label(opening.bookmarkID == nil ? L("post.save") : L("post.remove_saved"), systemImage: opening.bookmarkID == nil ? "bookmark" : "bookmark.slash") }
                        ShareButton(topic: opening.topicID, number: nil)
                    } label: { Image(systemName: "ellipsis") }.accessibilityLabel(L("discussion.more_actions")).accessibilityIdentifier("discussion-more")
                }
            }
        }
        .task { if state.page == nil { await state.load() } }
        .refreshable { await state.load(refresh: true) }
    }
    private func header(_ page: DiscussionPage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4) {
                if let category = app.category(page.summary.categoryID) {
                    if let parent = category.parentID.flatMap(app.category) { pathLink(parent); Image(systemName: "chevron.forward").font(.caption).foregroundStyle(Color.fomioSecondaryText).frame(minHeight: 44).accessibilityHidden(true) }
                    pathLink(category)
                } else {
                    Button(app.categoryName(page.summary.categoryID)) { app.navigate(.community(page.summary.categoryID)) }.frame(minHeight: 44)
                }
            }
            ScaledTitle(page.summary.title, size: 22).contentDirection(page.summary.title)
            if page.closed { Label(L("discussion.closed"), systemImage: "lock").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
            if page.archived { Label(L("discussion.archived"), systemImage: "archivebox").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
            if state.truncated { Text(L("discussion.context_truncated")).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
        }.padding(.bottom, 16)
    }
    private func pathLink(_ category: Community) -> some View {
        Button { app.navigate(.community(category.id)) } label: {
            HStack(spacing: 5) { CategoryMark(category: category, size: 20); Text(category.name).font(.caption.weight(.semibold)) }.frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel(L("community.open", ["name": category.name]))
    }
    @ViewBuilder private func failure(_ error: String) -> some View {
        if state.page == nil, state.errorKind == .unavailable {
            ScreenMessage(title: L("post.unavailable.title"), message: L("post.unavailable.message"), symbol: "bubble.left.and.exclamationmark.bubble.right", actionTitle: L("common.back")) { app.tabs[app.selectedTab]?.path.removeLast() }
        } else if state.page == nil, state.errorKind == .denied {
            ScreenMessage(title: L("access.denied.title"), message: L("access.denied.discussion_message"), symbol: "lock", actionTitle: L("common.back")) { app.tabs[app.selectedTab]?.path.removeLast() }
        } else {
            ScreenMessage(title: state.page == nil ? L("discussion.unavailable") : L("common.load_more_failed"), message: error, action: { Task { if state.page == nil { await state.load() } else { await state.moreRoots() } } })
        }
    }
    private func save(_ post: Post) {
        guard app.username != nil else { app.requireMember(.save) { Task { await state.load(refresh: true) } }; return }
        Task {
            do { let wasSaved = post.bookmarkID != nil; try await state.act(post.id, bookmark: true); app.toast(wasSaved ? L("post.removed_saved_toast") : L("post.saved_toast")) }
            catch { app.banner = error.localizedDescription }
        }
    }
}
struct ShareButton: View {
    @Environment(AppState.self) private var app
    let topic: TopicID
    let number: PostNumber?
    var body: some View {
        let _ = app.siteTheme
        if let url = app.configuration?.topicURL(topic, number: number) { ShareLink(item: url) { Label(L("post.share"), systemImage: "square.and.arrow.up") } }
        else { Button { app.toast(L("post.share_unconfigured")) } label: { Label(L("post.share"), systemImage: "square.and.arrow.up") } }
    }
}
struct ThreadBranch: View {
    @Environment(AppState.self) private var app
    let id: PostID
    let depth: Int
    let state: DiscussionState
    var body: some View {
        let _ = app.siteTheme
        if let post = state.nodes[id] {
            VStack(alignment: .leading, spacing: 8) {
                PostCard(post: post, state: state)
                if post.childCount > 0 {
                    if depth >= 2 {
                        Button(L("discussion.continue_thread")) { app.navigate(.thread(post.topicID, post.number)) }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else {
                        Button { Task { await state.toggle(id, depth: depth) } } label: {
                            Label(state.expanded.contains(id) ? L("discussion.hide_replies") : repliesText(post.childCount), systemImage: state.expanded.contains(id) ? "chevron.up" : "chevron.down").font(.subheadline.weight(.semibold))
                        }.frame(minHeight: 44).accessibilityIdentifier("branch-\(post.number.rawValue)")
                        if state.expanded.contains(id) {
                            ForEach(state.children[id, default: []], id: \.self) { child in
                                ThreadBranch(id: child, depth: depth + 1, state: state).padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(Color.fomioSeparator).frame(width: 2) }
                            }
                            if state.loadingChildren.contains(id) { ProgressView() }
                            if let error = state.childErrors[id] { Text(error.text).font(.subheadline).foregroundStyle(Color.fomioSecondaryText); Button(L("discussion.retry_replies")) { Task { await state.loadChildren(id, depth: depth, first: !state.childrenLoaded.contains(id)) } }.frame(minHeight: 44) }
                            else if state.childNext[id] != nil { Button(L("discussion.more_branch_replies")) { Task { await state.loadChildren(id, depth: depth) } }.frame(minHeight: 44) }
                        }
                    }
                }
            }.id(post.id)
        }
    }
}
struct PostCard: View {
    @Environment(AppState.self) private var app
    let post: Post
    let state: DiscussionState
    private var highlighted: Bool { state.highlight == post.id }
    private var own: Bool { app.username != nil && post.author == app.username }
    var body: some View {
        let _ = app.siteTheme
        VStack(alignment: .leading, spacing: 10) {
            if highlighted, let focus = state.focus { FocusTag(text: focus.label) }
            HStack(alignment: .center, spacing: 10) {
                Button { app.navigate(.profile(post.author)) } label: {
                    HStack(spacing: 10) {
                        Avatar(name: post.authorName ?? post.author, size: post.number.rawValue == 1 ? 40 : 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(post.authorName ?? (post.author.isEmpty ? L("post.member_fallback") : post.author)).font(.subheadline.weight(.bold)).foregroundStyle(Color.fomioText)
                            if !post.age.isEmpty { Text(post.number.rawValue == 1 ? L("post.started_discussion", ["age": post.age.compact]) : post.age.compact).font(.caption).foregroundStyle(Color.fomioSecondaryText) }
                        }
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel(L("post.view_profile", ["name": post.author]))
                Spacer()
                Text(L("post.number", ["number": String(post.number.rawValue)])).font(.caption).foregroundStyle(Color.fomioSecondaryText)
            }
            if post.deleted || post.ignored { Text(post.deleted ? L("post.deleted") : L("post.hidden")).foregroundStyle(Color.fomioSecondaryText) }
            else {
                if let quote = post.quote { QuoteBlock(quote: quote) }
                if let cooked = post.cooked { CookedContent(html: cooked, topic: post.topicID, number: post.number, textStyle: post.number.rawValue == 1 ? .body : .callout) }
                else { Text(.init(post.body)).font(post.number.rawValue == 1 ? .body : .callout).textSelection(.enabled).contentDirection(post.body) }
                if let image = post.image { SamplePhoto(name: image) }
                FlowLayout(spacing: 10) { actions }
            }
        }.padding(highlighted ? 12 : 0)
        .background(highlighted ? Color.fomioSelected : Color.clear, in: .rect(cornerRadius: 14))
        .overlay { if highlighted { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.fomioAccent.opacity(0.4), lineWidth: 1.5).accessibilityHidden(true) } }
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain).accessibilityLabel(post.number.rawValue == 1 ? L("post.a11y.opening", ["name": post.author]) : L("post.a11y.reply", ["number": String(post.number.rawValue), "name": post.author]))
        .contextMenu {
            if !post.deleted {
                Button { save() } label: { Label(post.bookmarkID == nil ? L("post.save_post") : L("post.remove_saved"), systemImage: post.bookmarkID == nil ? "bookmark" : "bookmark.slash") }
                ShareButton(topic: post.topicID, number: post.number)
            }
        }
    }
    @ViewBuilder private var actions: some View {
        if own {
            if post.likeCount > 0 { Label(L("post.likes", count: post.likeCount), systemImage: "heart").labelStyle(CompactIconLabel()).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).frame(minHeight: 44) }
        } else if post.canLike || app.username == nil || post.liked {
            Button { like() } label: {
                Label(post.likeCount > 0 ? L("post.like_count", count: post.likeCount) : L("post.like"), systemImage: post.liked ? "heart.fill" : "heart").labelStyle(CompactIconLabel())
                    .foregroundStyle(post.liked ? Color.fomioLove : Color.fomioSecondaryText)
                    .padding(.horizontal, 12).frame(minHeight: 44).background(Color.fomioFill, in: .capsule)
            }.font(.subheadline.weight(.medium)).frame(minWidth: 44, minHeight: 44).buttonStyle(.plain)
            .accessibilityLabel(post.liked ? L("post.a11y.unlike", count: post.likeCount, ["name": post.author]) : L("post.a11y.like", count: post.likeCount, ["name": post.author])).accessibilityAddTraits(post.liked ? .isSelected : [])
        }
        Button { save() } label: {
            Label(post.bookmarkID == nil ? L("post.save") : L("post.saved"), systemImage: post.bookmarkID == nil ? "bookmark" : "bookmark.fill").labelStyle(CompactIconLabel())
                .font(.subheadline.weight(.medium)).padding(.horizontal, 12).frame(minHeight: 44).background(Color.fomioFill, in: .capsule)
        }.buttonStyle(.plain).accessibilityLabel(post.bookmarkID == nil ? L("post.a11y.save", ["name": post.author]) : L("post.a11y.remove_saved", ["name": post.author]))
        if post.canReply || app.username == nil {
            if post.number.rawValue > 1 {
                Button { app.reply(to: post) } label: { Label(L("post.reply"), systemImage: "arrowshape.turn.up.backward").labelStyle(CompactIconLabel()).frame(minHeight: 44) }
                    .font(.subheadline.weight(.medium)).buttonStyle(.plain).accessibilityLabel(L("post.a11y.reply_to", ["name": post.author, "number": String(post.number.rawValue)]))
            }
            Button { app.reply(to: post, quote: true) } label: { Label(L("post.quote"), systemImage: "quote.opening").labelStyle(CompactIconLabel()).foregroundStyle(Color.fomioSecondaryText).frame(minHeight: 44) }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44).buttonStyle(.plain).accessibilityLabel(L("post.a11y.quote", ["name": post.author]))
        }
    }
    private func like() {
        guard app.username != nil else {
            app.requireMember(.like) { Task { await state.load(refresh: true) } }
            return
        }
        Task { do { try await state.act(post.id, bookmark: false) } catch { app.banner = error.localizedDescription } }
    }
    private func save() {
        guard app.username != nil else { app.requireMember(.save) { Task { await state.load(refresh: true) } }; return }
        Task {
            do { let wasSaved = post.bookmarkID != nil; try await state.act(post.id, bookmark: true); app.toast(wasSaved ? L("post.removed_saved_toast") : L("post.saved_toast")) }
            catch { app.banner = error.localizedDescription }
        }
    }
}
struct QuoteBlock: View {
    let quote: QuoteExcerpt
    var lineLimit: Int? = 4
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("quote.attribution", ["name": quote.author, "number": String(quote.number.rawValue)])).font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
            Text(quote.text).font(.subheadline).lineLimit(lineLimit).contentDirection(quote.text)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fomioHighlight, in: .rect(cornerRadius: 16))
        .overlay(alignment: .leading) { Capsule().fill(Color.fomioAccent).frame(width: 3).padding(.vertical, 8) }
        .accessibilityElement(children: .combine).accessibilityLabel(L("quote.a11y", ["name": quote.author, "number": String(quote.number.rawValue), "text": quote.text]))
    }
}
