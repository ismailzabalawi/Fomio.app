import SwiftUI

/// Layout is determined by readable column minima, never a device name or hinge angle.
/// Values follow the Adaptive Reading review at Standard text: list 300 + discussion 420,
/// sidebar from 1080, list up to 380 and a 260 sidebar.
struct ReadingLayout: Equatable {
    static let sidebarWidth: CGFloat = 260
    var scale: CGFloat
    var twoPanes: Bool
    var sidebar: Bool
    var listIdeal: CGFloat
    /// Set while a display division splits the window: the list fills the leading region exactly.
    var regionListWidth: CGFloat?
    var listMinimum: CGFloat { regionListWidth ?? 300 * scale }
    var listMaximum: CGFloat { regionListWidth ?? 380 * scale }
    init(width: CGFloat, scale: CGFloat) {
        self.scale = scale
        twoPanes = width >= (300 + 420) * scale
        sidebar = twoPanes && width >= 1080 * scale
        let available = width - (sidebar ? Self.sidebarWidth : 0)
        listIdeal = max(300 * scale, min(380 * scale, available * 0.36))
    }
    /// Within a display division (iPhone Duo's partial fold) each pane is a region: the list takes the
    /// leading region and the discussion the trailing one, never the band between. A region is held to a
    /// phone's reading width (320) rather than the 420 used beside the list, since it is its own surface.
    init(width: CGFloat, scale: CGFloat, regions: DivisionRegions?) {
        self.init(width: width, scale: scale)
        guard let regions else { return }
        sidebar = false
        twoPanes = regions.leading >= 300 * scale && regions.trailing >= 320 * scale
        if twoPanes { regionListWidth = regions.leading; listIdeal = regions.leading }
    }
    /// Minima grow more slowly than body text so larger sizes keep two panes longer:
    /// ×1.15 at a 23 pt body and ×1.6 at 34 pt, continuing that rate beyond.
    static func scale(for size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return scale(body: UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize)
    }
    static func scale(body: CGFloat) -> CGFloat {
        let ratio = body / 17, large: CGFloat = 23.0 / 17, accessibility: CGFloat = 34.0 / 17
        if ratio <= large { return max(1, 1 + (ratio - 1) * 0.15 / (large - 1)) }
        return 1.15 + (ratio - large) * 0.45 / (accessibility - large)
    }
}

