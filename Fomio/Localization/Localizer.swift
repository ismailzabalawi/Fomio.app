import Foundation
import Observation
import Synchronization
import SwiftUI
import UIKit

/// The active interface catalog. Reads are thread-safe and register SwiftUI Observation dependencies,
/// so views reading `L(...)` redraw in place when a catalog activates; view identity, navigation,
/// drafts and editor selection are untouched.
final class Localizer: Observable, Sendable {
    static let shared = Localizer(english: Localizer.bundledEnglish(), drivesUIKit: true)
    let english: LocalizationCatalog
    /// Only the app's shared localizer sets UIKit's global direction; test instances never do.
    let drivesUIKit: Bool
    private let registrar = ObservationRegistrar()
    private let storage: Mutex<LocalizationCatalog>

    init(english: LocalizationCatalog, drivesUIKit: Bool = false) { self.english = english; self.drivesUIKit = drivesUIKit; storage = Mutex(english) }

    var catalog: LocalizationCatalog {
        registrar.access(self, keyPath: \.catalog)
        return storage.withLock { $0 }
    }
    var formattingLocale: Locale { catalog.formattingLocale }
    var layoutDirection: LayoutDirection { catalog.direction == .rtl ? .rightToLeft : .leftToRight }
    /// Explicit UIKit direction for app-owned UIKit views. Never `.unspecified`: on a device whose system
    /// language is right-to-left, unspecified would mirror an English interface.
    var uikitAttribute: UISemanticContentAttribute { catalog.direction == .rtl ? .forceRightToLeft : .forceLeftToRight }

    /// Activates an already validated catalog. Call on the main actor so SwiftUI observes one transaction.
    @MainActor func activate(_ value: LocalizationCatalog) {
        // UIKit-presented surfaces (menus, the editor's attachment cards) are created from UIKit's own
        // direction, so it is set for every activation, including the initial English fallback at launch
        // (which equals the stored catalog). Existing SwiftUI views follow LocalizationEnvironment.
        if drivesUIKit {
            UIView.appearance().semanticContentAttribute = value.direction == .rtl ? .forceRightToLeft : .forceLeftToRight
            Self.applyBackIndicator(value.direction)
        }
        guard storage.withLock({ $0 }) != value else { return }
        registrar.withMutation(of: self, keyPath: \.catalog) { storage.withLock { $0 = value } }
    }

