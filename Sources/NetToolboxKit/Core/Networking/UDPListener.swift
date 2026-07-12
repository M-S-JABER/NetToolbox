import Foundation
import Network

/// Listens for inbound UDP datagrams on a port and delivers each one with its
/// sender. Used by the Syslog and SNMP-trap receivers. Zero dependencies.
final class UDPListener: @unchecked Sendable {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.nettoolbox.udplisten")

    var onDatagram: ((Data, String) -> Void)?
    var onError: ((String) -> Void)?
    var onReady: (() -> Void)?

    func start(port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onError?("Invalid port")
            return
        }
        guard let listener = try? NWListener(using: .udp, on: nwPort) else {
            onError?("Could not bind to port \(port)")
            return
        }
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.onReady?()
            case .failed(let error): self?.onError?(error.localizedDescription)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.connections.append(connection)
            connection.start(queue: self.queue)
            self.receive(on: connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        // Serialize teardown on the same queue the listener/connection
        // callbacks mutate `connections` on, so the array is never touched
        // from two threads at once.
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.connections.forEach { $0.cancel() }
            self.connections = []
            self.listener = nil
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.onDatagram?(data, self.sender(of: connection))
            }
            if error == nil {
                self.receive(on: connection)
            }
        }
    }

    private func sender(of connection: NWConnection) -> String {
        if case .hostPort(let host, _) = connection.endpoint {
            return "\(host)"
        }
        return "?"
    }
}
