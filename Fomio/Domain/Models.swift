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
    var topicTemplate: String? = nil
    var identity = CategoryIdentity()
    var descriptionExcerpt: String? = nil
    var aboutURL: String? = nil
}
struct CategoryAsset: Codable, Hashable, Sendable {
    var id: Int? = nil
    var url: String
    var width: Int? = nil
    var height: Int? = nil
}
struct CategoryIdentity: Codable, Hashable, Sendable {
    var color: String? = nil
    var textColor: String? = nil
    var style: String? = nil
    var icon: String? = nil
    var emoji: String? = nil
    var logo: CategoryAsset? = nil
    var darkLogo: CategoryAsset? = nil
    var background: CategoryAsset? = nil
    var darkBackground: CategoryAsset? = nil
}
struct SiteTheme: Equatable, Sendable {
    var light: [String: String] = [:]
    var dark: [String: String] = [:]
}

struct LatestPreview: Codable, Hashable, Sendable { var topicID: TopicID; var title: String; var categoryID: CategoryID; var activity: AgeValue }
struct DiscussionSummary: Identifiable, Codable, Hashable, Sendable {
    var id: TopicID
    var title: String
    var slug: String
    var categoryID: CategoryID
    var excerpt: String
    var author: String
    var replyCount: Int
    var activity: AgeValue
    var image: String?
    var targetPostNumber: PostNumber?
    /// Author of the matched post when a search hit is inside the discussion.
    var matchAuthor: String? = nil
    var pinned = false
    /// Discourse `image_url` from the topic list: an optional public HTTPS image. `image` names bundled fixture assets only.
    var imageURL: URL? = nil
}
/// Accepts only absolute HTTPS (or site-relative) media without embedded credentials. Requests never carry user keys.
enum PublicMedia {
    static func url(_ value: String?, base: URL?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        let url: URL?
        if value.hasPrefix("//") { url = URL(string: "https:" + value) }
        else {
            let root = base.map(\.absoluteString).flatMap { URL(string: $0.hasSuffix("/") ? $0 : $0 + "/") }
            url = URL(string: value, relativeTo: root)?.absoluteURL
        }
        guard let url, url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
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
    var age: AgeValue = ""
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
    var effectiveSort: String? = nil
    var archived = false
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
    var age: AgeValue = ""
    var read: Bool
    /// `actor` is empty when Discourse omits the display name.
    var text: String {
        let name = actor.isEmpty ? L("notifications.someone") : actor
        return kind == .reply ? L("notifications.replied", ["name": name]) : L("notifications.mentioned", ["name": name])
    }
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
    var version = 2
    var id = UUID()
    var account: AccountID
    var intent: ComposerIntent
    var title = ""
    var body = ""
    var categoryID: CategoryID?
    var missingPhoto = false
    var uploadedPhoto: UploadedPhoto?
    var attachments: [ComposerAttachment] = []
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
    /// App-side validation and recovery text, resolved from the active catalog when shown.
    case message(String)
    /// Text shown for this error: a catalog key with arguments, or Discourse's own message.
    var display: DisplayError {
        switch self {
        case .configuration: .key("error.configuration")
        case .offline: .key("error.offline")
        case .unauthorized: .key("error.unauthorized")
        case .denied: .key("error.denied")
        case .unavailable: .key("error.unavailable")
        case .unsupported: .key("error.unsupported")
        // Discourse validation messages are server-owned and shown as returned.
        case let .invalid(message): .verbatim(message)
        case .rateLimited: .key("error.rate_limited")
        case let .server(code): .key("error.server", ["code": String(code)])
        case .unconfirmed: .key("error.unconfirmed")
        case let .message(key): .key(key)
        }
    }
    var errorDescription: String? { display.text }
}

/// An error kept on screen or in a draft. App-authored text stays semantic and resolves from the active
/// catalog each time it is shown, so a retained error follows a language change; Discourse and system
/// messages are kept verbatim. Decodes legacy plain-string values as verbatim text.
enum DisplayError: Equatable, Codable, Sendable {
    case key(String, [String: String] = [:])
    case verbatim(String)
    init(_ error: any Error) {
        if let error = error as? RepositoryError { self = error.display }
        else if let error = error as? DisplayErrorConvertible { self = error.display }
        else { self = .verbatim(error.localizedDescription) }
    }
    var text: String {
        switch self {
        case let .key(key, arguments): Localizer.shared.string(key, arguments.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
        case let .verbatim(message): message
        }
    }
    private enum CodingKeys: String, CodingKey { case key, arguments, verbatim }
    init(from decoder: any Decoder) throws {
        if let legacy = try? decoder.singleValueContainer().decode(String.self) { self = .verbatim(legacy); return }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let key = try c.decodeIfPresent(String.self, forKey: .key) { self = .key(key, try c.decodeIfPresent([String: String].self, forKey: .arguments) ?? [:]) }
        else { self = .verbatim(try c.decode(String.self, forKey: .verbatim)) }
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .key(key, arguments): try c.encode(key, forKey: .key); if !arguments.isEmpty { try c.encode(arguments, forKey: .arguments) }
        case let .verbatim(message): try c.encode(message, forKey: .verbatim)
        }
    }
}
/// Errors that carry their own semantic display text.
protocol DisplayErrorConvertible: Error { var display: DisplayError { get } }

struct ComposerAttachment: Identifiable, Codable, Equatable, Sendable {
    enum Status: Codable, Equatable, Sendable { case retained, queued, uploading(Double), failed(DisplayError), uploaded, missing }
    var id = UUID()
    var description = L("composer.photo.default_description")
    var localFileName: String?
    var sourceLocation: Int?
    var inDocument: Bool?
    var server: UploadedPhoto?
    var status: Status = .retained
    var localReference: String { "fomio-attachment://\(id.uuidString)" }
    var reference: String { server?.shortURL ?? "fomio-attachment://\(id.uuidString)" }
    var markup: String { DiscourseMarkupCodec.image(description: description, url: reference) }
}
extension Draft {
    private enum CodingKeys: String, CodingKey { case version, id, account, intent, title, body, categoryID, missingPhoto, uploadedPhoto, submission, updatedAt, quote, contextTitle, contextCategory, targetAuthor, attachments }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard [1, 2].contains(version) else { throw DecodingError.dataCorruptedError(forKey: .version, in: c, debugDescription: "Unsupported draft version") }
        id = try c.decode(UUID.self, forKey: .id); account = try c.decode(AccountID.self, forKey: .account); intent = try c.decode(ComposerIntent.self, forKey: .intent)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""; body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        categoryID = try c.decodeIfPresent(CategoryID.self, forKey: .categoryID)
        missingPhoto = try c.decodeIfPresent(Bool.self, forKey: .missingPhoto) ?? false; uploadedPhoto = try c.decodeIfPresent(UploadedPhoto.self, forKey: .uploadedPhoto)
        submission = try c.decodeIfPresent(SubmissionState.self, forKey: .submission) ?? .editing; updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        quote = try c.decodeIfPresent(QuoteExcerpt.self, forKey: .quote); contextTitle = try c.decodeIfPresent(String.self, forKey: .contextTitle); contextCategory = try c.decodeIfPresent(CategoryID.self, forKey: .contextCategory); targetAuthor = try c.decodeIfPresent(String.self, forKey: .targetAuthor)
        attachments = try c.decodeIfPresent([ComposerAttachment].self, forKey: .attachments) ?? []
        migrateDocument()
    }
    mutating func migrateDocument() {
        if quote != nil { body = composedBody; quote = nil }
        if let photo = uploadedPhoto {
            let attachment = ComposerAttachment(server: photo, status: .uploaded)
            attachments.append(attachment); body += "\n\n" + attachment.markup; uploadedPhoto = nil
        }
        if missingPhoto && attachments.isEmpty {
            let attachment = ComposerAttachment(status: .missing)
            attachments.append(attachment); body += "\n\n" + attachment.markup
        }
        missingPhoto = false; version = 2
    }
    var attachmentBindings: [(node: MarkupNode, attachment: ComposerAttachment)] {
        var available = attachments
        return DiscourseMarkupCodec.parse(body).filter { $0.kind == .photo }.compactMap { node in
            let matching = available.indices.filter { node.raw.contains("](" + available[$0].reference + ")") || node.raw.contains("](" + available[$0].localReference + ")") }
            guard let index = matching.min(by: {
                let lhs = available[$0], rhs = available[$1]
                if (lhs.sourceLocation == node.range.location) != (rhs.sourceLocation == node.range.location) { return lhs.sourceLocation == node.range.location }
                if (lhs.inDocument != false) != (rhs.inDocument != false) { return lhs.inDocument != false }
                return abs((lhs.sourceLocation ?? node.range.location) - node.range.location) < abs((rhs.sourceLocation ?? node.range.location) - node.range.location)
            }) else { return nil }
            return (node, available.remove(at: index))
        }
    }
    var activeAttachments: [ComposerAttachment] { attachmentBindings.map(\.attachment) }
    mutating func synchronizeAttachments(previousBody: String? = nil) {
        if let previousBody, previousBody != body {
            let old = Array(previousBody.utf16), new = Array(body.utf16)
            var prefix = 0
            while prefix < min(old.count, new.count), old[prefix] == new[prefix] { prefix += 1 }
            var suffix = 0
            while suffix < min(old.count, new.count) - prefix, old[old.count - suffix - 1] == new[new.count - suffix - 1] { suffix += 1 }
            let oldEnd = old.count - suffix, delta = new.count - old.count
            for index in attachments.indices {
                guard attachments[index].inDocument != false, let location = attachments[index].sourceLocation else { continue }
                if location >= oldEnd { attachments[index].sourceLocation = location + delta }
                else if location >= prefix { attachments[index].inDocument = false }
            }
        }
        let bindings = attachmentBindings
        for index in attachments.indices {
            if let binding = bindings.first(where: { $0.attachment.id == attachments[index].id }) {
                attachments[index].sourceLocation = binding.node.range.location; attachments[index].inDocument = true
            } else { attachments[index].inDocument = false }
        }
    }
}