struct CommunitySidebar: View {
    @Environment(AppState.self) private var app
    @Environment(\.locale) private var locale
    let scope: BrowseScope
    let select: (BrowseScope) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(AppTab.allCases) { tab in
                    let selected = app.selectedTab == tab
                    // The tab bar is hidden beside the sidebar, so the sidebar carries the server-scoped badge.
                    let badge = tab == .notifications ? app.notificationBadge : nil
                    let unread = badge == nil ? 0 : app.notifications.totals?.unread ?? 0
                    Button { app.selectedTab = tab } label: {
                        HStack(spacing: 8) {
                            Label(LocalizedStringKey(tab.title), systemImage: tab.symbol)
                                .font(.body.weight(selected ? .semibold : .regular))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let badge {
                                Text(badge).font(.footnote.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(selected ? Color.fomioAccent : Color.fomioOnAccent)
                                    .padding(.horizontal, 7).frame(minWidth: 22, minHeight: 22)
                                    .background(selected ? Color.fomioOnAccent : Color.fomioAccent, in: .capsule)
                            }
                        }
                        .foregroundStyle(selected ? Color.fomioOnAccent : Color.fomioText)
                        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(selected ? Color.fomioAccent : .clear, in: .rect(cornerRadius: 12)).contentShape(.rect)
                    }.buttonStyle(.plain)
                        .accessibilityElement(children: .ignore).accessibilityLabel(LocalizedStringKey(tab.title))
                        .accessibilityValue(unread == 0 ? "" : unread == 1 ? String(localized: "1 unread") : String(localized: "\(unread) unread"))
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("sidebar-tab-\(tab.rawValue)")
                }
                Text("Communities").font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
                    .padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 8).accessibilityAddTraits(.isHeader)
                row(name: BrowseLocalization.string("All communities", locale: locale), scope: .all, mark: AnyView(allMark))
                    .accessibilityIdentifier("sidebar-all")
                if app.communities.isEmpty && !app.communitiesLoaded && app.communityError == nil { ProgressView().accessibilityLabel("Loading communities") }
                if app.communityError != nil { Button("Retry communities") { Task { await app.loadCommunities() } }.frame(minHeight: 44) }
                ForEach(app.communities.filter { $0.parentID == nil && !$0.restricted }) { root in
                    row(name: root.name, scope: .category(root.id), mark: AnyView(CategoryMark(category: root, size: 24)))
                        .accessibilityIdentifier("sidebar-\(root.id.rawValue)")
                    // The active root's children, as in the directory and chooser.
                    if scope.categoryID == root.id || app.communities.contains(where: { $0.id == scope.categoryID && $0.parentID == root.id }) {
                        ForEach(app.communities.filter { $0.parentID == root.id && !$0.restricted }) { child in
                            row(name: child.name, scope: .category(child.id), mark: nil)
                                .accessibilityIdentifier("sidebar-\(child.id.rawValue)")
                        }
                    }
                }
            }.padding(.horizontal, 12).padding(.bottom, 16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                FomioWordmark(height: 26)
                Spacer(minLength: 8)
                Button { app.sidebarHidden = true } label: {
                    Image(systemName: "sidebar.squares.leading").font(.title3).foregroundStyle(Color.fomioSecondaryText)
                        .frame(width: 44, height: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityLabel("Hide sidebar").accessibilityIdentifier("hide-sidebar")
            }.padding(.leading, 20).padding(.trailing, 16).padding(.top, 12).padding(.bottom, 4)
                // Keep the header in the window's safe-area layout, outside the
                // scroll content whose corner insets do not reserve window controls.
                .containerCornerOffset(.horizontal, sizeToFit: true)
        }
        // A containing element keeps this identifier off the header's own controls.
        .background(Color.fomioFill).accessibilityElement(children: .contain).accessibilityIdentifier("community-sidebar")
    }
    private var allMark: some View {
        Image(systemName: "asterisk").font(.caption.weight(.bold)).foregroundStyle(Color.fomioSecondaryText)
            .frame(width: 24, height: 24).background(Color.fomioFill, in: .rect(cornerRadius: 7))
    }
    /// Roots carry their mark; children are indented without one. Selection fills the row with the accent.
    private func row(name: String, scope target: BrowseScope, mark: AnyView?) -> some View {
        let selected = scope == target
        let count = app.topicCount(target)
        return Button { select(target) } label: {
            HStack(spacing: 12) {
                if let mark { mark }
                Text(name).font(.body.weight(selected ? .semibold : .regular)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                if let count {
                    Text(count, format: .number).font(.footnote).monospacedDigit()
                        .foregroundStyle(selected ? Color.fomioOnAccent.opacity(0.88) : Color.fomioSecondaryText)
                }
            }.foregroundStyle(selected ? Color.fomioOnAccent : Color.fomioText)
                .padding(.leading, mark == nil ? 48 : 12).padding(.trailing, 12).padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(selected ? Color.fomioAccent : .clear, in: .rect(cornerRadius: 12)).contentShape(.rect)
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel(name)
            .accessibilityValue(count.map { $0 == 1 ? String(localized: "1 topic") : String(localized: "\($0) topics") } ?? "")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
extension EnvironmentValues {
    /// Whether the community sidebar sits beside this reading split; it then carries the wordmark.
    @Entry var readingSidebarVisible = false
    /// Present when the window could show the sidebar but the reader hid it.
    @Entry var readingShowSidebar: (() -> Void)? = nil
    /// Present while a topic feed's header, which carries Create, is off screen beside this discussion.
    @Entry var readingCreate: (() -> Void)? = nil
}

/// The regions either side of an active vertical display division, in the reading root's width.
struct DivisionRegions: Equatable {
    var leading: CGFloat
    var band: CGFloat
    var trailing: CGFloat
    init?(division: CGRect?, width: CGFloat) {
        guard let division, division.minX > 0, division.maxX < width else { return nil }
        leading = division.minX; band = division.width; trailing = width - division.maxX
    }
}

/// Reports the display's active vertical division (iPhone Duo's partial fold) in this view's
/// coordinates, so the reading split can keep panes, controls and text out of the hinge band.
/// The window keeps its size across that fold, so the division is read from UIKit, not from geometry.
struct DisplayDivisionReader: UIViewRepresentable {
    let onChange: (CGRect?) -> Void
    func makeUIView(context: Context) -> Probe { let probe = Probe(); probe.isUserInteractionEnabled = false; probe.onChange = onChange; return probe }
    func updateUIView(_ probe: Probe, context: Context) { probe.onChange = onChange; probe.report() }
    final class Probe: UIView {
        var onChange: ((CGRect?) -> Void)?
        private var reported: CGRect?? = .none
        override func layoutSubviews() { super.layoutSubviews(); report() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); report() }
        override func didMoveToWindow() { super.didMoveToWindow(); report() }
        func report() {
            var division: CGRect?
            if #available(iOS 27.1, *), window != nil {
                division = reservedRegions(kind: .division).first { $0.isActive && $0.frame.height > $0.frame.width }?.frame
            }
            guard reported != .some(division) else { return }
            reported = .some(division)
            DispatchQueue.main.async { [weak self] in self?.onChange?(division) }
        }
    }
}

extension ToolbarContent {
    /// Which bar items stay direct when the system compresses the bar (iPhone Duo's short or folded
    /// vertical bar): the reviewed order keeps Back and the primary action, and moves secondary ones first.
    @ToolbarContentBuilder func barPriority(_ high: Bool) -> some ToolbarContent {
        if #available(iOS 27.0, *) { visibilityPriority(high ? .high : .low) } else { self }
    }
}
