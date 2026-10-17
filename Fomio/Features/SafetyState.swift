import Foundation
import Observation

/// One report for one exact target and account. Input is kept in memory only; it is never logged or persisted.
@MainActor @Observable final class ReportState: Identifiable {
    enum Phase: Equatable { case loading, form, sending, received, already, unavailable, removed, loadFailed(String) }
    /// Recoverable notices shown above the form. Input is kept for every one of them.
    enum Notice: Equatable {
        case offline, rateLimited, signInRequired, rejected(String), unconfirmed, notReceived
    }
    let id = UUID()
    let target: ReportTarget
    let title: String
    var account: AccountID
    let service: any SafetyRepository
    var phase: Phase = .loading
    var context: ReportContext?
    var reasonID: Int?
    var details = ""
    var notice: Notice?
    var checking = false
    var detailsMissing = false
    init(target: ReportTarget, title: String, account: AccountID, service: any SafetyRepository) {
        self.target = target; self.title = title; self.account = account; self.service = service
    }
    var reasons: [ReportReason] { context?.reasons ?? [] }
    var reason: ReportReason? { reasons.first { $0.id == reasonID } }
    var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasEdits: Bool { reasonID != nil || !trimmedDetails.isEmpty }
    var isSending: Bool { phase == .sending || checking }
    /// After an unknown outcome Send stays unavailable until Check status establishes the state.
    var canSend: Bool { phase == .form && reason != nil && notice != .unconfirmed && !checking }
    /// Rechecks the exact target. `keepInput` retains the reason and details across sign-in when the reason is still offered.
    func load(isOffline: Bool, keepInput: Bool = false) async {
        phase = .loading
        if !keepInput { reasonID = nil; details = "" }
        do {
            let value = try await service.reportContext(target)
            context = value
            if value.alreadyReported { phase = .already; return }
            if value.reasons.isEmpty { phase = .unavailable; return }
            if let reasonID, !value.reasons.contains(where: { $0.id == reasonID }) { self.reasonID = nil }
            phase = .form
            if keepInput { notice = nil }
        } catch RepositoryError.unavailable { phase = .removed }
        catch RepositoryError.denied { phase = .unavailable }
        catch { phase = .loadFailed(isOffline ? RepositoryError.offline.localizedDescription : error.localizedDescription) }
    }
    func select(_ id: Int) {
        guard !isSending else { return }
        reasonID = id; detailsMissing = false
        if case .rejected = notice { notice = nil }
    }
    /// Single explicit submit. Returns true if the session ended and the caller must sign in again.
    @discardableResult func send(isOffline: Bool) async -> Bool {
        guard canSend, let reason else { return false }
        if reason.requiresMessage && trimmedDetails.isEmpty { detailsMissing = true; return false }
        // The request never leaves the device while offline, so sending again later is safe.
        if isOffline { notice = .offline; return false }
        phase = .sending; notice = nil
        do {
            switch try await service.submitReport(target, reason: reason, message: trimmedDetails.isEmpty ? nil : trimmedDetails) {
            case .received: phase = .received
            case .unconfirmed: phase = .form; notice = .unconfirmed
            }
        } catch let error as RepositoryError {
            phase = .form
            switch error {
            case .unauthorized: notice = .signInRequired; return true
            case .rateLimited: notice = .rateLimited
            case .unavailable: phase = .removed
            case .denied:
                // 403 means already flagged or not permitted. Localized text isn't parsed; the target's state decides.
                await reconcileDenied()
            case let .invalid(message): notice = .rejected(message)
            case .offline: notice = .offline
            default: notice = .unconfirmed
            }
        } catch { phase = .form; notice = .unconfirmed }
        return false
    }
    private func reconcileDenied() async {
        if (try? await service.reportStatus(target)) == .received { phase = .already } else { phase = .unavailable }
    }
    /// Establishes whether an unconfirmed report was recorded. Never resubmits.
    func checkStatus() async {
        guard !checking else { return }
        checking = true; defer { checking = false }
        do {
            switch try await service.reportStatus(target) {
            case .received: phase = .received; notice = nil
            case .notReceived: notice = .notReceived
            }
        } catch RepositoryError.unavailable { phase = .removed }
        catch { notice = .unconfirmed }
    }
}

/// Ignore confirmation for one member and account. Success is shown only after the server state confirms it.
@MainActor @Observable final class IgnoreState: Identifiable {
    enum Phase: Equatable { case choosing, sending, uncertain, denied(String), failed(String), signInRequired, refreshing }
    let id = UUID()
    let username: String
    let name: String?
    let account: AccountID
    var duration: IgnoreDuration = .forever
    var phase: Phase = .choosing
    init(username: String, name: String?, account: AccountID) { self.username = username; self.name = name; self.account = account }
    var busy: Bool { phase == .sending || phase == .refreshing }
    /// Confirm is unavailable while uncertain: Refresh must reconcile first.
    var canConfirm: Bool {
        switch phase { case .choosing, .denied, .failed: true; default: false }
    }
    /// Returns true once Discourse confirms the member is ignored.
    func confirm(service: any SafetyRepository, isOffline: Bool) async -> Bool {
        guard canConfirm else { return false }
        if isOffline { phase = .failed(RepositoryError.offline.localizedDescription); return false }
        phase = .sending
        do {
            switch try await service.ignore(username, until: duration.expiry()) {
            case .confirmed: return await reconcile(service: service, expectIgnored: true)
            case .unconfirmed: phase = .uncertain; return false
            }
        } catch RepositoryError.unauthorized { phase = .signInRequired; return false }
        catch RepositoryError.unconfirmed { phase = .uncertain; return false }
        catch let error as RepositoryError where { if case .invalid = error { true } else { error == .denied } }() {
            // Discourse answers a refused Ignore with 422 `ignore_error`; recheck the member to explain it truthfully.
            if let member = try? await service.memberSafety(username), member.ignored { return true }
            phase = .denied(error.localizedDescription); return false
        }
        catch { phase = .failed(error.localizedDescription); return false }
    }
    /// Reads the authoritative state after a write or an unknown outcome.
    func reconcile(service: any SafetyRepository, expectIgnored: Bool = true) async -> Bool {
        phase = .refreshing
        do {
            let member = try await service.memberSafety(username)
            if member.ignored == expectIgnored { return true }
            phase = expectIgnored ? .choosing : .uncertain; return false
        } catch { phase = .uncertain; return false }
    }
}

/// Stop ignoring, reconciled against the member's server state. Discourse `normal` also clears any Mute.
@MainActor func stopIgnoring(_ username: String, app: AppState) async -> Bool {
    guard !app.isOffline else { app.banner = RepositoryError.offline.localizedDescription; return false }
    do {
        let write = try await app.service.stopIgnoring(username)
        let member = try? await app.service.memberSafety(username)
        if member?.ignored == false {
            await app.safetyChanged(); app.toast(String(localized: "You’re no longer ignoring \(username)."))
            return true
        }
        app.banner = write == .unconfirmed || member == nil
            ? String(localized: "We couldn’t confirm the change. Refresh to see whether \(username) is still ignored before trying again.")
            : String(localized: "\(username) is still ignored. Try again later.")
        return false
    } catch RepositoryError.unauthorized {
        app.banner = String(localized: "Your session ended and nothing changed. Sign in, then try again.")
        return false
    } catch { app.banner = error.localizedDescription; return false }
}
