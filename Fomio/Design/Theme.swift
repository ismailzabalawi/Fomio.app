import SwiftUI

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
    /// Trait-aware light/dark colors with optional Increase Contrast variants.
    static func fomio(_ light: UInt32, _ dark: UInt32, lightHC: UInt32? = nil, darkHC: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark ? (high ? darkHC ?? dark : dark) : (high ? lightHC ?? light : light)
            return UIColor(Color(hex: value))
        })
    }
    static func hexValue(_ text: String?) -> UInt32? {
        guard let text else { return nil }
        let value = text.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return UInt32(value, radix: 16)
    }
    @MainActor private static func token(_ name: String, _ light: UInt32, _ dark: UInt32) -> Color {
        fomio(hexValue(FomioTheme.current.light[name]) ?? light, hexValue(FomioTheme.current.dark[name]) ?? dark)
    }
    @MainActor static var fomioText: Color { token("primary", 0x1B1A1F, 0xECEBF0) }
    @MainActor static var fomioAccent: Color { token("tertiary", 0x5B3FD6, 0xA58FFF) }
    @MainActor static var fomioOnAccent: Color {
        func ink(_ hex: UInt32) -> UInt32 {
            let channels = [Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)].map { value in
                let c = value / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722 > 0.179 ? 0x000000 : 0xFFFFFF
        }
        return fomio(ink(hexValue(FomioTheme.current.light["tertiary"]) ?? 0x5B3FD6), ink(hexValue(FomioTheme.current.dark["tertiary"]) ?? 0xA58FFF))
    }
    @MainActor static var fomioBackground: Color { token("secondary", 0xFFFFFF, 0x000000) }
    @MainActor static var fomioGrouped: Color { fomioBackground }
    @MainActor static var fomioCell: Color { fomioBackground }
    @MainActor static var fomioFill: Color { fomioText.opacity(0.055) }
    @MainActor static var fomioSecondaryText: Color { fomioText.opacity(0.72) }
    @MainActor static var fomioSeparator: Color { fomioText.opacity(0.16) }
    @MainActor static var fomioHighlight: Color { fomioAccent.opacity(0.12) }
    @MainActor static var fomioSelected: Color { fomioAccent.opacity(0.08) }
    @MainActor static var fomioDanger: Color { token("danger", 0xC62D3A, 0xFF6B78) }
    @MainActor static var fomioSuccess: Color { token("success", 0x1D7F4A, 0x4CD48A) }
    @MainActor static var fomioLove: Color { token("love", 0xD6245C, 0xFF5C8D) }

}
struct ReadingColumn<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.frame(maxWidth: 620).frame(maxWidth: .infinity) }
}
struct ScreenMessage: View {
    var title: String
    var message: String
    var symbol = "exclamationmark.bubble"
    var actionTitle: String? = nil
    var action: (() -> Void)?
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: { Text(message) } actions: {
            if let action { Button(actionTitle ?? L("common.try_again"), action: action).buttonStyle(.bordered).frame(minHeight: 44) }
        }
    }
}
/// Left-aligned explanatory card used for guest prompts, empty states and no-match hand-offs.
struct InfoCard<Actions: View>: View {
    var title: String?
    var message: String
    var symbol: String?
    @ViewBuilder var actions: Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Label { Text(title).font(.headline) } icon: { if let symbol { Image(systemName: symbol) } }.labelStyle(TitleWithOptionalIcon(hasIcon: symbol != nil)) }
            Text(message).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            actions
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.fomioFill, in: .rect(cornerRadius: 16))
    }
}
extension InfoCard where Actions == EmptyView {
    init(title: String?, message: String, symbol: String? = nil) { self.init(title: title, message: message, symbol: symbol) { EmptyView() } }
}
private struct TitleWithOptionalIcon: LabelStyle {
    var hasIcon: Bool
    func makeBody(configuration: Configuration) -> some View { HStack(spacing: 6) { if hasIcon { configuration.icon }; configuration.title } }
}
struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText).accessibilityAddTraits(.isHeader) }
}
struct Avatar: View {
    var name: String
    var size: CGFloat = 34
    static func initials(_ name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" }).prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
    var body: some View {
        Text(Self.initials(name)).font(size > 44 ? .title3.bold() : .caption.weight(.semibold)).foregroundStyle(Color.fomioAccent)
            .frame(width: size, height: size).background(Color.fomioHighlight, in: .circle).accessibilityHidden(true)
    }
}
/// Labels a post reached from somewhere specific. The label is text, not color alone.
struct FocusTag: View {
    var text: String
    var body: some View { Text(text).font(.caption.weight(.semibold)).foregroundStyle(Color.fomioAccent).padding(.horizontal, 10).padding(.vertical, 4).background(Color.fomioHighlight, in: .capsule) }
}
/// Wrapping row for subcommunity chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for index in row.indices { let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)); subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size)); x += size.width + spacing }
        }
    }
    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            if !rows[rows.count - 1].indices.isEmpty && rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]; rows.append(Row(y: last.y + last.height + spacing))
            }
            rows[rows.count - 1].width += (rows[rows.count - 1].indices.isEmpty ? 0 : spacing) + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            rows[rows.count - 1].indices.append(index)
        }
        return rows
    }
}
struct Chip: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 36).background(Color.fomioFill, in: .capsule) }
            .buttonStyle(.plain).frame(minHeight: 44)
    }
}
/// Placeholder rows that keep navigation usable while discussions load.
struct SkeletonRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4).frame(height: 16)
                    RoundedRectangle(cornerRadius: 4).frame(height: 12)
                    RoundedRectangle(cornerRadius: 4).frame(width: 160, height: 10)
                }.foregroundStyle(Color.fomioFill).padding(.horizontal, 20).padding(.vertical, 18)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(L("feed.loading")).accessibilityAddTraits(.updatesFrequently)
    }
}
struct ToastHost: ViewModifier {
    let message: String?
    var bottom: CGFloat = 96
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message).font(.subheadline.weight(.medium)).multilineTextAlignment(.center).padding(.horizontal, 18).padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule).padding(.horizontal, 24).padding(.bottom, bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity)).accessibilityAddTraits(.isStaticText)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
            }
        }.animation(.snappy, value: message)
    }
}
struct SamplePhoto: View {
    var name: String
    var body: some View {
        Image(name).resizable().scaledToFit().clipShape(.rect(cornerRadius: 14))
            .accessibilityLabel(Self.description(name))
    }
    /// Alt text of the fictional fixture photos; it stands in for server-provided image descriptions.
    static func description(_ name: String) -> String { DevText(name == "ph-walnut" ? "Close-up of a solid walnut table top" : name == "ph-fig" ? "Fig tree growing in a large container outdoors" : "Rigol oscilloscope and function generator on a bench") }
}
struct PhotoCreditsView: View {
    var body: some View {
        List {
            Section(DevText("Fixture photos · unedited")) {
                credit(DevText("Walnut table top"), "Martin Lorenz · CC BY-SA 3.0", "https://commons.wikimedia.org/wiki/File:Oberfl%C3%A4che_Wohnzimmertisch.JPG", "https://creativecommons.org/licenses/by-sa/3.0/")
                credit(DevText("Rigol oscilloscope"), "Dave Clausen · CC BY 2.0", "https://commons.wikimedia.org/wiki/File:Rigol_oscilloscope_DS_1052E.jpg", "https://creativecommons.org/licenses/by/2.0/")
                credit(DevText("Fig tree"), "Homoarborea · CC0 1.0", "https://commons.wikimedia.org/wiki/File:Ficus_carica_(1).jpg", "https://creativecommons.org/publicdomain/zero/1.0/")
            }
        }.navigationTitle(L("me.photo_credits"))
    }
    private func credit(_ title: String, _ attribution: String, _ source: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(attribution).font(.subheadline); Link(DevText("Original photo"), destination: URL(string: source)!); Link(DevText("License"), destination: URL(string: license)!) }.padding(.vertical, 6)
    }
}
/// A coarse elapsed time captured from a server timestamp. Formatting happens at display time with the
/// active catalog, so a language change re-renders ages without refetching. Fixtures use literals ("3h").
enum AgeValue: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    case none, now, minutes(Int), hours(Int), days(Int)
    init(seconds: TimeInterval) {
        let seconds = max(0, seconds)
        if seconds < 60 { self = .now } else if seconds < 3600 { self = .minutes(Int(seconds / 60)) }
        else if seconds < 86_400 { self = .hours(Int(seconds / 3600)) } else { self = .days(Int(seconds / 86_400)) }
    }
    init(_ date: Date, now: Date = .now) { self.init(seconds: now.timeIntervalSince(date)) }
    init(iso: String?, now: Date = .now) {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let iso, let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { self = .none; return }
        self.init(date, now: now)
    }
    /// Stable, language-neutral token: "", "now", "40m", "3h", "2d".
    init(stringLiteral value: String) { self.init(token: value) }
    init(token value: String) {
        guard let unit = value.last, let number = Int(value.dropLast()) else { self = value == "now" ? .now : .none; return }
        switch unit { case "m": self = .minutes(number); case "h": self = .hours(number); case "d": self = .days(number); default: self = .none }
    }
    var token: String {
        switch self { case .none: ""; case .now: "now"; case let .minutes(n): "\(n)m"; case let .hours(n): "\(n)h"; case let .days(n): "\(n)d" }
    }
    var isEmpty: Bool { self == .none }
    init(from decoder: any Decoder) throws { self.init(token: try decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: any Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(token) }
    /// Compact age for metadata rows ("3h", "now"); empty when unknown.
    var compact: String {
        switch self {
        case .none: ""
        case .now: L("time.compact.now")
        case let .minutes(n): L("time.compact.minutes", count: n)
        case let .hours(n): L("time.compact.hours", count: n)
        case let .days(n): L("time.compact.days", count: n)
        }
    }
}
enum RelativeAge {
    static func edited(_ date: Date, now: Date = .now) -> String {
        let age = AgeValue(date, now: now)
        return age == .now ? L("drafts.edited_now") : L("drafts.edited_ago", ["age": age.compact])
    }
}

