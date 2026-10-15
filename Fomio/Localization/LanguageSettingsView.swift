import SwiftUI

extension LocalizationController {
    /// Native name of the language the interface currently shows.
    var currentName: String {
        let code = localizer.catalog.locale
        return nativeName(code)
    }
    /// The site's native name, or the language's own name (autonym) before the site list has loaded.
    func nativeName(_ code: String) -> String {
        languages.first { $0.locale == code }?.nativeName ?? Self.autonym(code)
    }
    static func autonym(_ code: String) -> String {
        let identifier = code.replacingOccurrences(of: "_", with: "-")
        return Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? code
    }
}

/// Me › Language. Device language is the default; an explicit choice downloads only that language.
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
                        Button(L("common.try_again")) { Task { await localization.select(code == localization.resolve(.system) && localization.preference == .system ? .system : .locale(code)) } }.frame(minHeight: 44)
                    }.listRowInsets(EdgeInsets()).accessibilityIdentifier("language-failed")
                }
            }
            if localization.status == .idle, localization.target != localization.localizer.catalog.locale {
                Section {
                    InfoCard(title: nil, message: L("language.pending", ["language": localization.nativeName(localization.target)]))
                        .listRowInsets(EdgeInsets()).accessibilityIdentifier("language-pending")
                }
            }
            Section {
                row(title: L("language.device"), subtitle: localization.systemLanguage.map { $0.nativeName } ?? L("language.device_unavailable"),
                    selected: localization.preference == .system, identifier: "language-system") { await localization.select(.system) }
                ForEach(localization.languages, id: \.locale) { entry in
                    row(title: entry.nativeName, subtitle: entry.name == entry.nativeName ? nil : entry.name, direction: entry.direction == "rtl" ? .rightToLeft : .leftToRight,
                        selected: localization.preference == .locale(entry.locale), identifier: "language-\(entry.locale)") { await localization.select(.locale(entry.locale)) }
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
        .task { await localization.refreshIndex() }
        .onDisappear { localization.clearFailure() }
    }
    private func row(title: String, subtitle: String?, direction: LayoutDirection? = nil, selected: Bool, identifier: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    // A language's own name keeps that language's direction.
                    Text(title).foregroundStyle(.primary).environment(\.layoutDirection, direction ?? title.naturalDirection)
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.fomioAccent).accessibilityHidden(true) }
            }.frame(minHeight: 44).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.map { L("language.row_label", ["name": title, "detail": $0]) } ?? title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
