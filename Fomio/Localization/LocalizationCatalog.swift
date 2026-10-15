import Foundation

/// CLDR plural categories. Catalog plural messages are keyed by these names.
enum PluralCategory: String, CaseIterable, Codable, Sendable, Comparable {
    case zero, one, two, few, many, other
    static func < (lhs: Self, rhs: Self) -> Bool { allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)! }
}

/// Interface writing direction carried by a catalog. Community content keeps its own direction.
enum CatalogDirection: String, Codable, Sendable { case ltr, rtl }

/// One complete interface catalog. Only catalogs that passed `CatalogValidator` (or the bundled English
/// reference) are ever activated, so lookups never fall through to blank labels.
struct LocalizationCatalog: Equatable, Sendable {
    /// Wire schema understood by this app version. A different schema is rejected, never partially read.
    static let schema = 1
    enum Message: Equatable, Sendable {
        case text(String)
        /// Selected by the `count` argument using `PluralRules`.
        case plural([PluralCategory: String])
    }
    /// Discourse locale code as resolved by the server (for example `ar`, `en`, `pt_BR`).
    var locale: String
    var revision: String
    var direction: CatalogDirection
    var messages: [String: Message]

    /// Formatting locale for numbers and dates. Discourse codes use `_`; Foundation accepts either.
    var formattingLocale: Locale { Locale(identifier: locale.replacingOccurrences(of: "_", with: "-")) }
    var language: String { LocaleMatcher.language(locale) }
}

/// The JSON contract shared by the bundled English file, the Debug fixture catalogs and the proposed
/// backend endpoint. See docs/localization-catalog-contract.md.
struct CatalogPayload: Codable, Sendable {
    var schema: Int
    var locale: String
    var revision: String
    var direction: String
    var complete: Bool
    var pluralCategories: [String]
    var messages: [String: Wire]
    enum CodingKeys: String, CodingKey { case schema, locale, revision, direction, complete, pluralCategories = "plural_categories", messages }
    enum Wire: Codable, Sendable, Equatable {
        case text(String)
        case plural([String: String])
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) { self = .text(text) }
            else { self = .plural(try container.decode([String: String].self)) }
        }
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self { case let .text(value): try container.encode(value); case let .plural(value): try container.encode(value) }
        }
    }
}

/// Server's list of interface languages. Only `complete` entries the app can validate are offered.
struct CatalogIndex: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var locale: String
        var name: String
        var nativeName: String
        var direction: String
        var complete: Bool
        var revision: String?
        enum CodingKeys: String, CodingKey { case locale, name, nativeName = "native_name", direction, complete, revision }
    }
    var schema: Int
    var defaultLocale: String
    var locales: [Entry]
    enum CodingKeys: String, CodingKey { case schema, defaultLocale = "default_locale", locales }
}

enum CatalogError: Error, Equatable, Sendable {
    case payloadTooLarge
    case malformed
    case unsupportedSchema(Int)
    case notComplete
    case localeMismatch(requested: String, resolved: String)
    case invalidDirection(String)
    case unsupportedPluralRules(String)
    case pluralCategoriesMismatch
    case missingKeys([String])
    case invalidMessage(key: String, reason: String)
}

/// Accepts a catalog only when it is complete and every message is compatible with the bundled English
/// reference: same message kind, allowed placeholders, required plural forms and no markup or raw keys.
enum CatalogValidator {
    static let maximumPayloadBytes = 1_000_000
    static let maximumMessageLength = 1_200
    static let maximumMessages = 6_000

    static func decode(_ data: Data) throws -> CatalogPayload {
        guard data.count <= maximumPayloadBytes else { throw CatalogError.payloadTooLarge }
        do { return try JSONDecoder().decode(CatalogPayload.self, from: data) } catch { throw CatalogError.malformed }
    }

    /// Validates a downloaded or cached catalog. `requested` is the Discourse locale the app asked for.
    static func validate(_ data: Data, requested: String?, reference: LocalizationCatalog) throws -> LocalizationCatalog {
        try validate(decode(data), requested: requested, reference: reference)
    }

