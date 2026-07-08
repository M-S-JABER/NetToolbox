import Foundation

/// One round-trip attempt result.
struct PingAttempt: Identifiable, Equatable, Sendable {
    let sequence: Int
    /// Round-trip time in milliseconds, or nil when the attempt failed.
    let milliseconds: Double?

    var id: Int { sequence }
    var succeeded: Bool { milliseconds != nil }
}

/// Aggregate statistics over a ping run.
struct PingSummary: Equatable, Sendable {
    let sent: Int
    let received: Int
    let minMs: Double?
    let avgMs: Double?
    let maxMs: Double?
    var mdevMs: Double?   // standard deviation of the round-trip times

    var lossPercent: Int {
        guard sent > 0 else { return 0 }
        return Int((Double(sent - received) / Double(sent) * 100).rounded())
    }
}

/// TCP-connect "ping": measures the time to complete a TCP handshake to a
/// port. iOS does not allow raw ICMP, so this is the reliable, native
/// equivalent for reachability and latency.
protocol PingProviding: Sendable {
    func attempt(host: String, port: UInt16, timeout: Double) async -> PingAttempt
}

struct TCPPingService: PingProviding {
    func attempt(host: String, port: UInt16, timeout: Double) async -> PingAttempt {
        let result = await TCPProbe.connectLatency(host: host, port: port, timeout: timeout)
        switch result {
        case .success(let duration):
            let ms = Double(duration.components.seconds) * 1000
                + Double(duration.components.attoseconds) / 1_000_000_000_000_000
            return PingAttempt(sequence: 0, milliseconds: ms)
        case .failure:
            return PingAttempt(sequence: 0, milliseconds: nil)
        }
    }

    /// Combines attempts into summary statistics.
    static func summarize(_ attempts: [PingAttempt]) -> PingSummary {
        let times = attempts.compactMap(\.milliseconds)
        let avg = times.isEmpty ? nil : times.reduce(0, +) / Double(times.count)
        var mdev: Double?
        if let avg, times.count > 1 {
            let variance = times.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(times.count)
            mdev = variance.squareRoot()
        }
        return PingSummary(
            sent: attempts.count,
            received: times.count,
            minMs: times.min(),
            avgMs: avg,
            maxMs: times.max(),
            mdevMs: mdev
        )
    }
}
