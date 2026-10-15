import SwiftUI

/// Device-local feed presentation. Both appearances render the same topics, order, pins and destinations.
enum FeedAppearance: String, CaseIterable, Identifiable {
    case compact, cards
    static let storageKey = "feedAppearance"
    var id: String { rawValue }
    var title: String { self == .compact ? L("feed.appearance.compact") : L("feed.appearance.cards") }
    var symbol: String { self == .compact ? "list.bullet" : "rectangle.grid.1x2" }
}

/// Reply count for feed metadata. Zero is shown, not omitted.
func feedRepliesText(_ count: Int) -> String { count == 0 ? L("discussion.no_replies_yet") : repliesText(count) }

/// Topic activity (`bumped_at`) labelled as activity, never as creation age.
enum ActiveAge {
    static func text(_ activity: AgeValue) -> String? {
        switch activity {
        case .none: nil
        case .now: L("topic.active.now")
        default: L("topic.active.ago", ["age": activity.compact])
        }
    }
    /// Full words for VoiceOver ("active 3 hours ago"); compact units are not reliably spoken.
    static func spoken(_ activity: AgeValue) -> String? {
        switch activity {
        case .none: nil
        case .now: L("topic.active.spoken.now")
        case let .minutes(n): L("topic.active.spoken.minutes", count: n)
        case let .hours(n): L("topic.active.spoken.hours", count: n)
        case let .days(n): L("topic.active.spoken.days", count: n)
        }
    }
}

/// One topic in a feed. Title, excerpt, media and metadata form a single Discussion target;
/// the category label is a sibling button. Optional fields are omitted when absent or failed.
struct TopicCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    let topic: DiscussionSummary
    var appearance: FeedAppearance = .compact
    var showCategory = true
    /// The feed's explicit-refresh counter; a refresh retries media that failed for the same source.
    var refreshGeneration = 0
    var onOpen: () -> Void
    var onCategory: (CategoryID) -> Void
    /// Media load attempts for this card: which source failed and which attempt is current.
    @State private var mediaState = MediaLoadState()
    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 72

    private var stacked: Bool { typeSize.isAccessibilitySize }
    private var category: Community? { app.category(topic.categoryID) }
    private var source: TopicMedia.Source? {
        if let url = topic.imageURL { return .remote(url) }
        // Bundled photos exist only in the fixture service; the live adapter never sets them.
        if app.fixture != nil, let name = topic.image { return .asset(name) }
        return nil
    }
    private var media: TopicMedia.Source? {
        guard let source, !mediaState.isHidden(source) else { return nil }
        return source
    }
    private var failed: Binding<Bool> {
        Binding(get: { media == nil && source != nil },
                set: { if $0, let source { mediaState.fail(source, generation: refreshGeneration) } })
    }

    var body: some View {
        let _ = app.siteTheme
        let content = VStack(alignment: .leading, spacing: 6) {
            header
            Button(action: onOpen) { mainLabel }
                .buttonStyle(TopicPressStyle())
                .accessibilityLabel(accessibilityText)
                .accessibilityHint(L("topic.open_hint"))
                .accessibilityIdentifier("topic-\(topic.id.rawValue)")
        }
        // An explicit refresh is the only retry trigger, so failed media never retries in a loop.
        .onChange(of: refreshGeneration) { _, generation in mediaState.refreshed(to: generation, current: source) }
        switch appearance {
        case .compact:
            VStack(alignment: .leading, spacing: 0) {
                content.padding(.horizontal, 20).padding(.vertical, 14)
                Rectangle().fill(Color.fomioSeparator).frame(height: 1 / 3).padding(.leading, 20).accessibilityHidden(true)
            }
        case .cards:
            content.padding(16)
                .background(Color.fomioFill, in: .rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.fomioSeparator.opacity(0.45), lineWidth: 0.5) }
                .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    @ViewBuilder private var header: some View {
        let label = showCategory ? category : nil
        if label != nil || topic.pinned {
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            layout {
                if let label { TopicCategoryLabel(category: label, parent: label.parentID.flatMap(app.category)) { onCategory(label.id) } }
                if !stacked { Spacer(minLength: 0) }
                if topic.pinned {
                    Label(L("topic.pinned"), systemImage: "pin.fill").labelStyle(CompactIconLabel())
                        .font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioAccent).accessibilityHidden(true)
                }
            }
        }
    }

    private var mainLabel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let media, appearance == .compact, !stacked {
                HStack(alignment: .top, spacing: 14) {
                    texts
                    TopicMedia(source: media, style: .thumbnail(thumbnailSize), failed: failed).id(mediaState.identity(media))
                }
            } else {
                texts
                if let media { TopicMedia(source: media, style: .wide, failed: failed).id(mediaState.identity(media)) }
            }
            TopicMetadata(author: topic.author, replyCount: topic.replyCount, activity: topic.activity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.title).font(.body.weight(.bold)).foregroundStyle(Color.fomioText)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, topic.title.naturalDirection)
            if !excerpt.isEmpty {
                Text(excerpt).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                    .lineLimit(stacked ? 4 : 2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, excerpt.naturalDirection)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Discourse excerpts keep source line breaks; a preview reads as one paragraph.
    private var excerpt: String {
        topic.excerpt.replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accessibilityText: String {
        var parts = [topic.title]
        if topic.pinned { parts.append(L("topic.pinned")) }
        if let category {
            parts.append(category.parentID.flatMap(app.category).map { L("topic.a11y.in_child", ["community": category.name, "parent": $0.name]) } ?? L("topic.a11y.in", ["community": category.name]))
        }
        if !topic.author.isEmpty { parts.append(L("topic.a11y.started_by", ["name": topic.author])) }
        parts.append(feedRepliesText(topic.replyCount))
        if let active = ActiveAge.spoken(topic.activity) { parts.append(active) }
        if case let .asset(name)? = media { parts.append(L("topic.a11y.photo", ["description": SamplePhoto.description(name)])) }
        else if media != nil { parts.append(L("topic.a11y.has_image")) }
        return parts.joined(separator: L("common.list_separator"))
    }
}

/// Actual Discourse category identity with optional parent context. A separate target from the topic.
struct TopicCategoryLabel: View {
    let category: Community
    var parent: Community?
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                CategoryMark(category: category, size: 20)
                Group {
                    if let parent {
                        // The chevron follows the interface direction; each name keeps its own script direction.
                        LText("topic.category_path", ["parent": parent.name, "community": category.name]) { name, text in name == "parent" ? text.foregroundStyle(Color.fomioSecondaryText) : text }
                    } else { Text(category.name) }
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioText).multilineTextAlignment(.leading)
            }
            .frame(minHeight: 44, alignment: .leading).contentShape(.rect)
        }
        .buttonStyle(.plain).padding(.vertical, -10)
        .accessibilityLabel(parent.map { L("community.open_in", ["name": category.name, "parent": $0.name]) } ?? L("community.open", ["name": category.name]))
        .accessibilityIdentifier("topic-category-\(category.id.rawValue)")
    }
}

