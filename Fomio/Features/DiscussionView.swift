import SwiftUI

struct DiscussionView: View {
    @Environment(AppState.self) private var app
    @Bindable var state: DiscussionState
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ReadingColumn {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if app.isOffline && state.page != nil {
                            Text("\(Text("You're offline.").bold()) Showing what was loaded earlier. Replies can't be sent until you're back online.")
                                .font(.subheadline).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14)).padding(.bottom, 12)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        PendingNoticeSlot().padding(.horizontal, -20).padding(.bottom, 8)
                        if let page = state.page {
                            header(page)
                            if case .discussion(_, .some) = state.route, state.focus != .published {
                                Button("Show all replies") { app.navigate(.discussion(state.topicID, nil)) }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44).background(Color.fomioFill, in: .capsule).padding(.bottom, 12)
                            }
                            if let opening = state.opening { PostCard(post: opening, state: state).id(opening.id) }
                            ForEach(state.roots, id: \.self) { id in
                                Divider().overlay(Color.fomioSeparator)
                                ThreadBranch(id: id, depth: 0, state: state).padding(.top, 14)
                            }
                            if state.roots.isEmpty { Divider().overlay(Color.fomioSeparator); Text("No replies yet.").foregroundStyle(Color.fomioSecondaryText).padding(.vertical, 16) }
                            if page.nextPage != nil {
                                Button("More replies") { Task { await state.moreRoots() } }.frame(maxWidth: .infinity, minHeight: 44).disabled(state.loading)
                            }
                        }
                        if state.loading { ProgressView().frame(maxWidth: .infinity).padding().accessibilityLabel("Loading discussion") }
                        if let error = state.error { failure(error) }
                    }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24).scrollTargetLayout()
                }
            }.scrollPosition(id: $state.anchor)
            .onChange(of: state.highlight) { _, value in if let value { proxy.scrollTo(value, anchor: .center) } }
            .safeAreaInset(edge: .bottom) {
                if let page = state.page, let opening = state.opening, !page.closed, page.canReply || app.username == nil {
                    let target = state.focus == .notification ? state.highlighted ?? opening : opening
                    ReadingColumn {
                        Button { app.reply(to: target) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44) }
                            .buttonStyle(.glassProminent).accessibilityIdentifier("discussion-reply")
                            .accessibilityLabel(target.number.rawValue > 1 ? "Reply to \(target.author) · #\(target.number.rawValue)" : "Reply to \(page.summary.title)")
                            .padding(.horizontal, 20).padding(.vertical, 8)
                    }
                }
            }
        }.background(Color.fomioBackground).navigationTitle("Discussion").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            if let opening = state.opening {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { save(opening) } label: { Label(opening.bookmarkID == nil ? "Save" : "Remove from Saved", systemImage: opening.bookmarkID == nil ? "bookmark" : "bookmark.slash") }
                        ShareButton(topic: opening.topicID, number: nil)
                    } label: { Image(systemName: "ellipsis") }.accessibilityLabel("More actions").accessibilityIdentifier("discussion-more")
                }
            }
        }
        .task { if state.page == nil { await state.load() } }
        .refreshable { await state.load(refresh: true) }
    }
    private func header(_ page: DiscussionPage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(app.categoryName(page.summary.categoryID)) { app.navigate(.community(page.summary.categoryID)) }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent).frame(minHeight: 44).padding(.vertical, -10)
                .accessibilityLabel("Open community \(app.categoryName(page.summary.categoryID))")
            Text(page.summary.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(([page.summary.author.isEmpty ? nil : page.summary.author, repliesText(page.summary.replyCount), page.summary.activity.isEmpty ? nil : "Active \(page.summary.activity)"] as [String?]).compactMap { $0 }.joined(separator: " · "))
                .font(.footnote).foregroundStyle(Color.fomioSecondaryText)
            if page.closed { Label("This discussion is closed", systemImage: "lock").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
            if state.truncated { Text("Earlier thread context is unavailable here.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
        }.padding(.bottom, 16)
    }
    @ViewBuilder private func failure(_ error: String) -> some View {
        if state.page == nil, state.errorKind == .unavailable {
            ScreenMessage(title: "This post isn't available", message: "It may have been deleted, or moved somewhere you can't see.", symbol: "bubble.left.and.exclamationmark.bubble.right", actionTitle: "Back") { app.tabs[app.selectedTab]?.path.removeLast() }
        } else if state.page == nil, state.errorKind == .denied {
            ScreenMessage(title: "You don't have access", message: "This discussion is only open to some members.", symbol: "lock", actionTitle: "Back") { app.tabs[app.selectedTab]?.path.removeLast() }
        } else {
            ScreenMessage(title: state.page == nil ? "Discussion unavailable" : "Couldn’t load more", message: error, action: { Task { if state.page == nil { await state.load() } else { await state.moreRoots() } } })
        }
    }
    private func save(_ post: Post) {
        guard app.username != nil else { app.requireMember(.save) { Task { await state.load(refresh: true) } }; return }
        Task {
            do { let wasSaved = post.bookmarkID != nil; try await state.act(post.id, bookmark: true); app.toast(wasSaved ? "Removed from Saved" : "Saved. Find it in Me › Saved.") }
            catch { app.banner = error.localizedDescription }
        }
    }
}
struct ShareButton: View {
    @Environment(AppState.self) private var app
    let topic: TopicID
    let number: PostNumber?
    var body: some View {
        if let url = app.configuration?.topicURL(topic, number: number) { ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") } }
        else { Button { app.toast("Sharing a community link is available when a live site is configured.") } label: { Label("Share", systemImage: "square.and.arrow.up") } }
    }
}
struct ThreadBranch: View {
    @Environment(AppState.self) private var app
    let id: PostID
    let depth: Int
    let state: DiscussionState
    var body: some View {
        if let post = state.nodes[id] {
            VStack(alignment: .leading, spacing: 8) {
                PostCard(post: post, state: state)
                if post.childCount > 0 {
                    if depth >= 2 {
                        Button("Continue this thread") { app.navigate(.thread(post.topicID, post.number)) }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    } else {
                        Button { Task { await state.toggle(id, depth: depth) } } label: {
                            Label(state.expanded.contains(id) ? "Hide replies" : repliesText(post.childCount), systemImage: state.expanded.contains(id) ? "chevron.up" : "chevron.down").font(.subheadline.weight(.semibold))
                        }.frame(minHeight: 44).accessibilityIdentifier("branch-\(post.number.rawValue)")
                        if state.expanded.contains(id) {
                            ForEach(state.children[id, default: []], id: \.self) { child in
                                ThreadBranch(id: child, depth: depth + 1, state: state).padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(Color.fomioSeparator).frame(width: 2) }
                            }
                            if state.loadingChildren.contains(id) { ProgressView() }
                            if let error = state.childErrors[id] { Text(error).font(.subheadline).foregroundStyle(Color.fomioSecondaryText); Button("Retry replies") { Task { await state.loadChildren(id, depth: depth, first: !state.childrenLoaded.contains(id)) } }.frame(minHeight: 44) }
                            else if state.childNext[id] != nil { Button("More replies in this branch") { Task { await state.loadChildren(id, depth: depth) } }.frame(minHeight: 44) }
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
        VStack(alignment: .leading, spacing: 10) {
            if highlighted, let focus = state.focus { FocusTag(text: focus.label) }
            HStack(alignment: .center, spacing: 10) {
                Button { app.navigate(.profile(post.author)) } label: {
                    HStack(spacing: 10) {
                        Avatar(name: post.authorName ?? post.author)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(post.author.isEmpty ? "Member" : post.author).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            if !post.age.isEmpty { Text(post.age).font(.caption).foregroundStyle(Color.fomioSecondaryText) }
                        }
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel("View profile, \(post.author)")
                Spacer()
                Text("#\(post.number.rawValue)").font(.caption).foregroundStyle(Color.fomioSecondaryText)
            }
            if post.deleted || post.ignored { Text(post.deleted ? "This reply was deleted." : "This reply is hidden.").foregroundStyle(Color.fomioSecondaryText) }
            else {
                if let quote = post.quote { QuoteBlock(quote: quote) }
                if let cooked = post.cooked { CookedContent(html: cooked, topic: post.topicID, number: post.number) }
                else { Text(.init(post.body)).font(.body).textSelection(.enabled) }
                if let image = post.image { SamplePhoto(name: image) }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { actions }
                    VStack(alignment: .leading, spacing: 0) { actions }
                }
            }
        }.padding(highlighted ? 12 : 0)
        .background(highlighted ? Color.fomioSelected : Color.clear, in: .rect(cornerRadius: 14))
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain).accessibilityLabel("\(post.number.rawValue == 1 ? "Opening post" : "Reply \(post.number.rawValue)") by \(post.author)")
        .contextMenu {
            if !post.deleted {
                Button { save() } label: { Label(post.bookmarkID == nil ? "Save post" : "Remove from Saved", systemImage: post.bookmarkID == nil ? "bookmark" : "bookmark.slash") }
                ShareButton(topic: post.topicID, number: post.number)
            }
        }
    }
    @ViewBuilder private var actions: some View {
        if own {
            if post.likeCount > 0 { Label(post.likeCount == 1 ? "1 like" : "\(post.likeCount) likes", systemImage: "heart").labelStyle(CompactIconLabel()).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).frame(minHeight: 44) }
        } else if post.canLike || app.username == nil || post.liked {
            Button { like() } label: {
                Label(post.likeCount > 0 ? "\(post.likeCount)" : "Like", systemImage: post.liked ? "heart.fill" : "heart").labelStyle(CompactIconLabel())
                    .foregroundStyle(post.liked ? Color.fomioLove : Color.fomioSecondaryText)
            }.font(.subheadline.weight(.medium)).frame(minWidth: 44, minHeight: 44).buttonStyle(.plain)
            .accessibilityLabel("\(post.liked ? "Unlike" : "Like") post by \(post.author), \(post.likeCount) likes").accessibilityAddTraits(post.liked ? .isSelected : [])
        }
        if post.canReply || app.username == nil {
            Button { app.reply(to: post, quote: true) } label: { Label("Quote", systemImage: "quote.opening").labelStyle(CompactIconLabel()).foregroundStyle(Color.fomioSecondaryText) }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44).buttonStyle(.plain).accessibilityLabel("Quote \(post.author)’s post")
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
            do { let wasSaved = post.bookmarkID != nil; try await state.act(post.id, bookmark: true); app.toast(wasSaved ? "Removed from Saved" : "Saved. Find it in Me › Saved.") }
            catch { app.banner = error.localizedDescription }
        }
    }
}
struct QuoteBlock: View {
    let quote: QuoteExcerpt
    var lineLimit: Int? = 4
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(quote.author) · #\(quote.number.rawValue)").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
            Text(quote.text).font(.subheadline).lineLimit(lineLimit)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fomioFill, in: .rect(cornerRadius: 12))
        .overlay(alignment: .leading) { Capsule().fill(Color.fomioAccent).frame(width: 3).padding(.vertical, 8) }
        .accessibilityElement(children: .combine).accessibilityLabel("Quote from \(quote.author), post \(quote.number.rawValue): \(quote.text)")
    }
}
