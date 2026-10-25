import Foundation

enum BrowseLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    static func format(_ key: String, locale: Locale = .current, _ arguments: CVarArg...) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: arguments)
    }
    static func retryCountdown(until: Date, now: Date, locale: Locale = .current) -> String {
        let seconds = ceil(until.timeIntervalSince(now))
        // A valid numeric Retry-After can exceed Int's range. Only the label falls
        // back; the original server deadline still controls Retry availability.
        guard seconds.isFinite, seconds < Double(Int.max) else { return string("Try again later", locale: locale) }
        return format("Try again in %ld seconds", locale: locale, Int(max(0, seconds)))
    }
}

/// A category ID is never inferred from a label, query string, or array position.
enum BrowseScope: Hashable, Sendable {
    case all
    case category(CategoryID)
    var categoryID: CategoryID? { if case let .category(id) = self { id } else { nil } }
    var feedKey: String { categoryID.map { "category-\($0.rawValue)" } ?? "home" }

    func categoryIDs(in catalog: [Community]) throws -> Set<CategoryID>? {
        guard let id = categoryID else { return nil }
        guard id.rawValue > 0, let root = catalog.first(where: { $0.id == id }), !root.restricted else { throw RepositoryError.denied }
        let children = catalog.filter { $0.parentID == id && !$0.restricted }
        if let parentID = root.parentID {
            guard let parent = catalog.first(where: { $0.id == parentID }), parent.parentID == nil, children.isEmpty else { throw SearchFailure.contract }
        }
        // The reviewed taxonomy supports one child level. Do not silently broaden a root boundary.
        guard !catalog.contains(where: { candidate in children.contains(where: { $0.id == candidate.parentID }) }) else { throw SearchFailure.contract }
        return Set([id] + children.map(\.id))
    }
}

struct SearchSettings: Equatable, Sendable {
    let minimumTermLength: Int
    let locale: String
    init(minimumTermLength: Int, locale: String) throws {
        guard minimumTermLength > 0, !locale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SearchFailure.settings }
        self.minimumTermLength = minimumTermLength; self.locale = locale
    }
}

enum SearchFailure: Error, LocalizedError, Equatable {
    case serverSearch, contract, settings
    case input(String)
    case rateLimited(Date?)
    case accessDenied
    var errorDescription: String? { localizedMessage(locale: .current) }
    func localizedMessage(locale: Locale) -> String {
        switch self {
        case .serverSearch: BrowseLocalization.string("Search couldn’t be completed. Try again.", locale: locale)
        case .contract: BrowseLocalization.string("The community returned search results that couldn’t be verified. Try again.", locale: locale)
        case .settings: BrowseLocalization.string("Search settings couldn’t be loaded. Try again.", locale: locale)
        case let .input(message): message
        case .rateLimited: BrowseLocalization.string("Too many searches. Wait a moment, then retry.", locale: locale)
        case .accessDenied: BrowseLocalization.string("Access to this search couldn’t be verified. Try again.", locale: locale)
        }
    }
}

struct DiscussionSearchRequest: Hashable, Sendable {
    let query: String
    let scope: BrowseScope
    let page: Int
    /// Explicit secured catalog boundary for scoped results. Nil means All, never an unresolved category.
    let allowedCategoryIDs: Set<CategoryID>?
    let locale: String

    init(query: String, scope: BrowseScope, page: Int, settings: SearchSettings, catalog: [Community], validationLocale: Locale = .current) throws {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Operators inside quotes are still operators in Discourse. Keep the first native grammar
        // deliberately limited to ordinary terms and balanced phrases, before adding trusted scope.
        guard !trimmed.isEmpty else { throw SearchFailure.input(BrowseLocalization.string("Enter words to search for.", locale: validationLocale)) }
        guard !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) }),
              trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":#@|=\\")) == nil,
              trimmed.filter({ $0 == "\"" }).count.isMultiple(of: 2),
              !trimmed.split(whereSeparator: \.isWhitespace).contains(where: { $0.hasPrefix("-") || $0.hasPrefix("+") }) else {
            throw SearchFailure.input(BrowseLocalization.string("Use words or quoted phrases. Advanced search operators aren’t supported here.", locale: validationLocale))
        }
        let meaningful = trimmed.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard meaningful.unicodeScalars.count >= settings.minimumTermLength,
              meaningful.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else {
            throw SearchFailure.input(BrowseLocalization.format("Enter at least %ld characters to search.", locale: validationLocale, settings.minimumTermLength))
        }
        guard (1...10).contains(page) else { throw SearchFailure.input(BrowseLocalization.string("Refine your search to see more results.", locale: validationLocale)) }
        self.query = trimmed; self.scope = scope; self.page = page; locale = settings.locale
        allowedCategoryIDs = try scope.categoryIDs(in: catalog)
    }

    var queryItems: [URLQueryItem] {
        let scopedQuery = query + (scope.categoryID.map { " category:\($0.rawValue)" } ?? "")
        var items = [URLQueryItem(name: "q", value: scopedQuery), .init(name: "page", value: String(page))]
        if let id = scope.categoryID { items += [.init(name: "context", value: "category"), .init(name: "context_id", value: String(id.rawValue))] }
        return items
    }
}

struct DiscussionSearchHit: Identifiable, Hashable, Sendable {
    let id: PostID
    let discussion: DiscussionSummary
    let number: PostNumber
}

struct DiscussionSearchPage: Sendable {
    var items: [DiscussionSearchHit]
    var nextPage: Int?
    var reachedLimit = false
}

@MainActor extension SearchRepository {
    /// Existing callers still receive topic summaries; the adaptive UI uses the exact-hit API.
    func search(_ query: String, page: Int) async throws -> Page<DiscussionSummary> {
        let settings = try await searchSettings()
        let request = try DiscussionSearchRequest(query: query, scope: .all, page: page, settings: settings, catalog: [])
        let result = try await search(request)
        return Page(items: result.items.map(\.discussion), nextPage: result.nextPage)
    }
}
