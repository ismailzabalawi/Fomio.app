import Foundation

@MainActor protocol FeedRepository { func feed(category: Community?, page: Int) async throws -> Page<DiscussionSummary> }
@MainActor protocol CommunityRepository { func communities() async throws -> [Community]; func siteTheme() async throws -> SiteTheme }
@MainActor protocol DiscussionRepository {
    func discussion(_ id: TopicID, page: Int) async throws -> DiscussionPage
    func children(topic: TopicID, parent: PostNumber, page: Int, depth: Int) async throws -> ChildPage
    func context(topic: TopicID, number: PostNumber, focused: Bool) async throws -> ThreadContext
    func like(_ post: Post) async throws -> Post
}
@MainActor protocol SearchRepository { func search(_ query: String, page: Int) async throws -> Page<DiscussionSummary> }
@MainActor protocol NotificationRepository {
    /// History contract: raw `offset`/`limit` window with an optional server read filter. No type filtering.
    func notificationHistory(offset: Int, limit: Int, filter: NotificationFilter) async throws -> NotificationHistoryPage
    /// Exact-ID acknowledgment only. There is deliberately no bulk variant.
    func markNotificationRead(_ id: NotificationID) async throws
    func notificationTotals() async throws -> NotificationTotals
    /// Whether the stored per-user key still authenticates `username`. Discourse answers a revoked or expired key
    /// with 403 `invalid_access` on every request, so content errors alone cannot reveal it.
    func credentialIsValid(username: String) async throws -> Bool
}
extension NotificationRepository { func credentialIsValid(username: String) async throws -> Bool { true } }
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
@MainActor protocol AccountRepository {
    func canDeleteAccount(username: String) async throws -> Bool
    func deleteAccount(username: String) async throws
}
extension AccountRepository {
    func canDeleteAccount(username: String) async throws -> Bool { false }
    func deleteAccount(username: String) async throws { throw RepositoryError.denied }
}
struct SafetySession: Sendable {
    var username: String
    var canIgnoreUsers: Bool
    var ignoredUsers: [String]
}
struct ReportReason: Identifiable, Sendable {
    var id: Int
    var title: String
    var description: String
    var requiresMessage: Bool
}
@MainActor protocol SafetyRepository {
    func safetySession() async throws -> SafetySession
    func reportReasons(post: Post) async throws -> [ReportReason]
    func report(post: Post, reason: Int, message: String) async throws
    func setIgnored(username: String, ignored: Bool) async throws -> SafetySession
}
extension SafetyRepository {
    func safetySession() async throws -> SafetySession { throw RepositoryError.unauthorized }
    func reportReasons(post: Post) async throws -> [ReportReason] { [] }
    func report(post: Post, reason: Int, message: String) async throws { throw RepositoryError.denied }
    func setIgnored(username: String, ignored: Bool) async throws -> SafetySession { throw RepositoryError.denied }
}
@MainActor protocol CommunityService: FeedRepository, CommunityRepository, DiscussionRepository, SearchRepository, NotificationRepository, ProfileRepository, BookmarkRepository, PostingRepository, UploadRepository, ComposerRepository, AccountRepository, SafetyRepository {}

struct ComposerCapabilities: Equatable, Sendable {
    var blocks: Set<ComposerBlockKind> = [.table, .code]
    var maximumPollOptions = 20
    var maximumUploadBytes: Int?
    var similarDiscussions = false
    var onebox = false
    var checklists = false
    static let fixture = ComposerCapabilities(blocks: [.poll, .table, .details, .spoiler, .date, .code], maximumUploadBytes: 10 * 1024 * 1024, similarDiscussions: true, onebox: true, checklists: true)
}
struct OneboxContext: Sendable { var category: CategoryID?; var topic: TopicID? }
struct OneboxMetadata: Equatable, Sendable { var url: URL; var title: String; var summary: String }
@MainActor protocol ComposerRepository {
    var composerCapabilities: ComposerCapabilities { get }
    func similarDiscussions(title: String, raw: String) async throws -> [DiscussionSummary]
    func oneboxPreview(url: URL, context: OneboxContext) async throws -> OneboxMetadata?
}
extension ComposerRepository {
    var composerCapabilities: ComposerCapabilities { ComposerCapabilities() }
    func similarDiscussions(title: String, raw: String) async throws -> [DiscussionSummary] { throw RepositoryError.unsupported }
    func oneboxPreview(url: URL, context: OneboxContext) async throws -> OneboxMetadata? { throw RepositoryError.unsupported }
}

extension CommunityRepository { func siteTheme() async throws -> SiteTheme { SiteTheme() } }
