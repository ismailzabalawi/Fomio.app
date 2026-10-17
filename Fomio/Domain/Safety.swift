import Foundation

/// Per-viewer flag state from a post's `actions_summary`. `canAct` absent means not permitted; unknown never means allowed.
struct FlagAction: Codable, Hashable, Sendable { var id: Int; var canAct: Bool; var acted: Bool }

/// What a report is about. Post reports carry the post ID; discussion reports carry the topic ID (`flag_topic=true`).
enum ReportTarget: Hashable, Sendable {
    case post(PostID, topic: TopicID, number: PostNumber, author: String)
    case discussion(TopicID, opening: PostID, author: String)
    var noun: String {
        switch self {
        case let .post(_, _, number, _): number.rawValue == 1 ? String(localized: "post") : String(localized: "reply")
        case .discussion: String(localized: "discussion")
        }
    }
    var author: String { switch self { case let .post(_, _, _, author), let .discussion(_, _, author): author } }
    var topicID: TopicID { switch self { case let .post(_, topic, _, _): topic; case let .discussion(topic, _, _): topic } }
    /// The post whose fresh `actions_summary` decides eligibility. Discourse flags a discussion through its opening post.
    var actionPostID: PostID { switch self { case let .post(id, _, _, _): id; case let .discussion(_, opening, _): opening } }
}

/// A Discourse-configured flag reason. Names, descriptions and order come from the server catalog.
struct ReportReason: Identifiable, Hashable, Sendable {
    var id: Int
    var name: String
    var description: String
    var requiresMessage: Bool
}

/// Server-confirmed context for the report sheet. Built from the catalog intersected with fresh `can_act`.
struct ReportContext: Sendable, Equatable {
    var target: ReportTarget
    var excerpt: String
    var reasons: [ReportReason]
    var alreadyReported: Bool
}

enum ReportSubmission: Sendable, Equatable {
    /// 2xx with a decodable post payload. Not a receipt ID.
    case received
    /// Request outcome is unknown (transport failure, 5xx, malformed success). Never resend automatically.
    case unconfirmed
}
enum ReportStatusCheck: Sendable, Equatable { case received, notReceived }

/// Account-wide Ignore state from Discourse; never a device-local list.
struct AccountSafety: Sendable, Equatable {
    var canIgnoreUsers = false
    var ignored: Set<String> = []
}

/// Target-specific Ignore facts from the user card.
struct MemberSafety: Sendable, Equatable {
    var username: String
    var ignored: Bool
    var canIgnore: Bool
    var staff: Bool
}

enum IgnoreDuration: String, CaseIterable, Identifiable, Sendable {
    case forever, week, month, threeMonths, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .forever: String(localized: "Forever")
        case .week: String(localized: "1 week")
        case .month: String(localized: "1 month")
        case .threeMonths: String(localized: "3 months")
        case .year: String(localized: "1 year")
        }
    }
    /// Forever follows Discourse's own convention (`thousandYears()`), so the server keeps a required expiry.
    func expiry(from now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        switch self {
        case .forever: calendar.date(byAdding: .year, value: 1000, to: now)!
        case .week: calendar.date(byAdding: .day, value: 7, to: now)!
        case .month: calendar.date(byAdding: .month, value: 1, to: now)!
        case .threeMonths: calendar.date(byAdding: .month, value: 3, to: now)!
        case .year: calendar.date(byAdding: .year, value: 1, to: now)!
        }
    }
}

/// A collapsed preview outside discussions. Reveals are per item and per launch.
enum IgnoredPreview: Hashable, Sendable { case topic(TopicID), search(TopicID, PostNumber?), notice(Int) }

enum PreferenceWrite: Sendable, Equatable {
    case confirmed
    /// The write may or may not have applied. Reconcile from the server before showing success or retrying.
    case unconfirmed
}

/// Published policy and contact resources. Only server-provided values; nothing is invented or embedded.
struct SafetyResources: Sendable, Equatable {
    var guidelines: URL?
    var terms: URL?
    var privacy: URL?
    var contactEmail: String?
}

@MainActor protocol SafetyRepository {
    func reportContext(_ target: ReportTarget) async throws -> ReportContext
    func submitReport(_ target: ReportTarget, reason: ReportReason, message: String?) async throws -> ReportSubmission
    /// Rechecks whether this account's flag is recorded on the target, after an unknown outcome or a denial.
    func reportStatus(_ target: ReportTarget) async throws -> ReportStatusCheck
    func accountSafety() async throws -> AccountSafety
    func memberSafety(_ username: String) async throws -> MemberSafety
    func ignore(_ username: String, until: Date) async throws -> PreferenceWrite
    /// Discourse `normal`: clears Ignore and any Mute. A previous Mute is not restored.
    func stopIgnoring(_ username: String) async throws -> PreferenceWrite
    /// Full post for a deliberate "Show once" of server-hidden content. Doesn't change the preference.
    func revealPost(_ id: PostID) async throws -> Post
    func safetyResources() async throws -> SafetyResources
}
