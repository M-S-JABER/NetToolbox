import Foundation
import Observation
import Network

/// Observes the device's live network path (Wi-Fi / cellular / wired /
/// offline) so the home screen can show an at-a-glance status pill.
@MainActor
@Observable
final class NetworkStatusMonitor {
    enum Connection: Equatable {
        case wifi, cellular, wired, other, offline, unknown

        var symbol: String {
            switch self {
            case .wifi: "wifi"
            case .cellular: "antenna.radiowaves.left.and.right"
            case .wired: "cable.connector"
            case .other: "network"
            case .offline: "wifi.slash"
            case .unknown: "questionmark.circle"
            }
        }

        var labelKey: String {
            switch self {
            case .wifi: "status.wifi"
            case .cellular: "status.cellular"
            case .wired: "status.wired"
            case .other: "status.other"
            case .offline: "status.offline"
            case .unknown: "status.unknown"
            }
        }

        var isOnline: Bool { self != .offline && self != .unknown }
    }

    private(set) var connection: Connection = .unknown
    private(set) var isExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.status.monitor")
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let connection = Self.classify(path)
            let expensive = path.isExpensive
            Task { @MainActor in
                self?.connection = connection
                self?.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    private static func classify(_ path: NWPath) -> Connection {
        guard path.status == .satisfied else { return .offline }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .other
    }
}
