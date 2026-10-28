import Foundation

enum NotificationTag: Sendable {}
/// Discourse notification row ID. Distinct from topic ID, post number and post database ID.
typealias NotificationID = EntityID<NotificationTag>

/// Discourse `Notification.types`. Unknown and plugin types are retained, never dropped.
enum NotificationKind: Hashable, Sendable {
    case mentioned, replied, quoted, edited, liked, privateMessage, invitedToPrivateMessage, posted, movedPost, linked
    case grantedBadge, invitedToTopic, groupMentioned, groupMessageSummary, watchingFirstPost, likedConsolidated
    case postApproved, bookmarkReminder, watchingCategoryOrTag, linkedConsolidated
    case unknown(Int)
    private static let table: [Int: NotificationKind] = [1: .mentioned, 2: .replied, 3: .quoted, 4: .edited, 5: .liked, 6: .privateMessage, 7: .invitedToPrivateMessage, 9: .posted, 10: .movedPost, 11: .linked, 12: .grantedBadge, 13: .invitedToTopic, 15: .groupMentioned, 16: .groupMessageSummary, 17: .watchingFirstPost, 19: .likedConsolidated, 20: .postApproved, 24: .bookmarkReminder, 36: .watchingCategoryOrTag, 39: .linkedConsolidated]
    init(raw: Int) { self = Self.table[raw] ?? .unknown(raw) }
    var raw: Int {
        if case let .unknown(value) = self { return value }
        return Self.table.first { $0.value == self }!.key
    }
    /// Types whose topic/post fields name a discussion post the native reader can open.
    var opensDiscussion: Bool {
        switch self {
        case .mentioned, .replied, .quoted, .edited, .liked, .posted, .movedPost, .linked, .invitedToTopic, .groupMentioned, .watchingFirstPost, .postApproved, .bookmarkReminder, .watchingCategoryOrTag: true
        default: false
        }
    }
}

/// Generic envelope over `NotificationSerializer`. Every field beyond identity is optional data.
struct NotificationItem: Identifiable, Equatable, Sendable {
    var id: NotificationID
    var kind: NotificationKind
    var read: Bool
    var highPriority = false
    var createdAt: String?
    var age = ""
    var topicID: TopicID?
    /// Post number inside the topic, not a post database ID.
    var postNumber: PostNumber?
    var topicTitle: String?
    var slug: String?
    /// `data.display_username`. For consolidated replies this is localized “N replies”, never an author.
    var displayUsername: String?
    var originalUsername: String?
    var actingName: String?
    /// `data.reply_to_post_number`: the nested reply bucket; 1 is the topic root.
    var replyBucket: PostNumber?
    var consolidatedCount: Int?
    var count: Int?
    var groupName: String?
    var badgeID: Int?
    var badgeName: String?
    var badgeSlug: String?
    var dataUsername: String?
    /// Category is not part of the notification serializer. Only fixtures supply it.
    var categoryID: CategoryID? = nil

    var isUnknownKind: Bool { if case .unknown = kind { true } else { false } }
    var isGroupedReplies: Bool { kind == .replied && replyBucket != nil && (consolidatedCount ?? 0) > 1 && topicID != nil }
    /// The member credited with the activity, when one exists. Grouped rows have none.
    var actor: String? {
        if isGroupedReplies { return nil }
        if kind == .replied, let original = originalUsername, displayUsername != original, displayUsername?.contains(where: \.isNumber) == true { return nil }
        return displayUsername ?? originalUsername ?? dataUsername
    }
    /// Usernames that local Ignore filtering compares against. Only a row credited to a single member is filtered:
    /// a grouped or collapsed reply keeps `original_username` from one incoming post while counting replies from
    /// several members (`PostAlerter#create_notification`), so one ignored name is not evidence about the aggregate.
    var filterNames: [String] {
        guard actor != nil else { return [] }
        return [displayUsername, originalUsername, dataUsername].compactMap { $0 }
    }
}

/// Where a notification opens. Built from server fields only.
enum NotificationDestination: Equatable, Sendable {
    case post(TopicID, PostNumber)
    case topic(TopicID)
    /// `parent == nil` is the topic-root bucket.
    case groupedReplies(TopicID, parent: PostNumber?, count: Int)
    case website(URL)
    case unsupported
    var isNative: Bool { switch self { case .post, .topic, .groupedReplies: true; default: false } }
}