    static func validate(_ payload: CatalogPayload, requested: String?, reference: LocalizationCatalog) throws -> LocalizationCatalog {
        guard payload.schema == LocalizationCatalog.schema else { throw CatalogError.unsupportedSchema(payload.schema) }
        guard payload.complete else { throw CatalogError.notComplete }
        guard LocaleMatcher.isValidCode(payload.locale), !payload.revision.isEmpty, payload.revision.count <= 128 else { throw CatalogError.malformed }
        // The server may resolve a region variant to its language, never to a different language.
        if let requested, LocaleMatcher.language(requested) != LocaleMatcher.language(payload.locale) {
            throw CatalogError.localeMismatch(requested: requested, resolved: payload.locale)
        }
        guard let direction = CatalogDirection(rawValue: payload.direction) else { throw CatalogError.invalidDirection(payload.direction) }
        guard let categories = PluralRules.categories(for: payload.locale) else { throw CatalogError.unsupportedPluralRules(payload.locale) }
        guard Set(payload.pluralCategories) == Set(categories.map(\.rawValue)) else { throw CatalogError.pluralCategoriesMismatch }
        guard payload.messages.count <= maximumMessages else { throw CatalogError.payloadTooLarge }
        let missing = reference.messages.keys.filter { payload.messages[$0] == nil }.sorted()
        guard missing.isEmpty else { throw CatalogError.missingKeys(missing) }

        var messages: [String: LocalizationCatalog.Message] = [:]
        // Keys unknown to this app version are ignored, so a newer server catalog stays usable.
        for (key, expected) in reference.messages {
            messages[key] = try message(key: key, wire: payload.messages[key]!, expected: expected, categories: categories)
        }
        return LocalizationCatalog(locale: payload.locale, revision: payload.revision, direction: direction, messages: messages)
    }

    /// The bundled English file uses the same contract; it is the placeholder and plural reference.
    static func reference(_ payload: CatalogPayload) throws -> LocalizationCatalog {
        guard payload.schema == LocalizationCatalog.schema, payload.complete, let direction = CatalogDirection(rawValue: payload.direction),
              let categories = PluralRules.categories(for: payload.locale), Set(payload.pluralCategories) == Set(categories.map(\.rawValue)) else { throw CatalogError.malformed }
        var messages: [String: LocalizationCatalog.Message] = [:]
        for (key, wire) in payload.messages {
            guard isValidKey(key) else { throw CatalogError.invalidMessage(key: key, reason: "key") }
            switch wire {
            case let .text(value): try checkText(key, value); messages[key] = .text(value)
            case let .plural(forms):
                var parsed: [PluralCategory: String] = [:]
                for (name, value) in forms {
                    guard let category = PluralCategory(rawValue: name), categories.contains(category) else { throw CatalogError.invalidMessage(key: key, reason: "plural category") }
                    try checkText(key, value); parsed[category] = value
                }
                guard Set(parsed.keys) == Set(categories), parsed[.other].map({ placeholders($0).contains("count") }) == true else { throw CatalogError.invalidMessage(key: key, reason: "plural forms") }
                messages[key] = .plural(parsed)
            }
        }
        return LocalizationCatalog(locale: payload.locale, revision: payload.revision, direction: direction, messages: messages)
    }

    private static func message(key: String, wire: CatalogPayload.Wire, expected: LocalizationCatalog.Message, categories: [PluralCategory]) throws -> LocalizationCatalog.Message {
        switch (expected, wire) {
        case let (.text(reference), .text(value)):
            try checkText(key, value)
            guard placeholders(value) == placeholders(reference) else { throw CatalogError.invalidMessage(key: key, reason: "placeholders") }
            return .text(value)
        case let (.plural(reference), .plural(forms)):
            let allowed = reference.values.reduce(into: Set<String>()) { $0.formUnion(placeholders($1)) }
            let required = allowed.subtracting(["count"])
            var parsed: [PluralCategory: String] = [:]
            for (name, value) in forms {
                guard let category = PluralCategory(rawValue: name) else { throw CatalogError.invalidMessage(key: key, reason: "plural category \(name)") }
                guard categories.contains(category) else { throw CatalogError.invalidMessage(key: key, reason: "plural category \(name) unused by locale") }
                try checkText(key, value)
                let used = placeholders(value)
                guard used.isSubset(of: allowed), required.isSubset(of: used) else { throw CatalogError.invalidMessage(key: key, reason: "placeholders") }
                parsed[category] = value
            }
            // Every category the language uses must be present; `other` must show the number.
            guard Set(parsed.keys) == Set(categories) else { throw CatalogError.invalidMessage(key: key, reason: "plural forms") }
            if allowed.contains("count"), parsed[.other].map({ placeholders($0).contains("count") }) != true { throw CatalogError.invalidMessage(key: key, reason: "plural other") }
            return .plural(parsed)
        default:
            throw CatalogError.invalidMessage(key: key, reason: "kind")
        }
    }

