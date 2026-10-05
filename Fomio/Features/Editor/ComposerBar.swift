import SwiftUI

/// Contextual floating composer bar: + inserts a block, the type chip changes the current block,
/// and a selection swaps the centre to formatting. It reflects editor state; it never owns it.
struct ComposerBar<More: View>: View {
    enum Mode: Equatable {
        /// Nothing written into yet: insert, More and Show keyboard.
        case entry
        case title
        case write(ComposerTextStyle?)
        case selection(ComposerTextStyle?)
        case turnInto(ComposerTextStyle)
    }
    struct Actions {
        var insert: () -> Void
        var openTurnInto: () -> Void
        var closeTurnInto: () -> Void
        var turnInto: (ComposerTextStyle) -> Void
        var bold: () -> Void
        var italic: () -> Void
        var link: () -> Void
        var quote: () -> Void
        var done: () -> Void
        var keyboard: () -> Void
        var undo: () -> Void
        var redo: () -> Void
    }
    var mode: Mode
    var editing: Bool
    var bold: Bool
    var italic: Bool
    var canUndo: Bool
    var canRedo: Bool
    var canFormatInline: Bool
    var actions: Actions
    /// Labelled More for the compact fallback, icon-only More for the full row.
    @ViewBuilder var more: (_ labelled: Bool) -> More
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    private let target: CGFloat = 44

    var body: some View {
        Group {
            if case let .turnInto(current) = mode { turnIntoStrip(current) }
            else if dynamicType.isAccessibilitySize {
                row(compact: true, link: false, minimal: true)
            } else {
                // Widest first: Link at a paragraph caret when it fits, then without it, then the large-text row.
                ViewThatFits(in: .horizontal) {
                    row(compact: false, link: true)
                    row(compact: false, link: false)
                    row(compact: true, link: false)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: max(52, target + 8))
        .background { surface }
        .frame(maxWidth: sizeClass == .regular ? 620 : .infinity)
        .padding(.horizontal, 12).padding(.bottom, 8)
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: mode)
        .tint(Color.fomioAccent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Formatting")
    }
    // MARK: Rows
    private func row(compact: Bool, link: Bool, minimal: Bool = false) -> some View {
        HStack(spacing: 0) {
            insertButton
            if !minimal { centre(compact: compact, link: link) }
            Spacer(minLength: 4)
            if sizeClass == .regular, !compact, mode != .title {
                icon("Undo", "arrow.uturn.backward", action: actions.undo).disabled(!canUndo).opacity(canUndo ? 1 : 0.35)
                icon("Redo", "arrow.uturn.forward", action: actions.redo).disabled(!canRedo).opacity(canRedo ? 1 : 0.35)
            }
            if mode != .title { more(compact && !minimal).fixedSize().frame(minWidth: target, minHeight: target) }
            trailing
        }
    }
    @ViewBuilder private func centre(compact: Bool, link: Bool) -> some View {
        switch mode {
        case .entry, .turnInto: EmptyView()
        case .title:
            Text("Title · plain text").font(.subheadline).foregroundStyle(Color.fomioSecondaryText).lineLimit(1).padding(.horizontal, 8)
        case let .write(style):
            if let style {
                if !compact { typeChip(style) }
                if canFormatInline {
                    toggle("Bold", "bold", on: bold, action: actions.bold)
                    toggle("Italic", "italic", on: italic, action: actions.italic)
                    if link || (sizeClass == .regular && !compact) { icon("Link", "link", action: actions.link) }
                }
            }
        case let .selection(style):
            if canFormatInline {
                toggle("Bold", "bold", on: bold, action: actions.bold)
                toggle("Italic", "italic", on: italic, action: actions.italic)
                icon("Link", "link", action: actions.link)
            }
            if !compact, style != nil { toggle("Quote", "text.quote", on: style == .quote, action: actions.quote) }
        }
    }
    @ViewBuilder private var trailing: some View {
        if case .selection = mode {
            Button(action: actions.done) { Text("Done").font(.body.weight(.semibold)).foregroundStyle(Color.fomioAccent).padding(.horizontal, 10).frame(minWidth: target, minHeight: target).contentShape(.rect) }
                .buttonStyle(.plain).accessibilityHint("Keeps the selected text and places the cursor after it").accessibilityIdentifier("composer-selection-done")
        } else {
            iconButton(editing ? "Hide keyboard" : "Show keyboard", editing ? "keyboard.chevron.compact.down" : "keyboard", tint: Color.fomioAccent, action: actions.keyboard)
                .accessibilityIdentifier("composer-keyboard")
        }
    }
    // MARK: Controls
    private var insertButton: some View {
        Button(action: actions.insert) {
            Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                .frame(width: target - 8, height: target - 8).background(Color.fomioAccent, in: .circle)
                .frame(width: target, height: target).contentShape(.rect)
        }
        .buttonStyle(.plain).disabled(mode == .title).opacity(mode == .title ? 0.35 : 1)
        .accessibilityLabel("Add block").accessibilityIdentifier("composer-insert")
    }
    /// Names the current block; tapping changes it. The outline separates it from the filled +, which adds.
    private func typeChip(_ style: ComposerTextStyle) -> some View {
        Button(action: actions.openTurnInto) {
            HStack(spacing: 4) {
                Text(style.title).lineLimit(1)
                if sizeClass == .regular { Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).accessibilityHidden(true) }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fomioAccent)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .overlay { Capsule().strokeBorder(Color.fomioAccent, lineWidth: 1.5) }
            .frame(minHeight: target).contentShape(.rect)
        }
        .buttonStyle(.plain).padding(.horizontal, 4)
        .accessibilityLabel(Text("Turn into: \(style.title)")).accessibilityIdentifier("composer-block-type")
    }
    private func toggle(_ title: LocalizedStringKey, _ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(on ? Color.fomioAccent : Color.primary)
                .frame(width: target - 8, height: target - 8)
                .background(on ? Color.fomioHighlight : .clear, in: .rect(cornerRadius: 10))
                .frame(width: target, height: target).contentShape(.rect)
        }
        .buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(on ? .isSelected : [])
    }
    private func icon(_ title: LocalizedStringKey, _ symbol: String, action: @escaping () -> Void) -> some View {
        iconButton(title, symbol, tint: .primary, action: action)
    }
    /// The 44 pt frame sits inside the label so the whole target is tappable, not only the glyph.
    private func iconButton(_ title: LocalizedStringKey, _ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                .frame(minWidth: target, minHeight: target).contentShape(.rect)
        }
        .buttonStyle(.plain).accessibilityLabel(title)
    }
    // MARK: Turn into
    private func turnIntoStrip(_ current: ComposerTextStyle) -> some View {
        HStack(spacing: 0) {
            iconButton("Close Turn into", "xmark", tint: .primary, action: actions.closeTurnInto)
                .accessibilityIdentifier("composer-turn-into-close")
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        Text("Turn into").font(.footnote).foregroundStyle(Color.fomioSecondaryText).padding(.horizontal, 4).accessibilityAddTraits(.isHeader)
                        ForEach(ComposerTextStyle.offered + (ComposerTextStyle.offered.contains(current) ? [] : [current]), id: \.self) { style in
                            let selected = style == current
                            Button { actions.turnInto(style) } label: {
                                Text(style.title).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selected ? Color.fomioAccent : Color.primary)
                                    .padding(.horizontal, 12).frame(minHeight: 32)
                                    .background(selected ? Color.fomioHighlight : Color.fomioFill, in: .capsule)
                                    .frame(minHeight: target).contentShape(.rect)
                            }
                            .buttonStyle(.plain).id(style)
                            .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("composer-turn-into-\(style.title)")
                        }
                    }.padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(current, anchor: .center) }
            }
        }
    }
    @ViewBuilder private var surface: some View {
        if reduceTransparency {
            Capsule().fill(Color.fomioCell).overlay { Capsule().strokeBorder(Color.fomioSeparator) }
        } else {
            Color.clear.glassEffect(.regular, in: .capsule)
        }
    }
}

