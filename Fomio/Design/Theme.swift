import SwiftUI

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
    /// Fomio web tokens: light, AMOLED dark, and their Increase Contrast variants.
    static func fomio(_ light: UInt32, _ dark: UInt32, lightHC: UInt32? = nil, darkHC: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark ? (high ? darkHC ?? dark : dark) : (high ? lightHC ?? light : light)
            return UIColor(Color(hex: value))
        })
    }
    static let fomioAccent = fomio(0x5B3FD6, 0xA58FFF, lightHC: 0x4A2FBF, darkHC: 0xBFAFFF)
    static let fomioBackground = fomio(0xFFFFFF, 0x000000)
    static let fomioGrouped = fomio(0xF4F3F7, 0x000000)
    static let fomioCell = fomio(0xFFFFFF, 0x111114)
    static let fomioFill = fomio(0xF4F3F7, 0x17161C)
    static let fomioSecondaryText = fomio(0x5E5C67, 0xAEACB8, lightHC: 0x45434D, darkHC: 0xCFCDD8)
    static let fomioSeparator = fomio(0xE2E0E8, 0x2A2831, lightHC: 0xA9A6B4, darkHC: 0x5A5863)
    static let fomioHighlight = fomio(0xE7E0FF, 0x2B2257)
    static let fomioSelected = fomio(0xEEEBFA, 0x1B1826)
    static let fomioDanger = fomio(0xC62D3A, 0xFF6B78)
    static let fomioSuccess = fomio(0x1D7F4A, 0x4CD48A)
    static let fomioLove = fomio(0xD6245C, 0xFF5C8D)
}
struct ReadingColumn<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.frame(maxWidth: 620).frame(maxWidth: .infinity) }
}
struct ScreenMessage: View {
    var title: String
    var message: String
    var symbol = "exclamationmark.bubble"
    var actionTitle = "Try again"
    var action: (() -> Void)?
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: { Text(message) } actions: {
            if let action { Button(actionTitle, action: action).buttonStyle(.bordered).frame(minHeight: 44) }
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
/// Letter tile used while Discourse category logos are unconfirmed.
struct Monogram: View {
    var name: String
    var size: CGFloat = 40
    var body: some View {
        Text(String(name.prefix(1)).uppercased()).font(size > 44 ? .title2.bold() : size < 32 ? .footnote.bold() : .headline).foregroundStyle(Color.fomioAccent)
            .frame(width: size, height: size).background(Color.fomioHighlight, in: .rect(cornerRadius: size * 0.26)).accessibilityHidden(true)
    }
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
            for index in row.indices { let size = subviews[index].sizeThatFits(.unspecified); subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size)); x += size.width + spacing }
        }
    }
    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
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
        }.accessibilityElement(children: .ignore).accessibilityLabel("Loading discussions").accessibilityAddTraits(.updatesFrequently)
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
    static func description(_ name: String) -> String { name == "ph-walnut" ? "Close-up of a solid walnut table top" : name == "ph-fig" ? "Fig tree growing in a large container outdoors" : "Rigol oscilloscope and function generator on a bench" }
}
struct PhotoCreditsView: View {
    var body: some View {
        List {
            Section("Fixture photos · unedited") {
                credit("Walnut table top", "Martin Lorenz · CC BY-SA 3.0", "https://commons.wikimedia.org/wiki/File:Oberfl%C3%A4che_Wohnzimmertisch.JPG", "https://creativecommons.org/licenses/by-sa/3.0/")
                credit("Rigol oscilloscope", "Dave Clausen · CC BY 2.0", "https://commons.wikimedia.org/wiki/File:Rigol_oscilloscope_DS_1052E.jpg", "https://creativecommons.org/licenses/by/2.0/")
                credit("Fig tree", "Homoarborea · CC0 1.0", "https://commons.wikimedia.org/wiki/File:Ficus_carica_(1).jpg", "https://creativecommons.org/publicdomain/zero/1.0/")
            }
        }.navigationTitle("Photo credits")
    }
    private func credit(_ title: String, _ attribution: String, _ source: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(attribution).font(.subheadline); Link("Original photo", destination: URL(string: source)!); Link("License", destination: URL(string: license)!) }.padding(.vertical, 6)
    }
}
enum RelativeAge {
    static func string(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
    static func string(iso: String?) -> String {
        guard let iso else { return "" }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        return string(date)
    }
    static func edited(_ date: Date, now: Date = .now) -> String {
        let value = string(date, now: now)
        if value == "now" { return "Edited just now" }
        let unit = value.last == "m" ? "m" : value.last == "h" ? "h" : "d"
        return "Edited \(value.dropLast())\(unit) ago"
    }
}
