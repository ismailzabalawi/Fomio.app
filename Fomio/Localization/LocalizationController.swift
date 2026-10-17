import Foundation
import Observation

/// Manual interface-language choice backed by the site's catalog endpoint.
///
/// - English (bundled) is the default and the fallback. Nothing chooses another language automatically:
///   not the device or per-app iOS language, not the site's default locale, not a member's Discourse locale,
///   and not a catalog that becomes available in the background.
/// - Me › Language lists English plus the languages the site offers (its allowed locales with complete
///   catalogs) that this app can validate (known plural rules and direction). Selecting one persists it only
///   after its catalog is validated, from the last good cache or a fresh download.
/// - Startup activates the selected language's validated cache synchronously; `refresh()` revalidates it
///   (24 hours, `If-None-Match`/304) and may update its wording, never which language is selected.
/// - Removed language: if the site's index no longer offers the selected language, the last good cache stays
///   active and is no longer refreshed; without a valid cache English is shown. The choice and any cache are
///   kept, and `removedNoticeKey` tells Me › Language which of the two it is.
///   Launch uses the cached index for 24 hours; opening Me › Language always revalidates it.
/// - Failed or incomplete selection: the current language and the stored choice are unchanged.
@MainActor @Observable final class LocalizationController {
    enum Status: Equatable, Sendable { case idle, downloading(String), failed(String) }
    static let preferenceKey = "interfaceLanguage"
    static let refreshInterval: TimeInterval = 24 * 60 * 60

    let localizer: Localizer
    let store: LocalizationStore
    @ObservationIgnored let transport: any LocalizationTransport
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    /// The explicitly selected language; "en" until the member chooses another.
    private(set) var selected: String
    private(set) var index: CatalogIndex?
    /// The last successful index response came from the server in this session (not only the cache).
    private(set) var indexIsFresh = false
    private(set) var status: Status = .idle
    /// The site offered no catalog contract on the last attempt; only English is available.
    private(set) var contractUnavailable = false
    @ObservationIgnored private var catalogTasks: [String: Task<LocalizationCatalog?, Never>] = [:]
    @ObservationIgnored private var indexTask: Task<Void, Never>?

    init(localizer: Localizer = .shared, store: LocalizationStore, transport: any LocalizationTransport, defaults: UserDefaults = .standard,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.localizer = localizer; self.store = store; self.transport = transport; self.defaults = defaults; self.now = now
        let saved = defaults.string(forKey: Self.preferenceKey)
        selected = saved.flatMap { LocaleMatcher.isValidCode($0) ? $0 : nil } ?? "en"
        store.removeOtherSchemas()
        index = store.index().flatMap { Self.decodeIndex($0.payload) }
        activateCached()
    }

    var english: LocalizationCatalog { localizer.english }

    /// English first, then the site's complete languages that this app can validate, in server order.
    var languages: [CatalogIndex.Entry] {
        let english = index?.locales.first { $0.locale == "en" } ?? Self.englishEntry
        return [english] + (index?.locales ?? []).filter { $0.locale != "en" && Self.isSupported($0) }
    }
    static let englishEntry = CatalogIndex.Entry(locale: "en", name: "English", nativeName: "English", direction: "ltr", complete: true, pluralCategories: ["one", "other"])
    /// A language is offered only when the server's assembled catalog is complete, its direction is known and
    /// the server's plural categories (Discourse's CLDR keys) are exactly the ones this app can select.
    static func isSupported(_ entry: CatalogIndex.Entry) -> Bool {
        guard entry.complete, LocaleMatcher.isValidCode(entry.locale), CatalogDirection(rawValue: entry.direction) != nil,
              let categories = PluralRules.categories(for: entry.locale) else { return false }
        return entry.pluralCategories.map { Set($0) == Set(categories.map(\.rawValue)) } ?? false
    }
    private func offered(_ code: String) -> Bool { code == "en" || languages.contains { $0.locale == code } }
    private func offersRemote(_ code: String) -> Bool { index?.locales.contains { $0.locale == code && Self.isSupported($0) } == true }
    /// A fresh index no longer lists the selected (non-English) language.
    var selectionRemoved: Bool { selected != "en" && indexIsFresh && !offersRemote(selected) }
    /// Me › Language's notice for a removed language: its last good copy is still shown, or (no valid cache) English is.
    /// Either way the choice is kept, so the language returns if the site offers it again.
    var removedNoticeKey: String? {
        guard selectionRemoved else { return nil }
        return localizer.catalog.locale == selected ? "language.removed" : "language.removed_english"
    }

    // MARK: Activation

    /// Synchronous and offline: the selected language's validated cache, otherwise bundled English.
    func activateCached() {
        if let catalog = cachedCatalog(selected) { localizer.activate(catalog); markUsed(selected) }
        else { localizer.activate(english) }
    }
    /// A cached catalog that still validates against this build. Invalid records are deleted, never shown.
    func cachedCatalog(_ code: String) -> LocalizationCatalog? {
        guard let record = store.record(code) else { return nil }
        do { return try CatalogValidator.validate(record.payload, requested: code, reference: english) }
        catch { store.remove(code); return nil }
    }
    private func markUsed(_ code: String) {
        guard var record = store.record(code) else { return }
        record.lastUsedAt = now(); try? store.save(record)
    }

