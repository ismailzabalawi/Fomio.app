import Foundation
import CryptoKit

/// Last-good public catalogs on disk, isolated by site (origin + relative root), schema and locale.
/// Each record is one atomically written file, so a crash mid-write leaves the previous record intact.
/// At most `limit` catalogs are retained: the current language plus one recently used language.
struct LocalizationStore: Sendable {
    struct Record: Codable, Equatable, Sendable {
        var locale: String
        var revision: String
        var etag: String?
        var fetchedAt: Date
        var lastUsedAt: Date
        /// The response body exactly as validated. It is revalidated on every load.
        var payload: Data
    }
    struct IndexRecord: Codable, Equatable, Sendable { var etag: String?; var fetchedAt: Date; var payload: Data }

    static let limit = 2
    let directory: URL
    let site: String

    /// `root` is Application Support/Localization in the app; tests and UI tests pass isolated folders.
    init(root: URL, site: String) {
        self.site = site
        let digest = SHA256.hash(data: Data(site.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        directory = root.appendingPathComponent("site-\(digest)", isDirectory: true).appendingPathComponent("schema-\(LocalizationCatalog.schema)", isDirectory: true)
    }
    /// Site identity: scheme, host, port and relative root. Query and fragment never participate.
    static func siteKey(_ baseURL: URL) -> String {
        var components = URLComponents()
        components.scheme = baseURL.scheme?.lowercased(); components.host = baseURL.host?.lowercased(); components.port = baseURL.port
        let path = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
        return (components.string ?? "") + path
    }
    static func defaultRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Localization", isDirectory: true)
    }

    private func file(_ locale: String) -> URL { directory.appendingPathComponent("catalog-\(locale).json") }
    private var indexFile: URL { directory.appendingPathComponent("index.json") }
    private func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The catalogs are public and rebuildable; keep them out of device backups.
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var root = directory.deletingLastPathComponent().deletingLastPathComponent()
        try? root.setResourceValues(values)
    }
    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try prepare()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: [.atomic])
    }
    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    func record(_ locale: String) -> Record? {
        guard LocaleMatcher.isValidCode(locale), let value = read(Record.self, from: file(locale)), value.locale == locale else { return nil }
        return value
    }
    func save(_ record: Record) throws {
        guard LocaleMatcher.isValidCode(record.locale) else { throw CatalogError.malformed }
        try write(record, to: file(record.locale))
    }
    func remove(_ locale: String) { try? FileManager.default.removeItem(at: file(locale)) }
    func storedLocales() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            guard name.hasPrefix("catalog-"), name.hasSuffix(".json") else { return nil }
            return String(name.dropFirst("catalog-".count).dropLast(".json".count))
        }.sorted()
    }
    /// Keeps the current locale and the most recently used other locale; everything else is deleted.
    func evict(keeping current: String) {
        let others = storedLocales().filter { $0 != current }.compactMap(record).sorted { $0.lastUsedAt > $1.lastUsedAt }
        let keep = Set([current] + others.prefix(Self.limit - 1).map(\.locale))
        for locale in storedLocales() where !keep.contains(locale) { remove(locale) }
    }

    func index() -> IndexRecord? { read(IndexRecord.self, from: indexFile) }
    func saveIndex(_ record: IndexRecord) throws { try write(record, to: indexFile) }

    /// Removes catalogs written by other schema versions for this site.
    func removeOtherSchemas() {
        let parent = directory.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        for name in names where name.hasPrefix("schema-") && name != directory.lastPathComponent {
            try? FileManager.default.removeItem(at: parent.appendingPathComponent(name))
        }
    }
}
