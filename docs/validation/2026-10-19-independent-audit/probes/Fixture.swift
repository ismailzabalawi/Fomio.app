import Foundation
struct NotificationFixture: Sendable {
    enum Acknowledgment: Sendable { case succeed, fail, unknown }
    struct Row: Sendable { var item: NotificationItem; var inaccessible = false }
    static let site = URL(string: "https://community.example")!
    var rows: [Row]
    var pageSize = 6
    var seenID = 4998
    var nextAcknowledgment: Acknowledgment = .succeed
    var failNextPage = false
    var failNextRefresh = false
    var delay: Duration = .zero
    init() {
        func n(_ id: Int, _ kind: NotificationKind, _ actor: String?, _ topic: Int?, _ post: Int?, _ title: String?, read: Bool, age: String, category: Int? = nil, bucket: Int? = nil, count: Int? = nil, group: String? = nil, inaccessible: Bool = false) -> Row {
            var item = NotificationItem(id: .init(id), kind: kind, read: read, age: age, topicID: topic.map { TopicID($0) }, postNumber: post.map { PostNumber($0) }, topicTitle: title, slug: topic.map { "topic-\($0)" }, displayUsername: actor, originalUsername: actor, replyBucket: bucket.map { PostNumber($0) }, consolidatedCount: count, groupName: group, categoryID: category.map { CategoryID($0) })
            if count != nil { item.displayUsername = "\(count!) replies"; item.originalUsername = "ines.r" }
            return Row(item: item, inaccessible: inaccessible)
        }
        let chair = "Hide glue or PVA for a first chair repair?"
        rows = [
            n(5011, .replied, "devon", 4190, 14, "Bench PSU hums after a fuse swap", read: false, age: "5m", category: 6),
            n(5010, .replied, nil, 4205, 5, chair, read: false, age: "40m", category: 3, bucket: 4, count: 3),
            n(5009, .mentioned, "priya", 4201, 6, "Deep sleep current on a dev board: 40 mA?", read: false, age: "1h", category: 7),
            n(5008, .quoted, "sunil.p", 4182, 4, "Oil vs. hardwax on a walnut desk top?", read: false, age: "2h", category: 2),
            n(5007, .unknown(800), "alex.h", 4195, 1, "First drawbored mortise and tenon", read: false, age: "3h", category: 3),
            n(5006, .replied, "theo", 4999, 6, "Bench power supply recommendations", read: false, age: "4h", category: 5),
            n(5005, .groupMentioned, "alex.h", 4195, 3, "First drawbored mortise and tenon", read: true, age: "5h", category: 3, group: "woodworkers"),
            n(5004, .replied, "theo", 4170, 2, "Overwintering a fig in a large container", read: true, age: "Yesterday", category: 8),
            n(5003, .mentioned, "theo", 4201, 5, "Deep sleep current on a dev board: 40 mA?", read: true, age: "Yesterday", category: 7),
            n(5002, .unknown(1000), nil, nil, nil, nil, read: true, age: "2d"),
            n(5001, .replied, "margaux.delacroix-whitfield", 4199, 2, "Built a standing desk from reclaimed oak flooring", read: true, age: "3d", category: 1),
            n(5000, .liked, "mara_k", 4188, 2, "Blotchy cherry: can gel stain save it?", read: true, age: "4d", category: 2),
            n(4999, .replied, nil, 4205, 2, chair, read: true, age: "5d", category: 3, bucket: 1, count: 3)
        ] + (4993...4998).reversed().map { n($0, .replied, "devon", 4100 + $0 % 7, 3, nil, read: false, age: "1w", inaccessible: true) } + [
            n(4990, .mentioned, "priya", 4201, 6, "Deep sleep current on a dev board: 40 mA?", read: false, age: "2w", category: 7)
        ]
    }
    func page(offset: Int, filter: NotificationFilter) -> NotificationHistoryPage {
        let scoped = rows.filter { filter == .all || !$0.item.read }
        let window = scoped.dropFirst(offset).prefix(pageSize)
        // Like the server, permission filtering happens after the window and after counting the total.
        return NotificationHistoryPage(items: window.filter { !$0.inaccessible }.map(\.item), offset: offset, limit: pageSize, totalRows: scoped.count, seenNotificationID: seenID)
    }
    var unseenUnread: Int { min(NotificationTotals.serverCap, rows.filter { !$0.item.read && $0.item.id.rawValue > seenID }.count) }
    mutating func markRead(_ id: NotificationID) { if let index = rows.firstIndex(where: { $0.item.id == id }) { rows[index].item.read = true } }
    /// Consolidation destroys the earlier grouped row and creates a new ID (server behavior in `PostAlerter`).
    mutating func consolidate(replacing old: NotificationID, with new: NotificationID, count: Int) {
        guard let index = rows.firstIndex(where: { $0.item.id == old }) else { return }
        var row = rows.remove(at: index); row.item.id = new; row.item.consolidatedCount = count; row.item.displayUsername = "\(count) replies"; row.item.read = false; row.item.age = "now"
        rows.insert(row, at: 0)
    }
    mutating func arrive(_ item: NotificationItem) { rows.insert(Row(item: item), at: 0) }
}
