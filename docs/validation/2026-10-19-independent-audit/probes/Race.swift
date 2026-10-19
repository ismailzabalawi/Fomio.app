import Foundation
@MainActor final class RaceService: CommunityService {
 var fixture = NotificationFixture()
 var suspendNext = false
 var suspended = false
 var continuation: CheckedContinuation<Void,Never>?
 init() { fixture.pageSize = 2; fixture.rows = (1...8).reversed().map { n in .init(item: .init(id: .init(n), kind: .replied, read: false, topicID: .init(n), postNumber: .init(2))) } }
 func notificationHistory(offset: Int, limit: Int, filter: NotificationFilter) async throws -> NotificationHistoryPage {
   let snapshot = fixture.page(offset: offset, filter: filter)
   if suspendNext { suspendNext = false; suspended = true; await withCheckedContinuation { continuation = $0 } }
   return snapshot
 }
 func markNotificationRead(_ id: NotificationID) async throws { fixture.markRead(id) }
 func notificationTotals() async throws -> NotificationTotals { .init(unread: fixture.rows.filter { !$0.item.read }.count) }
}
@main struct RaceProbe {
 @MainActor static func main() async {
   let service = RaceService(); let store = NotificationStore(service: service, account: .fixture); store.pageSize = 2
   await store.select(.unread)
   service.suspendNext = true
   let refresh = Task { await store.refresh() }
   while !service.suspended { await Task.yield() }
   await store.acknowledge(.init(8))
   print("After successful acknowledgment:", store.rows().map { "\($0.id.rawValue):\($0.read)" })
   service.continuation?.resume(); await refresh.value
   print("After older refresh completes:", store.rows().map { "\($0.id.rawValue):\($0.read)" }, "next:", store.feed.nextOffset as Any)
   await store.loadMore()
   print("Next page IDs:", store.rows().map { $0.id.rawValue }, "server ID8 read:", service.fixture.rows[0].item.read)
   var grouped = NotificationItem(id: .init(90), kind: .replied, read: false, topicID: .init(90), postNumber: .init(4))
   grouped.replyBucket = .init(4); grouped.consolidatedCount = 3; grouped.displayUsername = "3 replies"; grouped.originalUsername = "blocked-member"
   print("Grouped actor:", grouped.actor as Any, "hidden by ignoring original member:", grouped.filterNames.contains("blocked-member"))
 }
}
