import Foundation
@MainActor final class MockService: CommunityService {
    var fixture = NotificationFixture()
    init() {
        fixture.pageSize = 2
        fixture.rows = (1...8).reversed().map { n in NotificationFixture.Row(item: NotificationItem(id: .init(n), kind: .replied, read: false, topicID: .init(n), postNumber: .init(2), topicTitle: "Restricted topic \(n)")) }
    }
    func notificationHistory(offset: Int, limit: Int, filter: NotificationFilter) async throws -> NotificationHistoryPage { fixture.page(offset: offset, filter: filter) }
    func markNotificationRead(_ id: NotificationID) async throws { fixture.markRead(id) }
    func notificationTotals() async throws -> NotificationTotals { NotificationTotals(unread: fixture.rows.filter { !$0.item.read }.count) }
}
@main struct Probe {
    @MainActor static func main() async {
        let service = MockService(), store = NotificationStore(service: MockService(), account: .fixture)
        let unread = NotificationStore(service: service, account: .fixture); unread.pageSize = 2
        await unread.select(.unread)
        await unread.acknowledge(.init(8))
        print("Unread after acknowledgment:", unread.rows().map { "\($0.id.rawValue):read=\($0.read)" })
        await unread.loadMore()
        print("Unread after next page:", unread.rows().map { $0.id.rawValue }, "; expected next unread ID 6, found:", unread.rows().contains { $0.id.rawValue == 6 })
        let access = MockService(), secured = NotificationStore(service: MockService(), account: .fixture)
        let refreshed = NotificationStore(service: access, account: .fixture); refreshed.pageSize = 2
        await refreshed.loadMore()
        access.fixture.rows = access.fixture.rows.map { row in var copy = row; copy.inaccessible = true; return copy }
        await refreshed.refresh()
        print("After successful refresh removes access to all targets:", refreshed.rows().compactMap { $0.topicTitle }, "; refreshError:", refreshed.refreshError ?? "nil")
        let unknownService = MockService(), unknown = NotificationStore(service: MockService(), account: .fixture)
        let recheck = NotificationStore(service: unknownService, account: .fixture); recheck.pageSize = 2
        await recheck.loadMore()
        unknownService.fixture.rows[0].inaccessible = true
        await recheck.recheck(.init(8))
        print("Recheck inaccessible unread row: server.read=", unknownService.fixture.rows[0].item.read, "; client.read=", recheck.item(.init(8))?.read as Any, "; outcome=", recheck.acknowledgments[.init(8)] as Any)
        _ = (store, secured, unknown)
    }
}
