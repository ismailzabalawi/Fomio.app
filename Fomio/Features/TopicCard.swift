import SwiftUI

/// Device-local feed presentation. Both appearances render the same topics, order, pins and destinations.
enum FeedAppearance: String, CaseIterable, Identifiable {
    case compact, cards
    static let storageKey = "feedAppearance"
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .compact ? "Compact" : "Cards" }
    var symbol: String { self == .compact ? "list.bullet" : "rectangle.grid.1x2" }
}

/// Reply count for feed metadata. Zero is shown, not omitted.
func feedRepliesText(_ count: Int) -> String { count == 0 ? "No replies yet" : repliesText(count) }

/// Topic activity (`bumped_at`) labelled as activity, never as creation age.
enum ActiveAge {
    static func text(_ activity: String) -> String? {
        guard !activity.isEmpty else { return nil }
        return activity == "now" ? "Active now" : "Active \(activity) ago"
    }
    static func spoken(_ activity: String) -> String? {
        guard !activity.isEmpty else { return nil }
        if activity == "now" { return "active just now" }
        guard let unit = activity.last, let value = Int(activity.dropLast()) else { return "active \(activity) ago" }
        let name = unit == "m" ? "minute" : unit == "h" ? "hour" : unit == "d" ? "day" : nil
        return name.map { "active \(value) \($0)\(value == 1 ? "" : "s") ago" } ?? "active \(activity) ago"
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
    var onOpen: () -> Void
    var onCategory: (CategoryID) -> Void
    @State private var mediaFailed = false
    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 72

    private var stacked: Bool { typeSize.isAccessibilitySize }
    private var category: Community? { app.category(topic.categoryID) }
    private var media: TopicMedia.Source? {
        if mediaFailed { return nil }
        if let url = topic.imageURL { return .remote(url) }
        // Bundled photos exist only in the fixture service; the live adapter never sets them.
        if app.fixture != nil, let name = topic.image { return .asset(name) }
        return nil
    }

    var body: some View {
        let _ = app.siteTheme
        let content = VStack(alignment: .leading, spacing: 6) {
            header
            Button(action: onOpen) { mainLabel }
                .buttonStyle(TopicPressStyle())
                .accessibilityLabel(accessibilityText)
                .accessibilityHint("Opens the discussion")
                .accessibilityIdentifier("topic-\(topic.id.rawValue)")
        }
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
                    Label("Pinned", systemImage: "pin.fill").labelStyle(CompactIconLabel())
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
                    TopicMedia(source: media, style: .thumbnail(thumbnailSize), failed: $mediaFailed)
                }
            } else {
                texts
                if let media { TopicMedia(source: media, style: .wide, failed: $mediaFailed) }
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
        if topic.pinned { parts.append("Pinned") }
        if let category { parts.append("in \(category.parentID.flatMap(app.category).map { "\(category.name), \($0.name)" } ?? category.name)") }
        if !topic.author.isEmpty { parts.append("started by \(topic.author)") }
        parts.append(feedRepliesText(topic.replyCount))
        if let active = ActiveAge.spoken(topic.activity) { parts.append(active) }
        if case let .asset(name)? = media { parts.append("Photo: \(SamplePhoto.description(name))") }
        else if media != nil { parts.append("Has image") }
        return parts.joined(separator: ", ")
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
                        Text("\(Text(parent.name).foregroundStyle(Color.fomioSecondaryText)) \(parent.name.naturalDirection == .rightToLeft ? "‹" : "›") \(Text(category.name))")
                    } else { Text(category.name) }
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioText).multilineTextAlignment(.leading)
            }
            .frame(minHeight: 44, alignment: .leading).contentShape(.rect)
        }
        .buttonStyle(.plain).padding(.vertical, -10)
        .accessibilityLabel(parent.map { "Open community \(category.name), in \($0.name)" } ?? "Open community \(category.name)")
        .accessibilityIdentifier("topic-category-\(category.id.rawValue)")
    }
}

/// Original author, reply count (including zero) and labelled activity. Reflows to stacked lines.
struct TopicMetadata: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let author: String
    let replyCount: Int
    let activity: String
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
                Text("Started by \(Text(author).fontWeight(.semibold).foregroundStyle(Color.fomioText))").fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var replies: some View { Label(feedRepliesText(replyCount), systemImage: "bubble.left").labelStyle(CompactIconLabel()) }
    private var dot: some View { Text("·").accessibilityHidden(true) }
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
                default: framed(Color.fomioFill).accessibilityLabel("Loading image")
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
