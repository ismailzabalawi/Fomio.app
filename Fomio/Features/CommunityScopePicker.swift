import SwiftUI

struct CommunityScopePicker: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var direction
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var presentation: Presentation?
    @State private var query = ""
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var searchSymbolSize = 20.0
    /// The list title: 24 pt bold at Standard text, growing with the title style.
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0
    let scope: BrowseScope
    /// Incremented by a caller (such as an empty community) to open the chooser.
    var request = 0
    let select: (BrowseScope) -> Void
    private var name: String {
        guard let id = scope.categoryID else { return BrowseLocalization.string("All communities", locale: locale) }
        return app.category(id)?.name ?? BrowseLocalization.string("Community unavailable", locale: locale)
    }
    var body: some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name).font(.system(size: titleSize, weight: .bold)).tracking(-0.24)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down").font(.system(size: titleSize * 0.6, weight: .bold))
                    .foregroundStyle(Color.fomioAccent).accessibilityHidden(true)
            }.foregroundStyle(Color.fomioText).frame(minHeight: 44, alignment: .leading).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel(BrowseLocalization.format("Community: %@. Change community", locale: locale, name)).accessibilityIdentifier("community-scope")
        .accessibilityAddTraits(.isHeader)
        .onChange(of: request) { open() }
        // A popover at two-pane Standard text, a sheet at compact width or Large/AX text.
        // The style is fixed when the chooser opens, so one presentation owns it throughout
        // a window resize; bindings derived from live traits could dismiss each other.
        .popover(isPresented: presented(.popover)) {
            chooser.frame(idealWidth: 360, idealHeight: 520)
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: presented(.sheet)) {
            chooser.presentationSizing(.form)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }
    private func open() { query = ""; presentation = sizeClass == .regular && textSize < .xxxLarge ? .popover : .sheet }
    private enum Presentation { case popover, sheet }
    private func presented(_ style: Presentation) -> Binding<Bool> {
        Binding(get: { presentation == style }, set: { if !$0 && presentation == style { presentation = nil } })
    }
    private var chooser: some View {
        NavigationStack {
            List {
                Button { choose(.all) } label: { choice(name: BrowseLocalization.string("All communities", locale: locale), selected: scope == .all) }
                    .accessibilityIdentifier("scope-all")
                if !app.communitiesLoaded && app.communities.isEmpty && app.communityError == nil { ProgressView().accessibilityLabel("Loading communities") }
                if let error = app.communityError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Community list unavailable").font(.headline)
                        Text(BrowseLocalization.string(error, locale: locale)).font(.subheadline)
                        Button("Retry") { Task { await app.loadCommunities() } }.frame(minHeight: 44)
                            .accessibilityIdentifier("retry-community-list")
                    }
                }
                if let current = matchingCurrent {
                    Section("Current community") {
                        if let parent = current.parentID.flatMap(app.category), !parent.restricted {
                            Text(parent.name).font(.caption).foregroundStyle(Color.fomioSecondaryText)
                                .accessibilityIdentifier("current-community-parent")
                        }
                        scopeRow(current, parent: current.parentID.flatMap(app.category)?.name)
                    }
                }
                ForEach(roots) { root in
                    let children = visibleChildren(root)
                    if matches(root) || !children.isEmpty {
                        Section {
                            scopeRow(root, parent: nil)
                            ForEach(children) { child in scopeRow(child, parent: root.name) }
                        }
                    }
                }
                if !query.isEmpty && matchingCurrent == nil && !roots.contains(where: { matches($0) || !visibleChildren($0).isEmpty }) {
                    Text(BrowseLocalization.string(app.communityError == nil && app.communitiesLoaded ? "No communities match" : "No matches in loaded communities", locale: locale))
                        .foregroundStyle(.secondary)
                }
            }.listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Choose community").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                let layout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                layout {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: min(searchSymbolSize, 28)))
                            .foregroundStyle(.secondary).accessibilityHidden(true)
                        // Vertical like the topic search field: it sizes with Dynamic Type, where the
                        // single-line field's UIKit backing fails the text-clipping audit. Return still means Done.
                        TextField("Find communities", text: Binding(get: { query }, set: { value in
                            // Ending focus inside the text change is ignored in an iPad popover; defer it a turn.
                            if value.contains("\n") {
                                query = value.replacingOccurrences(of: "\n", with: "")
                                // Return is a newline in this vertical field; a focus change alone can leave the keyboard up in a popover.
                                Task { @MainActor in focused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                            }
                            else { query = value }
                        }), axis: .vertical).focused($focused)
                            .lineLimit(1...3).font(.body).frame(minHeight: 44)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.done).onSubmit { focused = false }
                            .accessibilityIdentifier("community-filter")
                    }.padding(.horizontal, 12).frame(minHeight: 44).background(Color.fomioFill, in: .rect(cornerRadius: 12))
                    Button { presentation = nil } label: { Text("Cancel").frame(minHeight: 44).contentShape(.rect) }.accessibilityIdentifier("scope-cancel")
                }.padding(.horizontal, 16).padding(.vertical, 6).background(Color.fomioBackground)
            }
            .task { focused = true }
            .onKeyPress(.escape) { presentation = nil; return .handled }
        }.environment(app)
            .environment(\.dynamicTypeSize, textSize)
            .environment(\.locale, locale)
            .environment(\.layoutDirection, direction)
    }
    private var roots: [Community] { app.communities.filter { $0.parentID == nil && !$0.restricted } }
    private var matchingCurrent: Community? {
        guard let id = scope.categoryID, !app.communities.contains(where: { $0.id == id }),
              let current = app.category(id), !current.restricted else { return nil }
        let parentMatches = current.parentID.flatMap(app.category).map { !$0.restricted && matches($0) } ?? false
        return matches(current) || parentMatches ? current : nil
    }
    private func matches(_ category: Community) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Names only: a description hit would show a community without saying why it matched.
        return term.isEmpty || category.name.localizedCaseInsensitiveContains(term)
    }
    private func visibleChildren(_ root: Community) -> [Community] {
        app.communities.filter { $0.parentID == root.id && !$0.restricted && (matches(root) || matches($0)) }
    }
    private func choice(name: String, selected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(Color.fomioText).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if selected { Image(systemName: "checkmark").foregroundStyle(Color.fomioAccent).accessibilityLabel("Selected") }
        }.frame(minHeight: 44).contentShape(.rect)
    }
    private func scopeRow(_ category: Community, parent: String?) -> some View {
        Button { choose(.category(category.id)) } label: {
            HStack(alignment: .top, spacing: 10) {
                CategoryMark(category: category, size: 24).accessibilityHidden(true)
                choice(name: category.name, selected: scope.categoryID == category.id)
            }.padding(.leading, parent == nil || textSize.isAccessibilitySize ? 0 : 20)
        }.accessibilityLabel(parent.map { BrowseLocalization.format("%@, subcommunity of %@", locale: locale, category.name, $0) } ?? category.name)
            .accessibilityIdentifier("scope-\(category.id.rawValue)")
            .accessibilityAddTraits(scope.categoryID == category.id ? .isSelected : [])
    }
    private func choose(_ scope: BrowseScope) { select(scope); presentation = nil }
}

/// The two-color brand wordmark: dark letters with the accent curve, and a light-on-dark
/// variant for dark appearance. Never mirrored and not scaled with text.
struct FomioWordmark: View {
    var height: CGFloat = 24
    var body: some View {
        Image("wordmark-color").resizable().scaledToFit().frame(height: height)
            .environment(\.layoutDirection, .leftToRight).accessibilityLabel("Fomio")
    }
}
