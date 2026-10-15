import Foundation
import Observation

/// Chooses the interface language and keeps its public catalog current.
///
/// Startup never waits for the network: a valid cached catalog for the chosen language activates during
/// `init`, otherwise the bundled English catalog stays active. `refresh()` runs on launch and foreground,
/// revalidates stale data (24 hours) with `If-None-Match`, and activates a changed revision in place.
/// Every response is validated before it is stored; a failure leaves the last good catalog active.
@MainActor @Observable final class LocalizationController {
    enum Preference: Equatable, Sendable {
        /// Follow the device's ordered language preferences among the languages the site offers.
        case system
        case locale(String)
    }
    enum Status: Equatable, Sendable { case idle, downloading(String), failed(String) }
    static let preferenceKey = "interfaceLanguage"
    static let refreshInterval: TimeInterval = 24 * 60 * 60

    let localizer: Localizer
    let store: LocalizationStore
    @ObservationIgnored let transport: any LocalizationTransport
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let preferredLanguages: @Sendable () -> [String]
    private(set) var preference: Preference
    private(set) var index: CatalogIndex?
    private(set) var status: Status = .idle
    /// The site offered no catalog contract on the last attempt; only English is available.
    private(set) var contractUnavailable = false
    @ObservationIgnored private var catalogTasks: [String: Task<LocalizationCatalog?, Never>] = [:]
    @ObservationIgnored private var indexTask: Task<Void, Never>?

    init(localizer: Localizer = .shared, store: LocalizationStore, transport: any LocalizationTransport, defaults: UserDefaults = .standard,
         now: @escaping @Sendable () -> Date = { Date() }, preferredLanguages: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }) {
        self.localizer = localizer; self.store = store; self.transport = transport; self.defaults = defaults; self.now = now; self.preferredLanguages = preferredLanguages
        let saved = defaults.string(forKey: Self.preferenceKey)
        preference = saved.flatMap { LocaleMatcher.isValidCode($0) ? .locale($0) : nil } ?? .system
        store.removeOtherSchemas()
        index = store.index().flatMap { Self.decodeIndex($0.payload) }
        activateCached()
    }

    var english: LocalizationCatalog { localizer.english }

    /// English first, then complete languages the app can validate (plural rules known), in server order.
    var languages: [CatalogIndex.Entry] {
        let english = index?.locales.first { $0.locale == "en" } ?? .init(locale: "en", name: "English", nativeName: "English", direction: "ltr", complete: true)
        let others = (index?.locales ?? []).filter { $0.locale != "en" && $0.complete && PluralRules.categories(for: $0.locale) != nil && CatalogDirection(rawValue: $0.direction) != nil }
        return [english] + others
    }
    private var offered: [String] { languages.map(\.locale) }
    private func offersRemote(_ code: String) -> Bool { index?.locales.contains { $0.locale == code && $0.complete } == true }

    /// The language the interface should show; its catalog may not have downloaded yet.
    func resolve(_ preference: Preference) -> String {
        switch preference {
        case let .locale(code): code
        case .system: LocaleMatcher.match(preferred: preferredLanguages(), available: offered) ?? "en"
        }
    }
    var target: String { resolve(preference) }
    /// What the device language resolves to, shown beside the "Device language" choice.
    var systemLanguage: CatalogIndex.Entry? { languages.first { $0.locale == resolve(.system) } }

    // MARK: Activation

    /// Synchronous and offline: the chosen language's validated cache, otherwise bundled English.
    func activateCached() {
        let code = target
        if let catalog = cachedCatalog(code) { localizer.activate(catalog); markUsed(code) }
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

    /// Launch/foreground refresh. Skips fresh data unless `force` is set (manual refresh).
    func refresh(force: Bool = false) async {
        await refreshIndex(force: force)
        let code = target
        guard code != "en" || offersRemote("en") else {
            // English is bundled; with no server English catalog, a previously cached one is no longer current.
            if code == "en" { localizer.activate(english) }
            return
        }
        let record = store.record(code)
        let stale = force || record.map { now().timeIntervalSince($0.fetchedAt) >= Self.refreshInterval || $0.fetchedAt > now() } ?? true
        if stale, let catalog = await download(code), target == code { localizer.activate(catalog); return }
        if target == code { activateCached() }
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
                case let .payload(data, etag):
                    guard let value = Self.decodeIndex(data) else { return }
                    index = value
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
                store.evict(keeping: target == code ? code : target)
                return catalog
            }
        } catch {
            if error as? TransportError == .unavailable { contractUnavailable = true }
            return nil
        }
    }

    // MARK: Selection

    /// Switches the interface language. A language that is neither cached nor downloadable leaves the
    /// current language and preference unchanged and reports `.failed`.
    @discardableResult func select(_ value: Preference) async -> Bool {
        let code = resolve(value)
        func commit(_ catalog: LocalizationCatalog) {
            preference = value
            switch value { case .system: defaults.removeObject(forKey: Self.preferenceKey); case let .locale(code): defaults.set(code, forKey: Self.preferenceKey) }
            localizer.activate(catalog); status = .idle
            markUsed(code); store.evict(keeping: code)
        }
        if code == "en" && cachedCatalog("en") == nil {
            commit(english)
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
