import Foundation
import Network

/// Errors shared by the low-level network probes.
enum NetProbeError: LocalizedError, Equatable {
    case invalidHost
    case invalidPort
    case timeout
    case connection(String)
    case cancelled
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidHost: String(localized: "error.probe.invalidHost", bundle: .module)
        case .invalidPort: String(localized: "error.probe.invalidPort", bundle: .module)
        case .timeout: String(localized: "error.probe.timeout", bundle: .module)
        case .connection(let message): message
        case .cancelled: String(localized: "error.probe.cancelled", bundle: .module)
        case .noData: String(localized: "error.probe.noData", bundle: .module)
        }
    }
}

/// Guards a `CheckedContinuation` so it resumes exactly once, even though
/// `NWConnection` may deliver several callbacks (state change + timeout).
final class OneShot<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

/// One-shot TCP connect used for reachability timing and port scanning.
enum TCPProbe {
    /// Attempts a TCP handshake and returns how long it took to reach
    /// `.ready`. A refused/unreachable port resolves to a failure.
    static func connectLatency(
        host: String, port: UInt16, timeout: Double
    ) async -> Result<Duration, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                shot.resume(.failure(.invalidPort))
                return
            }
            let host = host.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else {
                shot.resume(.failure(.invalidHost))
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host), port: nwPort, using: .tcp
            )
            let queue = DispatchQueue(label: "net.probe.tcp")
            let clock = ContinuousClock()
            let start = clock.now

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = start.duration(to: clock.now)
                    connection.cancel()
                    shot.resume(.success(elapsed))
                case .failed(let error):
                    connection.cancel()
                    shot.resume(.failure(.connection(error.localizedDescription)))
                case .waiting(let error):
                    // A probe should not wait for connectivity: treat a
                    // refused/unreachable endpoint as a definitive failure.
                    connection.cancel()
                    shot.resume(.failure(.connection(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                shot.resume(.failure(.timeout))
            }
        }
    }
}

/// A longer-lived TCP (optionally TLS) connection supporting async
/// connect / send / receive — used by Whois, Telnet and the MikroTik API.
final class TCPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "net.probe.stream")

    init?(host: String, port: UInt16, tls: Bool = false) {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else {
            return nil
        }
        let parameters: NWParameters = tls ? .tls : .tcp
        connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
    }

    /// Opens the connection, resolving when it becomes ready.
    func open(timeout: Double) async -> Result<Void, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    shot.resume(.success(()))
                case .failed(let error), .waiting(let error):
                    shot.resume(.failure(.connection(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                shot.resume(.failure(.timeout))
            }
        }
    }

    func send(_ data: Data) async -> Result<Void, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    shot.resume(.failure(.connection(error.localizedDescription)))
                } else {
                    shot.resume(.success(()))
                }
            })
        }
    }

    /// Receives the next available chunk (up to `maxLength` bytes).
    /// An empty result means the peer closed the stream.
    func receive(maxLength: Int = 65536) async -> Result<Data, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) {
                data, _, isComplete, error in
                if let error {
                    shot.resume(.failure(.connection(error.localizedDescription)))
                } else if let data, !data.isEmpty {
                    shot.resume(.success(data))
                } else if isComplete {
                    shot.resume(.success(Data()))
                } else {
                    shot.resume(.success(Data()))
                }
            }
        }
    }

    /// Reads until the peer closes the connection, accumulating all bytes.
    func receiveAll(timeout: Double) async -> Result<Data, NetProbeError> {
        var accumulated = Data()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        while clock.now < deadline {
            let result = await receive()
            switch result {
            case .success(let chunk):
                if chunk.isEmpty { return .success(accumulated) }
                accumulated.append(chunk)
            case .failure(let error):
                if !accumulated.isEmpty { return .success(accumulated) }
                return .failure(error)
            }
        }
        return .success(accumulated)
    }

    func cancel() {
        connection.cancel()
    }
}

/// Sends a single UDP datagram and waits for one response datagram.
/// Used by the DNS and SNMP tools.
enum UDPExchange {
    static func request(
        host: String, port: UInt16, payload: Data, timeout: Double
    ) async -> Result<Data, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                shot.resume(.failure(.invalidPort))
                return
            }
            let host = host.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else {
                shot.resume(.failure(.invalidHost))
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host), port: nwPort, using: .udp
            )
            let queue = DispatchQueue(label: "net.probe.udp")

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error {
                            connection.cancel()
                            shot.resume(.failure(.connection(error.localizedDescription)))
                            return
                        }
                        connection.receiveMessage { data, _, _, receiveError in
                            connection.cancel()
                            if let receiveError {
                                shot.resume(.failure(.connection(receiveError.localizedDescription)))
                            } else if let data, !data.isEmpty {
                                shot.resume(.success(data))
                            } else {
                                shot.resume(.failure(.noData))
                            }
                        }
                    })
                case .failed(let error):
                    connection.cancel()
                    shot.resume(.failure(.connection(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                shot.resume(.failure(.timeout))
            }
        }
    }
}
