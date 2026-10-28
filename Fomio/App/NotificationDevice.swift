import Foundation
import Observation
import UIKit
import UserNotifications

/// Reads and requests OS notification permission. OS permission is never treated as delivery readiness.
@MainActor protocol AlertPermissionProvider {
    func current() async -> AlertPermission
    /// Shows the system prompt (or its fixture simulation). Returns the resulting permission.
    func request() async -> AlertPermission
    var settingsURL: URL? { get }
}
/// Connects this device to a delivery relay for the signed-in account. No relay exists yet for live builds.
@MainActor protocol AlertEnrollmentService {
    var isAvailable: Bool { get }
    func enroll(account: AccountID) async throws
    func detach(account: AccountID) async
}

@MainActor struct SystemAlertPermission: AlertPermissionProvider {
    func current() async -> AlertPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unknown
        }
    }
    func request() async -> AlertPermission {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        return await current()
    }
    var settingsURL: URL? { URL(string: UIApplication.openNotificationSettingsURLString) }
}

/// Live builds: Discourse can only push to an allowed user-API-key push URL, and no Fomio relay, device registry,
/// APNs credential or site setting has been provisioned. This boundary reports that honestly and sends nothing.
/// It never registers for remote notifications and never posts an APNs token to the Web Push subscription endpoint.
@MainActor struct UnavailableAlertEnrollment: AlertEnrollmentService {
    var isAvailable: Bool { false }
    func enroll(account: AccountID) async throws { throw RepositoryError.unsupported }
    func detach(account: AccountID) async {}
}

/// Fixture-only permission prompt. The app shows a labelled simulation instead of the real system alert.
@MainActor final class SimulatedAlertPermission: AlertPermissionProvider {
    var value: AlertPermission = .notDetermined
    /// Set by the device model while the simulated prompt is on screen.
    var prompt: ((@escaping (Bool) -> Void) -> Void)?
    func current() async -> AlertPermission { value }
    func request() async -> AlertPermission {
        guard value == .notDetermined, let prompt else { return value }
        let allowed = await withCheckedContinuation { continuation in prompt { continuation.resume(returning: $0) } }
        value = allowed ? .authorized : .denied
        return value
    }
    var settingsURL: URL? { nil }
}
@MainActor final class SimulatedAlertEnrollment: AlertEnrollmentService {
    var failNext = false
    var step: Duration = .milliseconds(900)
    var isAvailable: Bool { true }
    func enroll(account: AccountID) async throws {
        try await Task.sleep(for: step)
        if failNext { failNext = false; throw RepositoryError.server(503) }
    }
    func detach(account: AccountID) async {}
}

/// Device alert status combines OS permission and enrollment. “On” requires both.
@MainActor @Observable final class NotificationDevice {
    enum Status: Equatable { case unavailable, off, notAllowed, allowed, finishing, failed, updating, on, detached }
    private(set) var permission: AlertPermission = .unknown
    private(set) var enrollment: AlertEnrollment
    var explaining = false
    /// Fixture system-prompt simulation currently on screen.
    var simulatedPrompt: ((Bool) -> Void)?
    var simulatedSettings = false
    let permissions: any AlertPermissionProvider
    let enrollments: any AlertEnrollmentService
    let wording: DeviceWording
    private var account: AccountID = .guest
    init(permissions: any AlertPermissionProvider, enrollments: any AlertEnrollmentService, isPad: Bool) {
        self.permissions = permissions; self.enrollments = enrollments
        self.wording = .current(isPad: isPad)
        enrollment = enrollments.isAvailable ? .none : .unavailable
        if let simulated = permissions as? SimulatedAlertPermission { simulated.prompt = { [weak self] reply in self?.simulatedPrompt = reply } }
    }
    var isSimulated: Bool { permissions is SimulatedAlertPermission }
    var status: Status {
        if enrollment == .unavailable { return .unavailable }
        if enrollment == .detached { return .detached }
        switch permission {
        case .denied: return .notAllowed
        case .authorized, .provisional, .ephemeral:
            switch enrollment {
            case .registering: return .finishing
            case .failed: return .failed
            case .renewing: return .updating
            case .ready: return .on
            default: return .allowed
            }
        default: return .off
        }
    }
    func refreshPermission() async { permission = await permissions.current() }
    /// Explicit Continue after the contextual explanation. Never called at launch.
    func requestPermission(account: AccountID) async {
        explaining = false
        // Let the explanation sheet finish dismissing before the system (or simulated) prompt appears.
        try? await Task.sleep(for: .milliseconds(450))
        permission = await permissions.request()
        if [.authorized, .provisional, .ephemeral].contains(permission) { await enroll(account: account) }
    }
    func enroll(account: AccountID) async {
        guard enrollments.isAvailable, account != .guest else { return }
        self.account = account
        enrollment = enrollment == .ready ? .renewing : .registering
        do { try await enrollments.enroll(account: account); guard self.account == account else { return }; enrollment = .ready }
        catch { guard self.account == account else { return }; enrollment = .failed(error.localizedDescription) }
    }
    /// Sign-out or account removal: the previous account's enrollment is detached before anything else binds.
    func detach() async {
        let previous = account; account = .guest
        guard enrollments.isAvailable else { return }
        if enrollment != .none { await enrollments.detach(account: previous); enrollment = .detached }
    }
    func bind(account: AccountID) { if self.account != account, enrollment == .detached { enrollment = .none }; self.account = account }
    func answerSimulatedPrompt(_ allowed: Bool) { let reply = simulatedPrompt; simulatedPrompt = nil; reply?(allowed) }
    func setSimulatedPermission(_ allowed: Bool) {
        guard let simulated = permissions as? SimulatedAlertPermission else { return }
        simulated.value = allowed ? .authorized : .denied; permission = simulated.value
        if !allowed, enrollment != .unavailable, enrollment != .detached { enrollment = .none }
    }
}

/// Holds notification taps until the app state can validate them (cold start, before account restoration).
@MainActor final class IncomingNotifications {
    static let shared = IncomingNotifications()
    private var queue: [NotificationIntent] = []
    var handler: ((NotificationIntent) -> Void)? { didSet { flush() } }
    var foreground: (() -> Void)?
    func deliver(_ intent: NotificationIntent) { queue.append(intent); flush() }
    private func flush() { guard let handler else { return }; let pending = queue; queue = []; pending.forEach(handler) }
}

final class FomioAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    /// Foreground delivery shows the system banner and refreshes server state. Nothing is marked read.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { IncomingNotifications.shared.foreground?() }
        return [.banner, .list, .sound]
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let info = response.notification.request.content.userInfo
        guard let intent = NotificationIntent.parse(info) else { return }
        await MainActor.run { IncomingNotifications.shared.deliver(intent) }
    }
}