/// App-wide site palette. Color providers capture immutable light/dark values for UIKit traits.
/// Refreshing AppState.siteTheme redraws mounted SwiftUI surfaces without resetting navigation.
@MainActor enum FomioTheme { static var current = SiteTheme() }

struct ScaledTitle: View {
    var text: String
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22
    init(_ text: String, size: CGFloat) { self.text = text; _size = ScaledMetric(wrappedValue: size, relativeTo: .title2) }
    var body: some View { Text(text).font(.system(size: size, weight: .bold)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader) }
}

/// Discourse identifiers are Font Awesome names, not SF Symbol names. Supported mappings are explicit;
/// unrecognized/custom names and failed assets use the category's own color square.
struct CategoryMark: View {
    @Environment(AppState.self) private var app
    @Environment(\.colorScheme) private var scheme
    let category: Community
    var size: CGFloat = 44
    var useLogo = false
    // Map server icon identifiers to native symbols; category names, colors and hierarchy stay server-owned.
    static let icons = [
        "bicycle": "bicycle", "gear": "gearshape", "wrench": "wrench", "hammer": "hammer",
        "microchip": "cpu", "seedling": "leaf", "leaf": "leaf", "screwdriver-wrench": "wrench.and.screwdriver",
        "paintbrush": "paintbrush", "comments": "bubble.left.and.bubble.right", "code": "chevron.left.forwardslash.chevron.right",
        "trophy": "trophy", "magnifying-glass": "magnifyingglass", "hand": "hand.wave",
        "desktop": "desktopcomputer", "chart-line": "chart.xyaxis.line", "palette": "paintpalette",
        "puzzle-piece": "puzzlepiece", "flask": "flask", "gavel": "building.columns", "cubes": "shippingbox",
        "circle-plus": "plus.circle", "rss": "dot.radiowaves.left.and.right", "book-open-reader": "book",
        "rocket": "paperplane", "headset": "headphones", "triangle-exclamation": "exclamationmark.triangle",
        "sun": "sun.max", "face-smile": "face.smiling", "lock": "lock"
    ]
    static let emoji = ["bike": "🚲", "bicyclist": "🚴", "seedling": "🌱", "hammer": "🔨", "wrench": "🔧", "thread": "🧵", "art": "🎨", "gear": "⚙️", "heart": "❤️"]
    var color: Color { Color.hexValue(category.identity.color).map(Color.init(hex:)) ?? .fomioAccent }
    private var logo: URL? {
        guard useLogo else { return nil }
        let asset = scheme == .dark ? category.identity.darkLogo ?? category.identity.logo : category.identity.logo
        return app.publicAssetURL(asset?.url)
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(color.opacity(0.14)).rotationEffect(.degrees(-7)).padding(2)
            if let logo {
                AsyncImage(url: logo) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().padding(5) } else if phase.error != nil { square } else { marker }
                }
            } else { marker }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
    @ViewBuilder private var marker: some View {
        if category.identity.style == "icon", let name = category.identity.icon, let symbol = Self.icons[name] {
            Image(systemName: symbol).font(.system(size: size * 0.46, weight: .semibold)).foregroundStyle(color)
        } else if category.identity.style == "emoji", let name = category.identity.emoji,
                  let resolved = Self.emoji[name.trimmingCharacters(in: CharacterSet(charactersIn: ":"))] ?? (name.unicodeScalars.contains(where: { $0.value > 127 }) ? name : nil) {
            Text(resolved).font(.system(size: size * 0.5))
        } else {
            square
        }
    }
    private var square: some View { RoundedRectangle(cornerRadius: size * 0.09).fill(color).frame(width: size * 0.4, height: size * 0.4) }
}
struct CategoryChip: View {
    @Environment(AppState.self) private var app
    let category: Community
    var body: some View {
        Button { app.navigate(.community(category.id)) } label: {
            HStack(spacing: 6) { CategoryMark(category: category, size: 24); Text(category.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading) }
                .padding(.horizontal, 10).padding(.vertical, 6).frame(minHeight: 44)
                .background(Color.fomioFill, in: .rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.fomioSeparator, lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityLabel(L("community.open", ["name": category.name]))
    }
}

struct CategoryHeading: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let category: Community
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            CategoryMark(category: category, size: 50, useLogo: true)
            ScaledTitle(category.name, size: 25).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
