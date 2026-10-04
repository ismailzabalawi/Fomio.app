import Foundation

@MainActor final class DiscourseService: CommunityService {
    let api: APIClient
    let composerCapabilities: ComposerCapabilities
    private var topicSlugs: [TopicID: String] = [:]
    private var initialPages: [TopicID: DiscussionPage] = [:]
    private var metadata: [TopicID: DiscussionSummary] = [:]
    init(configuration: LiveConfiguration?, session: URLSession? = nil, credentials: @escaping (String) throws -> Credential? = KeychainCredentialStore.read, composerCapabilities: ComposerCapabilities = ComposerCapabilities()) { self.composerCapabilities = composerCapabilities; api = APIClient(configuration: configuration, session: session, credentials: credentials) }
    func similarDiscussions(title: String, raw: String) async throws -> [DiscussionSummary] {
        guard composerCapabilities.similarDiscussions else { throw RepositoryError.unsupported }
        let data = try await api.request("topics/similar_to.json", query: [.init(name: "title", value: title), .init(name: "raw", value: raw)], member: true)
        if let empty = try? api.decode([String].self, from: data), empty.isEmpty { return [] }
        struct Envelope: Decodable { var topics: [TopicDTO]?; var users: [UserDTO]? }
        let envelope = try api.decode(Envelope.self, from: data)
        return (envelope.topics ?? []).map { $0.domain(users: envelope.users ?? []) }
    }
    func oneboxPreview(url: URL, context: OneboxContext) async throws -> OneboxMetadata? {
        guard composerCapabilities.onebox, ["https", "http"].contains(url.scheme ?? ""), url.host != nil else { throw RepositoryError.unsupported }
        var query = [URLQueryItem(name: "url", value: url.absoluteString)]
        if let category = context.category { query.append(.init(name: "category_id", value: String(category.rawValue))) }
        if let topic = context.topic { query.append(.init(name: "topic_id", value: String(topic.rawValue))) }
        let data = try await api.request("onebox.json", query: query, member: true)
        guard data.count <= 256 * 1024, let html = String(data: data, encoding: .utf8) else { return nil }
        return NativeOneboxParser.parse(html, url: url)
    }
    func communities() async throws -> [Community] {
        let envelope = try await api.get(CategoryEnvelope.self, "categories.json", query: [URLQueryItem(name: "include_subcategories", value: "true")])
        var result: [Community] = []
        func append(_ category: CategoryDTO) {
            let value = category.domain(canCreate: envelope.categoryList.canCreateTopic == true)
            if !result.contains(where: { $0.id == value.id }) { result.append(value) }
            (category.subcategoryList ?? []).forEach(append)
        }
        envelope.categoryList.categories.forEach(append)
        return result
    }
    func feed(category: Community?, page: Int) async throws -> Page<DiscussionSummary> {
        let path = category.map { "c/\($0.id.rawValue)/l/latest.json" } ?? "latest.json"
        let envelope = try await api.get(FeedEnvelope.self, path, query: [URLQueryItem(name: "page", value: String(page))])
        let items = envelope.topicList.topics.map { $0.domain(users: envelope.users ?? []) }
        for item in items { metadata[item.id] = item; topicSlugs[item.id] = item.slug }
        return Page(items: items, nextPage: envelope.topicList.moreTopicsUrl == nil ? nil : page + 1)
    }
    private func nestedPath(_ id: TopicID) -> String { "n/\(topicSlugs[id] ?? "topic")/\(id.rawValue)" }
    private func summary(_ dto: TopicDTO) -> DiscussionSummary { let result = dto.domain(users: []); metadata[result.id] = result; topicSlugs[result.id] = result.slug; return result }
    func discussion(_ id: TopicID, page: Int) async throws -> DiscussionPage {
        let envelope = try await api.get(RootsDTO.self, nestedPath(id) + ".json", query: [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "sort", value: "new")])
        let detail: DiscussionSummary
        let opening: Post
        let canReply: Bool
        if let topic = envelope.topic, let op = envelope.opPost {
            detail = summary(topic); canReply = topic.details?.canCreatePost == true
            opening = op.domain(canReply: canReply, topicID: id)
        } else {
            // Later root pages omit topic and OP metadata. Fetch only when this adapter has no initial page.
            let initial: DiscussionPage
            if let cached = initialPages[id] { initial = cached } else { initial = try await discussion(id, page: 0) }
            detail = initial.summary; opening = initial.opening; canReply = initial.canReply
        }
        let result = DiscussionPage(summary: detail, opening: opening, roots: envelope.roots.map { $0.node(canReply: canReply, topicID: id) }, nextPage: envelope.hasMoreRoots ? page + 1 : nil, closed: envelope.topic?.closed ?? initialPages[id]?.closed ?? false, canReply: canReply)
        if page == 0 { initialPages[id] = result }; return result
    }
    func children(topic: TopicID, parent: PostNumber, page: Int, depth: Int) async throws -> ChildPage {
        let dto = try await api.get(ChildrenDTO.self, nestedPath(topic) + "/children/\(parent.rawValue).json", query: [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "sort", value: "new"), URLQueryItem(name: "depth", value: String(depth))])
        // Reply permission comes from topic details, never from tree existence.
        let detail: DiscussionPage
        if let cached = initialPages[topic] { detail = cached } else { detail = try await discussion(topic, page: 0) }
        return ChildPage(nodes: dto.children.map { $0.node(canReply: detail.canReply, topicID: topic) }, nextPage: dto.hasMore ? page + 1 : nil)
    }
    func context(topic: TopicID, number: PostNumber, focused: Bool) async throws -> ThreadContext {
        var query = [URLQueryItem(name: "sort", value: "new")]
        if focused { query.append(URLQueryItem(name: "context", value: "0")) }
        let dto = try await api.get(ContextDTO.self, nestedPath(topic) + "/context/\(number.rawValue).json", query: query)
        let detail = summary(dto.topic), canReply = dto.topic.details?.canCreatePost == true
        let page = DiscussionPage(summary: detail, opening: dto.opPost.domain(canReply: canReply, topicID: topic), roots: [], nextPage: nil, closed: dto.topic.closed == true, canReply: canReply)
        return ThreadContext(page: page, ancestors: dto.ancestorChain.map { $0.domain(canReply: canReply, topicID: topic) }, target: dto.targetPost.node(canReply: canReply, topicID: topic), truncated: dto.ancestorsTruncated)
    }
    func like(_ post: Post) async throws -> Post {
        let data = try await api.json(post.liked ? "post_actions/\(post.id.rawValue).json" : "post_actions.json", method: post.liked ? "DELETE" : "POST", payload: ["id": post.id.rawValue, "post_action_type_id": 2])
        if data.isEmpty { throw RepositoryError.unavailable }
        return try api.decode(PostDTO.self, from: data).domain(canReply: post.canReply)
    }
    func bookmark(_ post: Post) async throws -> Post {
        var result = post
        if let id = post.bookmarkID { _ = try await api.json("bookmarks/\(id).json", method: "DELETE", payload: [:]); result.bookmarkID = nil }
        else {
            struct Created: Decodable { let id: Int }
            let data = try await api.json("bookmarks.json", payload: ["bookmarkable_type": "Post", "bookmarkable_id": post.id.rawValue])
            result.bookmarkID = try api.decode(Created.self, from: data).id
        }
        return result
    }
    func search(_ query: String, page: Int) async throws -> Page<DiscussionSummary> {
        let dto = try await api.get(SearchDTO.self, "search.json", query: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "type_filter", value: "topic")])
        let items: [DiscussionSummary] = (dto.posts ?? []).compactMap { post in
            guard let topic = dto.topics?.first(where: { $0.id == post.topicId }) else { return nil }
            var item = topic.domain(users: dto.users ?? [])
            item.excerpt = HTMLContent.plainText(post.blurb ?? ""); item.author = post.username ?? item.author
            item.targetPostNumber = post.postNumber.map { PostNumber($0) }; item.matchAuthor = post.username
            return item
        }
        items.forEach { metadata[$0.id] = $0; topicSlugs[$0.id] = $0.slug }
        return Page(items: items, nextPage: dto.groupedSearchResult?.moreFullPageResults == true ? page + 1 : nil)
    }
    func notifications(page: Int) async throws -> Page<Notice> {
        let dto = try await api.get(NoticesDTO.self, "notifications.json", query: [URLQueryItem(name: "offset", value: String(page * 30)), URLQueryItem(name: "limit", value: "30"), URLQueryItem(name: "filter_by_types", value: "replied,mentioned")], member: true)
        let items = dto.notifications.filter { $0.notificationType == 1 || $0.notificationType == 2 }.map { notice in
            Notice(id: notice.id, kind: notice.notificationType == 1 ? .mention : .reply, actor: notice.data?.displayUsername ?? "A member", title: notice.fancyTitle.map(HTMLContent.plainText) ?? "", topicID: notice.topicId.map { TopicID($0) }, number: notice.postNumber.map { PostNumber($0) }, age: RelativeAge.string(iso: notice.createdAt), read: notice.read)
        }
        return Page(items: items, nextPage: (page + 1) * 30 < dto.totalRowsNotifications ? page + 1 : nil)
    }
    func markRead(_ notice: Notice) async throws { _ = try await api.json("notifications/mark-read.json", method: "PUT", payload: ["id": notice.id]) }
    func profile(_ username: String) async throws -> Member {
        let dto = try await api.get(MemberDTO.self, "u/\(username).json")
        let recent = try await api.get(FeedEnvelope.self, "topics/created-by/\(username).json")
        return Member(username: dto.user.username, name: dto.user.name, bio: HTMLContent.plainText(dto.user.bioCooked ?? ""), recent: recent.topicList.topics.map { $0.domain(users: recent.users ?? []) }, joined: dto.user.joined)
    }
    func saved(username: String, page: Int) async throws -> Page<SavedItem> {
        let dto = try await api.get(SavedDTO.self, "u/\(username)/bookmarks.json", query: [URLQueryItem(name: "page", value: String(page))], member: true)
        return Page(items: dto.bookmarks.compactMap { item in guard let topic = item.topicId else { return nil }; return SavedItem(id: item.id, title: item.title ?? "Saved discussion", topicID: .init(topic), number: item.linkedPostNumber.map { PostNumber($0) }) }, nextPage: dto.moreBookmarksUrl == nil ? nil : page + 1)
    }
    func publish(_ draft: Draft) async throws -> PostingOutcome {
        guard !draft.body.contains("fomio-attachment://"), draft.activeAttachments.allSatisfy({ $0.status == .uploaded && $0.server?.shortURL.hasPrefix("upload://") == true }) else { throw RepositoryError.invalid("Resolve every photo before posting.") }
        let body = draft.composedBody
        var payload: [String: Any] = ["raw": body, "nested_post": true]
        switch draft.intent {
        case .newDiscussion:
            guard let category = draft.categoryID else { throw RepositoryError.invalid("Choose a community.") }
            payload["title"] = draft.title; payload["category"] = category.rawValue
        case let .reply(topic, parent): payload["topic_id"] = topic.rawValue; if let parent { payload["reply_to_post_number"] = parent.rawValue }
        }
        let data: Data
        do { data = try await api.json("posts.json", payload: payload) } catch RepositoryError.unconfirmed { return .unconfirmed }
        // A malformed successful response must remain uncertain, not become a retryable validation error.
        guard let dto = try? api.decode(PostingDTO.self, from: data) else { return .unconfirmed }
        if dto.action == "enqueued" { return .pending }
        if dto.success == true, let post = dto.post, let topic = post.topicId { return .published(topic: .init(topic), number: .init(post.postNumber)) }
        if let errors = dto.errors, !errors.isEmpty { throw RepositoryError.invalid(errors.joined(separator: "\n")) }
        return .unconfirmed
    }
    func reconcile(_ draft: Draft) async throws -> Reconciliation {
        // No client submission identity contract has been established. Matching raw text is not proof.
        return .unresolved
    }
    func upload(_ data: Data, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> UploadedPhoto {
        let boundary = "Fomio-" + UUID().uuidString
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"upload_type\"\r\n\r\ncomposer\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        progress(0)
        let result = try await api.request("uploads.json", method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)", member: true, uploadProgress: progress)
        struct UploadDTO: Decodable { var url: String; var shortUrl: String; var width: Int?; var height: Int? }
        let dto = try api.decode(UploadDTO.self, from: result); progress(1)
        return UploadedPhoto(url: dto.url, shortURL: dto.shortUrl, width: dto.width, height: dto.height)
    }
}
struct CategoryEnvelope: Decodable {
    struct List: Decodable { var categories: [CategoryDTO]; var canCreateTopic: Bool? }
    var categoryList: List
}
struct CategoryDTO: Decodable {
    var id: Int; var name: String; var slug: String?; var parentCategoryId: Int?; var descriptionText: String?; var permission: Int?; var subcategoryList: [CategoryDTO]?; var topicTemplate: String?
    func domain(canCreate: Bool) -> Community { Community(id: .init(id), name: name, slug: slug ?? "", parentID: parentCategoryId.map { CategoryID($0) }, description: descriptionText ?? "", canCreate: canCreate && permission == 1, topicTemplate: topicTemplate) }
}
struct UserDTO: Decodable { var id: Int; var username: String }
struct TopicDTO: Decodable {
    struct Details: Decodable { var canCreatePost: Bool? }
    struct Poster: Decodable { var userId: Int; var description: String? }
    var id: Int; var title: String; var slug: String?; var categoryId: Int?; var excerpt: String?; var replyCount: Int?; var postsCount: Int?; var lastPosterUsername: String?; var posters: [Poster]?; var closed: Bool?; var details: Details?
    func domain(users: [UserDTO]) -> DiscussionSummary {
        let authorID = posters?.first(where: { $0.description?.contains("Original Poster") == true })?.userId ?? posters?.first?.userId
        let author = users.first { $0.id == authorID }?.username ?? ""
        return DiscussionSummary(id: .init(id), title: title, slug: slug ?? "topic", categoryID: .init(categoryId ?? 0), excerpt: HTMLContent.plainText(excerpt ?? ""), author: author, replyCount: replyCount ?? max(0, (postsCount ?? 1) - 1), activity: "")
    }
}
struct FeedEnvelope: Decodable { struct List: Decodable { var topics: [TopicDTO]; var moreTopicsUrl: String? }; var topicList: List; var users: [UserDTO]? }
struct PostDTO: Decodable {
    struct Action: Decodable { var id: Int; var count: Int?; var acted: Bool?; var canAct: Bool? }
    var id: Int; var postNumber: Int; var topicId: Int?; var replyToPostNumber: Int?; var username: String?; var name: String?; var createdAt: String?; var cooked: String?; var raw: String?; var actionsSummary: [Action]?; var bookmarkId: Int?; var deletedPostPlaceholder: Bool?; var ignoredPostPlaceholder: Bool?; var directReplyCount: Int?; var children: [PostDTO]?
    func domain(canReply: Bool, topicID: TopicID? = nil) -> Post {
        let like = actionsSummary?.first { $0.id == 2 }
        return Post(id: .init(id), number: .init(postNumber), topicID: topicId.map { TopicID($0) } ?? topicID ?? .init(0), parent: replyToPostNumber.map { PostNumber($0) }, author: username ?? "", body: raw ?? HTMLContent.plainText(cooked ?? ""), cooked: cooked, likeCount: like?.count ?? 0, liked: like?.acted == true, bookmarkID: bookmarkId, canLike: like?.canAct == true, canReply: canReply, deleted: deletedPostPlaceholder == true, ignored: ignoredPostPlaceholder == true, childCount: directReplyCount ?? 0, age: RelativeAge.string(iso: createdAt), authorName: name.flatMap { $0.isEmpty ? nil : $0 })
    }
    func node(canReply: Bool, topicID: TopicID? = nil) -> ThreadNode { ThreadNode(post: domain(canReply: canReply, topicID: topicID), children: (children ?? []).map { $0.node(canReply: canReply, topicID: topicID) }) }
}
struct RootsDTO: Decodable { var topic: TopicDTO?; var opPost: PostDTO?; var roots: [PostDTO]; var hasMoreRoots: Bool; var page: Int }
struct ChildrenDTO: Decodable { var children: [PostDTO]; var hasMore: Bool; var page: Int }
struct ContextDTO: Decodable { var topic: TopicDTO; var opPost: PostDTO; var ancestorChain: [PostDTO]; var targetPost: PostDTO; var ancestorsTruncated: Bool }
struct SearchDTO: Decodable { struct Result: Decodable { var topicId: Int; var postNumber: Int?; var blurb: String?; var username: String? }; struct Group: Decodable { var moreFullPageResults: Bool? }; var topics: [TopicDTO]?; var posts: [Result]?; var users: [UserDTO]?; var groupedSearchResult: Group? }
struct NoticesDTO: Decodable {
    struct Item: Decodable { struct Info: Decodable { var displayUsername: String? }; var id: Int; var notificationType: Int; var read: Bool; var topicId: Int?; var postNumber: Int?; var fancyTitle: String?; var createdAt: String?; var data: Info? }
    var notifications: [Item]; var totalRowsNotifications: Int
}
struct MemberDTO: Decodable {
    struct User: Decodable {
        var username: String; var name: String?; var bioCooked: String?; var createdAt: String?
        var joined: String? {
            guard let createdAt, let date = ISO8601DateFormatter.fractional.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) else { return nil }
            return date.formatted(.dateTime.month(.abbreviated).year())
        }
    }
    var user: User
}
extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter { let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return value }
}
struct SavedDTO: Decodable { struct Item: Decodable { var id: Int; var title: String?; var topicId: Int?; var linkedPostNumber: Int? }; var bookmarks: [Item]; var moreBookmarksUrl: String? }
struct PostingDTO: Decodable { var success: Bool?; var action: String?; var post: PostDTO?; var errors: [String]? }