/// Original author, reply count (including zero) and labelled activity. Reflows to stacked lines.
struct TopicMetadata: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let author: String
    let replyCount: Int
    let activity: AgeValue
    var body: some View {
        let active = ActiveAge.text(activity)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { authorView; if !author.isEmpty { dot }; replies; if let active { dot; Text(active) } }
            VStack(alignment: .leading, spacing: 4) { authorView; HStack(spacing: 6) { replies; if let active { dot; Text(active) } } }
            VStack(alignment: .leading, spacing: 4) { authorView; replies; if let active { Text(active) } }
        }
        .font(.footnote).foregroundStyle(Color.fomioSecondaryText).lineLimit(nil)
    }
    @ViewBuilder private var authorView: some View {
        if !author.isEmpty {
            HStack(spacing: 6) {
                // Decorative initials; omitted at accessibility sizes where the fixed mark cannot scale with the text.
                if !typeSize.isAccessibilitySize { Avatar(name: author, size: 20) }
                LText("topic.started_by", ["name": author]) { _, text in text.fontWeight(.semibold).foregroundStyle(Color.fomioText) }.fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var replies: some View { Label(feedRepliesText(replyCount), systemImage: "bubble.left").labelStyle(CompactIconLabel()) }
    private var dot: some View { Text("·").accessibilityHidden(true) }
}

/// Load attempts for one topic's media. A failed source stays hidden (no automatic retry, so no loop) until
/// a deliberate retry — the next successful explicit refresh — or until the topic has a different source.
/// Only a deliberate retry advances the attempt; success changes nothing, so a recovered image keeps its view
/// identity, and is not requested again, on every later refresh.
struct MediaLoadState: Equatable {
    private(set) var failed: TopicMedia.Source?
    private(set) var failedGeneration = 0
    private(set) var attempt = 0
    private(set) var attemptSource: TopicMedia.Source?
    func isHidden(_ source: TopicMedia.Source) -> Bool { failed == source }
    mutating func fail(_ source: TopicMedia.Source, generation: Int) { failed = source; failedGeneration = generation }
    /// The feed's explicit refresh generation changed. Retries the current source only if it is presently failed.
    mutating func refreshed(to generation: Int, current: TopicMedia.Source?) {
        guard let failed, failed == current, generation > failedGeneration else { return }
        self.failed = nil; attempt += 1; attemptSource = failed
    }
    /// View identity of the current load attempt.
    func identity(_ source: TopicMedia.Source?) -> String {
        let base = switch source { case let .remote(url)?: url.absoluteString; case let .asset(name)?: "asset:" + name; case nil: "none" }
        return attemptSource == source && source != nil ? base + "#attempt-\(attempt)" : base
    }
}

/// Optional topic media. Loading shows a quiet placeholder; failure removes the slot so the card falls back to text.
struct TopicMedia: View {
    enum Source: Equatable { case asset(String), remote(URL) }
    enum Style { case thumbnail(CGFloat), wide }
    let source: Source
    let style: Style
    @Binding var failed: Bool
    var body: some View {
        switch source {
        case let .asset(name): framed(Image(name).resizable().scaledToFill())
        case let .remote(url):
            AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                switch phase {
                case let .success(image): framed(image.resizable().scaledToFill())
                case .failure: Color.clear.frame(width: 0, height: 0).onAppear { failed = true }
                default: framed(Color.fomioFill).accessibilityLabel(L("media.loading_image"))
                }
            }
        }
    }
    @ViewBuilder private func framed(_ content: some View) -> some View {
        switch style {
        case let .thumbnail(size):
            let side = min(size, 112)
            content.frame(width: side, height: side).clipShape(.rect(cornerRadius: 12)).accessibilityHidden(true)
        case .wide:
            Color.clear.aspectRatio(16 / 9, contentMode: .fit).frame(maxWidth: .infinity)
                .overlay { content }.clipShape(.rect(cornerRadius: 14)).accessibilityHidden(true)
        }
    }
}

extension String {
    /// Community text keeps its own reading direction (like HTML `dir="auto"`), independent of the app language.
    var naturalDirection: LayoutDirection {
        for scalar in unicodeScalars where scalar.properties.isAlphabetic {
            let value = scalar.value
            return (0x0590...0x08FF).contains(value) || (0xFB1D...0xFDFF).contains(value) || (0xFE70...0xFEFF).contains(value) ? .rightToLeft : .leftToRight
        }
        return .leftToRight
    }
}

private struct TopicPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