/// + opens this sheet. It names where the block will go and only lists what this site supports.
struct ComposerInserter: View {
    enum Choice: Hashable { case text(ComposerTextStyle), photo, samplePhoto, block(ComposerBlockKind) }
    var placement: String
    var blocks: [ComposerBlockKind]
    var samplePhoto: Bool
    var pick: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private struct Item: Identifiable { var choice: Choice; var title: String; var symbol: String; var id: Choice { choice } }
    private var sections: [(String, [Item])] {
        let text = ComposerTextStyle.offered.map { Item(choice: .text($0), title: $0.title, symbol: $0.symbol) }
        var media = [Item(choice: .photo, title: String(localized: "Photo"), symbol: "photo")]
        if samplePhoto { media.append(Item(choice: .samplePhoto, title: String(localized: "Sample photo"), symbol: "photo.badge.checkmark")) }
        let advanced = blocks.map { Item(choice: .block($0), title: String(localized: String.LocalizationValue($0.title)), symbol: Self.symbol($0)) }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return [(String(localized: "Text"), text), (String(localized: "Media"), media), (String(localized: "Advanced"), advanced)].map { title, items in
            (title, trimmed.isEmpty ? items : items.filter { $0.title.localizedStandardContains(trimmed) })
        }.filter { !$0.1.isEmpty }
    }
    var body: some View {
        NavigationStack {
            List {
                Section { Text(placement).font(.subheadline).foregroundStyle(Color.fomioSecondaryText).accessibilityIdentifier("composer-insert-placement") }
                ForEach(sections, id: \.0) { title, items in
                    Section(title) {
                        ForEach(items) { item in
                            Button { pick(item.choice) } label: { Label(item.title, systemImage: item.symbol).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(.rect) }
                                .foregroundStyle(.primary)
                        }
                    }
                }
                if sections.isEmpty { Text("No block matches “\(query)”.").foregroundStyle(Color.fomioSecondaryText) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search blocks"))
            .navigationTitle("Add block").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() }.accessibilityIdentifier("composer-insert-cancel") } }
        }
        .presentationDetents([.medium, .large])
    }
    private static func symbol(_ kind: ComposerBlockKind) -> String {
        switch kind {
        case .poll: "chart.bar.xaxis"
        case .table: "tablecells"
        case .details: "chevron.down.square"
        case .spoiler: "eye.slash"
        case .date: "calendar"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .quote: "quote.opening"
        case .photo: "photo"
        case .opaque: "square.dashed"
        }
    }
}
