import SwiftUI

extension LocalizationController {
    /// Native name of the language the interface currently shows.
    var currentName: String { nativeName(localizer.catalog.locale) }
    /// The site's native name, or the language's own name (autonym) when the site list does not include it.
    func nativeName(_ code: String) -> String {
        languages.first { $0.locale == code }?.nativeName ?? index?.locales.first { $0.locale == code }?.nativeName ?? Self.autonym(code)
    }
    static func autonym(_ code: String) -> String {
        let identifier = code.replacingOccurrences(of: "_", with: "-")
        return Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? code
    }
}

/// Me › Language. English is the default; each other row is a language the community offers and this app
/// can display. Choosing one downloads only that language and keeps it only if its catalog is valid.
struct LanguageSettingsView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let localization = app.localization
        let busy: Bool = { if case .downloading = localization.status { true } else { false } }()
        List {
            if case let .failed(code) = localization.status {
                Section {
                    InfoCard(title: L("language.download_failed.title", ["language": localization.nativeName(code)]),
                             message: L("language.download_failed.message", ["current": localization.currentName])) {
                        Button(L("common.try_again")) { Task { await localization.select(code) } }.frame(minHeight: 44)
                    }.listRowInsets(EdgeInsets()).accessibilityIdentifier("language-failed")
                }
            }
            if let key = localization.removedNoticeKey {
                Section {
                    InfoCard(title: nil, message: L(key, ["language": localization.nativeName(localization.selected)]))
                        .listRowInsets(EdgeInsets()).accessibilityIdentifier("language-removed")
                }
            } else if localization.status == .idle, localization.selected != localization.localizer.catalog.locale {
                Section {
                    InfoCard(title: nil, message: L("language.pending", ["language": localization.nativeName(localization.selected)]))
                        .listRowInsets(EdgeInsets()).accessibilityIdentifier("language-pending")
                }
            }
            Section {
                ForEach(localization.languages, id: \.locale) { entry in
                    row(title: entry.nativeName, subtitle: entry.name == entry.nativeName ? nil : entry.name, note: entry.isPartial ? L("language.partial") : nil,
                        direction: entry.direction == "rtl" ? .rightToLeft : .leftToRight,
                        selected: localization.selected == entry.locale, identifier: "language-\(entry.locale)") { await localization.select(entry.locale) }
                }
                if case let .downloading(code) = localization.status {
                    HStack(spacing: 10) { ProgressView(); Text(L("language.downloading", ["language": localization.nativeName(code)])) }
                        .frame(minHeight: 44).accessibilityElement(children: .combine).accessibilityIdentifier("language-downloading")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("language.footer"))
                    if localization.languages.count == 1 { Text(L("language.only_english")) }
                }
            }
            .disabled(busy)
        }
        .navigationTitle(L("language.title")).navigationBarTitleDisplayMode(.inline)
        .task { await localization.revalidateLanguages() }
        .onDisappear { localization.clearFailure() }
    }
    /// `note` says when a language is only partly translated (the server fills the rest with English).
    private func row(title: String, subtitle: String?, note: String?, direction: LayoutDirection, selected: Bool, identifier: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    // A language's own name keeps that language's direction.
                    Text(title).foregroundStyle(.primary).environment(\.layoutDirection, direction)
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                    if let note { Text(note).font(.footnote).foregroundStyle(Color.fomioSecondaryText).accessibilityIdentifier("\(identifier)-partial") }
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.fomioAccent).accessibilityHidden(true) }
            }.frame(minHeight: 44).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([subtitle, note].compactMap { $0 }.reduce(title) { L("language.row_label", ["name": $0, "detail": $1]) })
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