enum NotificationResolver {
    static func destination(_ item: NotificationItem, site: URL?, username: String?) -> NotificationDestination {
        if item.isGroupedReplies, let topic = item.topicID, let bucket = item.replyBucket, let count = item.consolidatedCount {
            return .groupedReplies(topic, parent: bucket.rawValue <= 1 ? nil : bucket, count: count)
        }
        if item.kind.opensDiscussion, let topic = item.topicID {
            if let number = item.postNumber, number.rawValue > 1 { return .post(topic, number) }
            return .topic(topic)
        }
        // Native private messages are out of scope; other types use the web renderer's link only when it is derivable.
        guard let site else { return .unsupported }
        func page(_ path: String, query: [URLQueryItem] = []) -> NotificationDestination { .website(LiveConfiguration(baseURL: site, callbackURL: site, scopes: "").url(path, query: query)) }
        switch item.kind {
        case .privateMessage, .invitedToPrivateMessage:
            if let topic = item.topicID { return page("t/\(item.slug ?? "topic")/\(topic.rawValue)" + (item.postNumber.map { "/\($0.rawValue)" } ?? "")) }
        case .grantedBadge:
            if let badge = item.badgeID {
                let slug = item.badgeSlug ?? item.badgeName.map { $0.replacingOccurrences(of: "[^A-Za-z0-9_]+", with: "-", options: .regularExpression).lowercased() } ?? "badge"
                return page("badges/\(badge)/\(slug)", query: username.map { [URLQueryItem(name: "username", value: $0)] } ?? [])
            }
        case .groupMessageSummary:
            if let owner = item.dataUsername, let group = item.groupName { return page("u/\(owner)/messages/group/\(group)") }
        case .likedConsolidated:
            if let username, let actor = item.dataUsername { return page("u/\(username)/notifications/likes-received", query: [URLQueryItem(name: "acting_username", value: actor)]) }
        default:
            if let topic = item.topicID { return page("t/\(item.slug ?? "topic")/\(topic.rawValue)" + (item.postNumber.map { "/\($0.rawValue)" } ?? "")) }
        }
        return .unsupported
    }
    /// Accepts only links on the configured site's origin and base path.
    static func isSameSite(_ url: URL, site: URL) -> Bool {
        guard url.scheme == "https", url.scheme == site.scheme, url.host == site.host, url.port == site.port, url.user == nil else { return false }
        let base = site.path.split(separator: "/"), path = url.path.split(separator: "/")
        return path.starts(with: base)
    }
}

/// Human copy for one row; mirrors the approved mock wording.
struct NotificationCopy: Equatable {
    var lead: String
    var action: String
    var full: String { lead + action }
    init(_ item: NotificationItem) {
        let actor = item.actor ?? "A member"
        if item.isGroupedReplies {
            let count = item.consolidatedCount ?? 2
            lead = "\(count) new replies"; action = item.replyBucket?.rawValue == 1 ? " to your discussion" : " to your post"; return
        }
        if item.kind == .replied, item.actor == nil { lead = "New replies"; action = " in your discussion"; return }
        switch item.kind {
        case .mentioned: lead = actor; action = " mentioned you"
        case .replied: lead = actor; action = " replied to your post"
        case .quoted: lead = actor; action = " quoted your post"
        case .groupMentioned: lead = actor; action = item.groupName.map { " mentioned @\($0)" } ?? " mentioned your group"
        case .liked: lead = actor; action = " liked your post"
        case .likedConsolidated: lead = actor; action = item.count.map { " liked \($0) of your posts" } ?? " liked your posts"
        case .edited: lead = actor; action = " edited a post"
        case .posted: lead = actor; action = " posted in a discussion you follow"
        case .watchingFirstPost, .watchingCategoryOrTag: lead = actor; action = " started a discussion"
        case .movedPost: lead = actor; action = " moved a post"
        case .linked, .linkedConsolidated: lead = actor; action = " linked to your post"
        case .invitedToTopic: lead = actor; action = " invited you to a discussion"
        case .privateMessage: lead = actor; action = " sent you a message"
        case .invitedToPrivateMessage: lead = actor; action = " invited you to a message"
        case .groupMessageSummary: lead = item.groupName.map { "\($0) inbox" } ?? "Group inbox"; action = item.count.map { " has \($0) messages" } ?? " has messages"
        case .grantedBadge: lead = "You earned"; action = item.badgeName.map { " the \($0) badge" } ?? " a badge"
        case .postApproved: lead = "Your post"; action = " was approved"
        case .bookmarkReminder: lead = "Reminder"; action = " for a saved post"
        case .unknown: lead = "Activity Fomio can’t show yet"; action = ""
        }
    }
}

