import Foundation

@MainActor protocol FeedRepository { func feed(category: Community?, page: Int) async throws -> Page<DiscussionSummary> }
@MainActor protocol CommunityRepository { func communities() async throws -> [Community] }
@MainActor protocol DiscussionRepository {
    func discussion(_ id: TopicID, page: Int) async throws -> DiscussionPage
    func children(topic: TopicID, parent: PostNumber, page: Int, depth: Int) async throws -> ChildPage
    func context(topic: TopicID, number: PostNumber, focused: Bool) async throws -> ThreadContext
    func like(_ post: Post) async throws -> Post
}
@MainActor protocol SearchRepository { func search(_ query: String, page: Int) async throws -> Page<DiscussionSummary> }
@MainActor protocol NotificationRepository {
    func notifications(page: Int) async throws -> Page<Notice>
    func markRead(_ notice: Notice) async throws
}
@MainActor protocol ProfileRepository { func profile(_ username: String) async throws -> Member }
@MainActor protocol BookmarkRepository {
    func saved(username: String, page: Int) async throws -> Page<SavedItem>
    func bookmark(_ post: Post) async throws -> Post
}
@MainActor protocol PostingRepository {
    func publish(_ draft: Draft) async throws -> PostingOutcome
    func reconcile(_ draft: Draft) async throws -> Reconciliation
}
@MainActor protocol UploadRepository {
    func upload(_ data: Data, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> UploadedPhoto
}
@MainActor protocol CommunityService: FeedRepository, CommunityRepository, DiscussionRepository, SearchRepository, NotificationRepository, ProfileRepository, BookmarkRepository, PostingRepository, UploadRepository {}
