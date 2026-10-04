import Foundation
import CryptoKit

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
            .filter { [1, 2].contains($0.version) && $0.account == account }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    func delete(_ id: UUID) throws {
        if FileManager.default.fileExists(atPath: url(id).path) {
            let draft = try JSONDecoder().decode(Draft.self, from: Data(contentsOf: url(id)))
            let folder = photoFolder(draft)
            if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
            try FileManager.default.removeItem(at: url(id))
        }
    }
    private func photoFolder(_ draft: Draft) -> URL {
        let account = SHA256.hash(data: Data(draft.account.rawValue.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("Photos", isDirectory: true).appendingPathComponent(account, isDirectory: true).appendingPathComponent(draft.id.uuidString, isDirectory: true)
    }
    func reconcileFiles(account: AccountID) throws {
        let drafts = try list(account: account)
        let accountFolder = photoFolder(Draft(account: account, intent: .newDiscussion)).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: accountFolder.path) {
            let ids = Set(drafts.map { $0.id.uuidString })
            for folder in try FileManager.default.contentsOfDirectory(at: accountFolder, includingPropertiesForKeys: nil) where !ids.contains(folder.lastPathComponent) { try FileManager.default.removeItem(at: folder) }
        }
        for draft in drafts {
            let folder = photoFolder(draft)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            let referenced = Set(draft.attachments.compactMap(\.localFileName))
            for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) where !referenced.contains(file.lastPathComponent) { try FileManager.default.removeItem(at: file) }
        }
    }
    func retain(_ data: Data, draft: Draft, attachment: UUID) throws -> String {
        let folder = photoFolder(draft)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let name = attachment.uuidString + ".jpg"
        try data.write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        return name
    }
    func photo(draft: Draft, attachment: ComposerAttachment) throws -> Data {
        guard let name = attachment.localFileName, name == attachment.id.uuidString + ".jpg" else { throw RepositoryError.unavailable }
        return try Data(contentsOf: photoFolder(draft).appendingPathComponent(name))
    }
    func clear(account: AccountID) throws {
        for draft in try list(account: account) { try delete(draft.id) }
        let parent = photoFolder(Draft(account: account, intent: .newDiscussion)).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) { try FileManager.default.removeItem(at: parent) }
    }
    func migrateGuest(to account: AccountID) throws {
        for var draft in try list(account: .guest) {
            let previous = photoFolder(draft)
            draft.account = account
            let target = photoFolder(draft)
            if FileManager.default.fileExists(atPath: previous.path) {
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
                try FileManager.default.moveItem(at: previous, to: target)
            }
            do { try save(draft) } catch {
                if FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.moveItem(at: target, to: previous) }
                throw error
            }
        }
    }
}