/// Server-provided history window. `nextOffset` advances by the raw requested limit, never by the returned count.
struct NotificationHistoryPage: Sendable {
    var items: [NotificationItem]
    var offset: Int
    var limit: Int
    var totalRows: Int
    var seenNotificationID: Int?
    var nextOffset: Int? { offset + limit < totalRows ? offset + limit : nil }
}
enum NotificationFilter: String, CaseIterable, Sendable { case all, unread }

/// `GET /notifications/totals.json` `unread_notifications`: unread rows newer than the seen cursor on non-deleted
/// topics, capped at 99 by the server, minus new private-message notifications. It is not a loaded-row count.
struct NotificationTotals: Equatable, Sendable {
    static let serverCap = 99
    var unread: Int
    var badgeText: String? { unread <= 0 ? nil : unread >= Self.serverCap ? "99+" : String(unread) }
}

/// Outcome of an exact-ID acknowledgment as the inbox shows it.
enum AcknowledgmentState: Equatable, Sendable { case pending, failed(String), unknown, checking }

// MARK: Device alerts

enum AlertPermission: Equatable, Sendable { case notDetermined, denied, authorized, provisional, ephemeral, unknown }
/// Enrollment with a delivery relay, tracked separately from OS permission.
enum AlertEnrollment: Equatable, Sendable {
    case none, registering, failed(String), ready, renewing, detached
    /// No approved relay or device-registration service is configured for this build.
    case unavailable
}
struct DeviceWording: Sendable {
    var device: String
    var system: String
    static func current(isPad: Bool) -> DeviceWording { isPad ? .init(device: "iPad", system: "iPadOS") : .init(device: "iPhone", system: "iOS") }
}

/// A typed notification-tap intent. The relay payload is not established; fields are validated before use.
struct NotificationIntent: Equatable, Sendable {
    var site: URL
    var username: String
    var notificationID: NotificationID?
    var topicID: TopicID?
    var postNumber: PostNumber?
    var kind: NotificationKind
    var replyBucket: PostNumber?
    var consolidatedCount: Int?
    var title: String?
    init(site: URL, username: String, notificationID: NotificationID? = nil, topicID: TopicID? = nil, postNumber: PostNumber? = nil, kind: NotificationKind, replyBucket: PostNumber? = nil, consolidatedCount: Int? = nil, title: String? = nil) {
        self.site = site; self.username = username; self.notificationID = notificationID; self.topicID = topicID; self.postNumber = postNumber
        self.kind = kind; self.replyBucket = replyBucket; self.consolidatedCount = consolidatedCount; self.title = title
    }
    var dedupeKey: String { notificationID.map { "n\($0.rawValue)" } ?? "t\(topicID?.rawValue ?? 0)p\(postNumber?.rawValue ?? 0)k\(kind.raw)" }
    /// Parses only explicit, typed keys. URLs inside the payload are never launched directly.
    static func parse(_ info: [AnyHashable: Any]) -> NotificationIntent? {
        func int(_ key: String) -> Int? { (info[key] as? Int) ?? (info[key] as? NSNumber)?.intValue ?? (info[key] as? String).flatMap(Int.init) }
        guard let raw = info["fomio_site"] as? String, let site = URL(string: raw), site.scheme == "https", site.host != nil,
              let username = info["fomio_username"] as? String, !username.isEmpty, let type = int("notification_type") else { return nil }
        var intent = NotificationIntent(site: site, username: username, kind: NotificationKind(raw: type))
        intent.notificationID = int("notification_id").map { NotificationID($0) }
        if let topic = int("topic_id"), topic > 0 { intent.topicID = TopicID(topic) }
        if let number = int("post_number"), number > 0 { intent.postNumber = PostNumber(number) }
        intent.replyBucket = int("reply_to_post_number").map { PostNumber($0) }
        intent.consolidatedCount = int("consolidated_count")
        intent.title = info["topic_title"] as? String
        return intent
    }
    var item: NotificationItem {
        NotificationItem(id: notificationID ?? NotificationID(0), kind: kind, read: false, topicID: topicID, postNumber: postNumber, topicTitle: title, replyBucket: replyBucket, consolidatedCount: consolidatedCount)
    }
}
