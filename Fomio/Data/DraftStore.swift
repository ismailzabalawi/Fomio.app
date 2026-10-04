import Foundation

@MainActor final class DraftStore {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Drafts", isDirectory: true)
    }
    private func url(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString).appendingPathExtension("json") }
    func save(_ draft: Draft) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var value = draft
        if value.submission == .submitting { value.submission = .unconfirmed }
        value.updatedAt = Date()
        try JSONEncoder().encode(value).write(to: url(value.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func list(account: AccountID) throws -> [Draft] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(Draft.self, from: Data(contentsOf: $0)) }
            .filter { $0.version == 1 && $0.account == account }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    func delete(_ id: UUID) throws { if FileManager.default.fileExists(atPath: url(id).path) { try FileManager.default.removeItem(at: url(id)) } }
    func clear(account: AccountID) throws { for draft in try list(account: account) { try delete(draft.id) } }
    func migrateGuest(to account: AccountID) throws {
        for var draft in try list(account: .guest) { draft.account = account; try save(draft) }
    }
}