    static func isValidKey(_ key: String) -> Bool { key.range(of: #"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$"#, options: .regularExpression) != nil }

    /// Rejects blank values, markup, Discourse `%{}` interpolation, unbalanced braces and values that are
    /// themselves translation keys (the live site has an override whose value is the literal "js.hubs.all").
    static func checkText(_ key: String, _ value: String) throws {
        func fail(_ reason: String) -> CatalogError { .invalidMessage(key: key, reason: reason) }
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw fail("empty") }
        guard value.count <= maximumMessageLength else { throw fail("length") }
        guard !value.unicodeScalars.contains(where: { $0.properties.generalCategory == .control && $0 != "\n" }) else { throw fail("control") }
        guard value.range(of: #"<\s*/?\s*[A-Za-z]"#, options: .regularExpression) == nil else { throw fail("markup") }
        guard !value.contains("%{"), value.range(of: #"%(\d+\$)?[@dlsf]"#, options: .regularExpression) == nil else { throw fail("format") }
        guard !isValidKey(value.trimmingCharacters(in: .whitespaces)) else { throw fail("raw key") }
        var depth = 0
        for character in value {
            if character == "{" { depth += 1; if depth > 1 { throw fail("braces") } }
            if character == "}" { depth -= 1; if depth < 0 { throw fail("braces") } }
        }
        guard depth == 0 else { throw fail("braces") }
        let names = value.matches(of: /\{([^{}]*)\}/).map { String($0.1) }
        guard names.allSatisfy({ $0.range(of: #"^[a-z][A-Za-z0-9_]*$"#, options: .regularExpression) != nil }) else { throw fail("placeholder name") }
    }

    static func placeholders(_ value: String) -> Set<String> { Set(value.matches(of: /\{([a-z][A-Za-z0-9_]*)\}/).map { String($0.1) }) }
}

/// CLDR cardinal rules for integer counts. A locale without rules here cannot be activated, because its
/// plural forms could not be selected correctly. Add a language only together with its verification.
enum PluralRules {
    static func categories(for locale: String) -> [PluralCategory]? {
        switch LocaleMatcher.language(locale) {
        case "en": [.one, .other]
        case "ar": [.zero, .one, .two, .few, .many, .other]
        case "ja", "ko", "zh": [.other]
        default: nil
        }
    }
    static func category(_ count: Int, locale: String) -> PluralCategory {
        let n = abs(count)
        switch LocaleMatcher.language(locale) {
        case "ar":
            if n == 0 { return .zero }
            if n == 1 { return .one }
            if n == 2 { return .two }
            if (3...10).contains(n % 100) { return .few }
            if (11...99).contains(n % 100) { return .many }
            return .other
        case "ja", "ko", "zh": return .other
        default: return n == 1 ? .one : .other
        }
    }
}

/// Discourse locale code helpers. The app never maps device languages to site locales: the choice is manual.
enum LocaleMatcher {
    static func isValidCode(_ code: String) -> Bool { code.range(of: #"^[a-z]{2,3}(_[A-Za-z0-9]{2,8})?$"#, options: .regularExpression) != nil }
    static func language(_ code: String) -> String { String(code.split(whereSeparator: { $0 == "_" || $0 == "-" }).first ?? "").lowercased() }
}