    // MARK: Refresh

    /// Launch/foreground: refreshes the language list and the selected language's wording when stale.
    /// It never changes which language is selected.
    func refresh(force: Bool = false) async {
        await refreshIndex(force: force)
        let code = selected
        // English without a site English catalog is the bundled English.
        guard code != "en" || offersRemote("en") else { localizer.activate(english); return }
        // A removed language keeps its last good cache; the server no longer serves it.
        if selectionRemoved { activateCached(); return }
        let record = store.record(code)
        let stale = force || record.map { now().timeIntervalSince($0.fetchedAt) >= Self.refreshInterval || $0.fetchedAt > now() } ?? true
        if stale, let catalog = await download(code), selected == code { localizer.activate(catalog); return }
        if selected == code { activateCached() }
    }

    func refreshIndex(force: Bool = false) async {
        if let indexTask { await indexTask.value; return }
        let cached = store.index()
        if !force, let cached, index != nil, now().timeIntervalSince(cached.fetchedAt) < Self.refreshInterval, cached.fetchedAt <= now() { return }
        let task = Task { @MainActor in
            do {
                switch try await transport.index(etag: index == nil ? nil : cached?.etag) {
                case .notModified:
                    if var cached { cached.fetchedAt = now(); try? store.saveIndex(cached) }
                    indexIsFresh = index != nil
                case let .payload(data, etag):
                    guard let value = Self.decodeIndex(data) else { return }
                    index = value; indexIsFresh = true
                    try? store.saveIndex(.init(etag: etag, fetchedAt: now(), payload: data))
                }
                contractUnavailable = false
            } catch TransportError.unavailable { contractUnavailable = true }
            catch { /* Offline or server failure: keep the last good index. */ }
        }
        indexTask = task
        await task.value
        indexTask = nil
    }
    /// Me › Language: always revalidates the list (conditional, so usually a 304), even when the cached index is
    /// younger than 24 hours, so a removed or newly offered language is seen when the member looks for it.
    func revalidateLanguages() async { await refreshIndex(force: true) }
    private static func decodeIndex(_ data: Data) -> CatalogIndex? {
        guard data.count <= CatalogValidator.maximumPayloadBytes, let value = try? JSONDecoder().decode(CatalogIndex.self, from: data),
              value.schema == LocalizationCatalog.schema, value.locales.allSatisfy({ LocaleMatcher.isValidCode($0.locale) }) else { return nil }
        return value
    }

    /// Fetches, validates and stores one locale. Concurrent callers for the same locale share one request.
    func download(_ code: String) async -> LocalizationCatalog? {
        if let task = catalogTasks[code] { return await task.value }
        let task = Task { @MainActor in await self.fetch(code) }
        catalogTasks[code] = task
        let result = await task.value
        catalogTasks[code] = nil
        return result
    }
    private func fetch(_ code: String, conditional: Bool = true) async -> LocalizationCatalog? {
        let cached = cachedCatalog(code)
        let record = cached == nil ? nil : store.record(code)
        do {
            switch try await transport.catalog(locale: code, etag: conditional ? record?.etag : nil) {
            case .notModified:
                // A 304 without a usable cache means the validator state was lost; ask once without it.
                guard var record, let cached else { return conditional ? await fetch(code, conditional: false) : nil }
                record.fetchedAt = now(); try? store.save(record)
                return cached
            case let .payload(data, etag):
                let catalog = try CatalogValidator.validate(data, requested: code, reference: english)
                try store.save(.init(locale: code, revision: catalog.revision, etag: etag, fetchedAt: now(), lastUsedAt: now(), payload: data))
                store.evict(keeping: selected == code ? code : selected)
                return catalog
            }
        } catch {
            // A 404 for one locale (not offered, or removed) says nothing about the contract as a whole.
            return nil
        }
    }

    // MARK: Selection

    /// Explicit choice from Me › Language. Persists only after the language's catalog validates: English
    /// (bundled, or the site's English when offered), the last good cache (also offline), or a download.
    /// A language the site does not offer, or whose catalog fails, leaves everything unchanged.
    @discardableResult func select(_ code: String) async -> Bool {
        func commit(_ catalog: LocalizationCatalog) {
            selected = code
            if code == "en" { defaults.removeObject(forKey: Self.preferenceKey) } else { defaults.set(code, forKey: Self.preferenceKey) }
            localizer.activate(catalog); status = .idle
            markUsed(code); store.evict(keeping: code)
        }
        guard offered(code) else { status = .failed(code); return false }
        if code == "en" {
            commit(cachedCatalog("en") ?? english)
            if offersRemote("en") { Task { await refresh() } }
            return true
        }
        if let cached = cachedCatalog(code) {
            commit(cached)
            Task { await refresh() }
            return true
        }
        status = .downloading(code)
        if let catalog = await download(code) { commit(catalog); return true }
        status = .failed(code)
        return false
    }
    func clearFailure() { if case .failed = status { status = .idle } }
}
