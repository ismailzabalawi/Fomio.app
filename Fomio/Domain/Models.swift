import Foundation

struct EntityID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
    var rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }
    init(_ value: Int) { rawValue = value }
    init(from decoder: any Decoder) throws { rawValue = try decoder.singleValueContainer().decode(Int.self) }
    func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
enum TopicTag: Sendable {}
enum PostTag: Sendable {}
enum CategoryTag: Sendable {}
enum NumberTag: Sendable {}
typealias TopicID = EntityID<TopicTag>
typealias PostID = EntityID<PostTag>
typealias CategoryID = EntityID<CategoryTag>
typealias PostNumber = EntityID<NumberTag>

struct AccountID: RawRepresentable, Hashable, Codable, Sendable {
    var rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    static let fixture = AccountID(rawValue: "fixture:jonah.w")
    static let guest = AccountID(rawValue: "guest")
}
struct Community: Identifiable, Codable, Hashable, Sendable {
    var id: CategoryID
    var name: String
    var slug: String
    var parentID: CategoryID?
    var description: String
    var canCreate: Bool
    /// Shown as a word plus lock in the directory; opening it shows the access-denied state.
    var restricted = false
    /// Latest visible discussion for the directory preview. Nil when the source does not provide it.
    var latest: LatestPreview? = nil
}
struct LatestPreview: Codable, Hashable, Sendable { var topicID: TopicID; var title: String; var categoryID: CategoryID; var activity: String }
struct DiscussionSummary: Identifiable, Codable, Hashable, Sendable {
    var id: TopicID
    var title: String
    var slug: String
    var categoryID: CategoryID
    var excerpt: String
    var author: String
    var replyCount: Int
    var activity: String
    var image: String?
    var targetPostNumber: PostNumber?
    /// Author of the matched post when a search hit is inside the discussion.
    var matchAuthor: String? = nil
}
struct QuoteExcerpt: Codable, Hashable, Sendable { var author: String; var number: PostNumber; var text: String }
struct Post: Identifiable, Codable, Hashable, Sendable {
    var id: PostID
    var number: PostNumber
    var topicID: TopicID
    var parent: PostNumber?
    var author: String
    var body: String
    var cooked: String? = nil
    var image: String? = nil
    var likeCount = 0
    var liked = false
    var bookmarkID: Int? = nil
    var canLike = false
    var canReply = false
    var deleted = false
    var ignored = false
    var childCount = 0
    var age = ""
    var quote: QuoteExcerpt? = nil
    var authorName: String? = nil
}
struct ThreadNode: Identifiable, Hashable, Sendable {
    var post: Post
    var children: [ThreadNode] = []
    var id: PostID { post.id }
}
struct DiscussionPage: Sendable {
    var summary: DiscussionSummary
    var opening: Post
    var roots: [ThreadNode]
    var nextPage: Int?
    var closed = false
    var canReply = false
}
struct ChildPage: Sendable { var nodes: [ThreadNode]; var nextPage: Int? }
struct ThreadContext: Sendable { var page: DiscussionPage; var ancestors: [Post]; var target: ThreadNode; var truncated: Bool }
struct Page<Value: Sendable>: Sendable { var items: [Value]; var nextPage: Int? }
struct Member: Identifiable, Sendable { var username: String; var name: String?; var bio: String; var recent: [DiscussionSummary]; var joined: String? = nil; var id: String { username } }
struct Notice: Identifiable, Sendable {
    enum Kind: Sendable { case reply, mention }
    var id: Int
    var kind: Kind
    var actor: String
    var title: String
    var topicID: TopicID?
    var number: PostNumber?
    var age = ""
    var read: Bool
    var text: String { actor + (kind == .reply ? " replied to you" : " mentioned you") }
}
struct SavedItem: Identifiable, Sendable { var id: Int; var title: String; var topicID: TopicID; var number: PostNumber?; var categoryID: CategoryID? = nil; var postAuthor: String? = nil }

enum ComposerIntent: Codable, Hashable, Sendable {
    case newDiscussion
    case reply(topic: TopicID, parent: PostNumber?)
    var topicID: TopicID? { if case let .reply(topic, _) = self { topic } else { nil } }
    var isNew: Bool { topicID == nil }
}
enum SubmissionState: Codable, Equatable, Sendable { case editing, submitting, pending, unconfirmed }
struct Draft: Identifiable, Codable, Equatable, Sendable {
    var version = 1
    var id = UUID()
    var account: AccountID
    var intent: ComposerIntent
    var title = ""
    var body = ""
    var categoryID: CategoryID?
    var missingPhoto = false
    var uploadedPhoto: UploadedPhoto?
    var submission: SubmissionState = .editing
    var updatedAt = Date()
    var quote: QuoteExcerpt? = nil
    /// Display context captured when the composer opened; Discourse stays authoritative on submit.
    var contextTitle: String? = nil
    var contextCategory: CategoryID? = nil
    var targetAuthor: String? = nil
    /// Raw sent to the community: an attributed quote, when present, precedes the writing.
    var composedBody: String {
        guard let quote, let topic = intent.topicID else { return body }
        return "[quote=\"\(quote.author), post:\(quote.number.rawValue), topic:\(topic.rawValue)\"]\n\(quote.text)\n[/quote]\n\n" + body
    }
}
struct UploadedPhoto: Codable, Equatable, Sendable { var url: String; var shortURL: String; var width: Int?; var height: Int? }
enum PostingOutcome: Sendable { case published(topic: TopicID, number: PostNumber); case pending; case unconfirmed }
enum Reconciliation: Sendable { case published(topic: TopicID, number: PostNumber); case unresolved }
enum RepositoryError: LocalizedError, Equatable {
    case configuration, offline, unauthorized, denied, unavailable, unsupported, invalid(String), rateLimited, server(Int), unconfirmed
    var errorDescription: String? {
        switch self {
        case .configuration: "Live community configuration is unavailable."
        case .offline: "You’re offline. Your writing is kept on this device."
        case .unauthorized: "Sign in again to continue. Your writing is kept."
        case .denied: "You don’t have permission to access this content."
        case .unavailable: "This content is no longer available."
        case .unsupported: "This community does not provide the required nested reply capability."
        case let .invalid(message): message
        case .rateLimited: "Too many requests. Please try again later."
        case let .server(code): "The community could not complete the request (\(code))."
        case .unconfirmed: "The post could not be confirmed. Check before trying again."
        }
    }
}