    /// The back indicator image a navigation bar should use, or nil to keep the system's own chevron.
    /// UIKit mirrors the indicator whenever the app's system direction (its preferred bundle localization,
    /// which follows the iOS language) is right-to-left, independent of the interface. Observed on iOS 26.1:
    /// Arabic iOS + English interface drew the default chevron pointing right. When the directions differ, a
    /// fixed glyph is supplied so that UIKit's mirroring yields the interface's direction; when they match,
    /// the system chevron is left untouched.
    static func backIndicatorSymbol(interface: CatalogDirection, systemRightToLeft: Bool) -> String? {
        let interfaceRightToLeft = interface == .rtl
        guard interfaceRightToLeft != systemRightToLeft else { return nil }
        // Mismatch: system RTL mirrors "chevron.right" into a left chevron for an LTR interface; system LTR
        // leaves "chevron.right" as the right chevron an RTL interface needs. Either way the glyph is the same.
        return "chevron.right"
    }
    static var systemIsRightToLeft: Bool {
        Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en").characterDirection == .rightToLeft
    }
    /// The native back button, its title, accessibility and interactive pop gesture are kept; only the indicator
    /// image changes. Bars created afterwards use it (the tab container rebuilds on a direction change).
    @MainActor static func applyBackIndicator(_ direction: CatalogDirection) {
        let image = backIndicatorSymbol(interface: direction, systemRightToLeft: systemIsRightToLeft)
            .flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .large)) }
        let bar = UINavigationBar.appearance()
        bar.backIndicatorImage = image; bar.backIndicatorTransitionMaskImage = image
    }

    /// Resolves a key. Arguments are inserted as text; `count` selects the plural form and is formatted
    /// with the catalog's locale.
    func string(_ key: String, count: Int? = nil, _ arguments: [(String, String)] = []) -> String {
        let active = catalog
        let message = active.messages[key] ?? english.messages[key]
        guard let message else {
            assertionFailure("Missing localization key \(key)")
            return key
        }
        let template = Self.template(message, count: count, locale: active.locale)
        return Self.anchor(template, in: active.direction) + Self.format(template, count: count, arguments: arguments, catalog: active)
    }
    /// An RTL message that begins with an argument (for example "{parent} › {community}") has no strong
    /// right-to-left letter before its isolated arguments, so its paragraph would fall back to left-to-right.
    /// A leading right-to-left mark keeps the interface order; it is invisible and not spoken.
    static func anchor(_ template: String, in direction: CatalogDirection) -> String {
        direction == .rtl && template.first == "{" ? "\u{200F}" : ""
    }

    /// Splits a resolved message into literal and argument segments, for styled SwiftUI `Text`.
    func segments(_ key: String, count: Int? = nil, _ arguments: [(String, String)] = []) -> [(text: String, argument: String?)] {
        let active = catalog
        guard let message = active.messages[key] ?? english.messages[key] else { assertionFailure("Missing localization key \(key)"); return [(key, nil)] }
        let template = Self.template(message, count: count, locale: active.locale)
        var result: [(String, String?)] = []
        let mark = Self.anchor(template, in: active.direction)
        if !mark.isEmpty { result.append((mark, nil)) }
        var rest = Substring(template)
        while let match = rest.firstMatch(of: /\{([a-z][A-Za-z0-9_]*)\}/) {
            if match.range.lowerBound > rest.startIndex { result.append((String(rest[rest.startIndex..<match.range.lowerBound]), nil)) }
            let name = String(match.1)
            result.append((Self.value(name, count: count, arguments: arguments, catalog: active), name))
            rest = rest[match.range.upperBound...]
        }
        if !rest.isEmpty { result.append((String(rest), nil)) }
        return result
    }

    private static func template(_ message: LocalizationCatalog.Message, count: Int?, locale: String) -> String {
        switch message {
        case let .text(value): return value
        case let .plural(forms): return forms[PluralRules.category(count ?? 0, locale: locale)] ?? forms[.other] ?? ""
        }
    }
    private static func value(_ name: String, count: Int?, arguments: [(String, String)], catalog: LocalizationCatalog) -> String {
        if name == "count", let count { return count.formatted(.number.locale(catalog.formattingLocale)) }
        guard let value = arguments.first(where: { $0.0 == name })?.1 else { return "" }
        return isolate(value, in: catalog.direction)
    }
    static func format(_ template: String, count: Int?, arguments: [(String, String)], catalog: LocalizationCatalog) -> String {
        template.replacing(/\{([a-z][A-Za-z0-9_]*)\}/) { value(String($0.1), count: count, arguments: arguments, catalog: catalog) }
    }
    /// Wraps an argument in Unicode first-strong isolates when it contains letters of the opposite direction,
    /// so a Latin username inside Arabic interface text (or an Arabic title inside English text) keeps its order.
    static func isolate(_ value: String, in direction: CatalogDirection) -> String {
        let opposite = value.unicodeScalars.contains { scalar in
            guard scalar.properties.isAlphabetic else { return false }
            return isRightToLeft(scalar) != (direction == .rtl)
        }
        return opposite ? "\u{2068}\(value)\u{2069}" : value
    }
    static func isRightToLeft(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x0590...0x08FF).contains(value) || (0xFB1D...0xFDFF).contains(value) || (0xFE70...0xFEFF).contains(value)
    }

    static func bundledEnglish(bundle: Bundle = .main) -> LocalizationCatalog {
        // The English catalog is part of the app build and covered by tests; without it there is no interface text.
        guard let url = bundle.url(forResource: "fomio-catalog-en", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? CatalogValidator.reference(CatalogValidator.decode(data)) else {
            preconditionFailure("The bundled English localization catalog is missing or invalid.")
        }
        return catalog
    }
}

/// Interface text for a semantic key from the active catalog.
func L(_ key: String) -> String { Localizer.shared.string(key) }
/// Interface text with named text arguments, for example `L("access.message", ["name": community])`.
func L(_ key: String, _ arguments: KeyValuePairs<String, String>) -> String { Localizer.shared.string(key, arguments.map { ($0.key, $0.value) }) }
/// Plural interface text; `count` selects the form and is formatted for the active locale.
func L(_ key: String, count: Int, _ arguments: KeyValuePairs<String, String> = [:]) -> String { Localizer.shared.string(key, count: count, arguments.map { ($0.key, $0.value) }) }

/// Styled interface text: arguments named in `emphasis` are passed through `style`, the rest stays plain.
func LText(_ key: String, count: Int? = nil, _ arguments: KeyValuePairs<String, String> = [:], style: (String, Text) -> Text) -> Text {
    Localizer.shared.segments(key, count: count, arguments.map { ($0.key, $0.value) }).reduce(Text(verbatim: "")) { result, segment in
        let piece = Text(verbatim: segment.text)
        return Text("\(result)\(segment.argument.map { style($0, piece) } ?? piece)")
    }
}
/// Whole-message emphasis for a leading phrase: `LText(lead:rest:)` renders "**lead** rest" with one key each.
func LText(lead: String, rest: String) -> Text { Text("\(Text(verbatim: L(lead)).bold()) \(Text(verbatim: L(rest)))") }

/// Development-only English copy (fixture controls, fixture banner, fixture photo credits). These surfaces are
/// unreachable in Release builds and are intentionally outside the translated catalog.
func DevText(_ value: String) -> String { value }

/// Applies the active catalog's formatting locale and layout direction together at a presentation root.
struct LocalizationEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        let localizer = Localizer.shared
        content.environment(\.locale, localizer.formattingLocale).environment(\.layoutDirection, localizer.layoutDirection)
    }
}
