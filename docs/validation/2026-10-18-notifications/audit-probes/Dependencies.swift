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

struct LiveConfiguration { var baseURL: URL; var callbackURL: URL; var scopes: String
func url(_ path: String, query: [URLQueryItem] = []) -> URL { var c = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!; c.queryItems = query.isEmpty ? nil : query; return c.url! }
}
enum RepositoryError: Error { case unconfirmed, unauthorized }
@MainActor protocol CommunityService {
func notificationHistory(offset: Int, limit: Int, filter: NotificationFilter) async throws -> NotificationHistoryPage
func markNotificationRead(_ id: NotificationID) async throws
func notificationTotals() async throws -> NotificationTotals
}
