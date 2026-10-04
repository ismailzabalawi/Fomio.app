import Foundation
import Network
import Observation

/// Path status only drives offline messaging and disables sending; nothing is queued.
@MainActor @Observable final class Connectivity {
    private(set) var offline = false
    @ObservationIgnored private let monitor = NWPathMonitor()
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in self?.offline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "app.fomio.connectivity"))
    }
    deinit { monitor.cancel() }
}
