import Foundation
import Observation

/// Drives a real ICMP (or ICMPv6) ping run with professional options:
/// request count / continuous, period between echoes, per-echo timeout,
/// payload size, TTL / hop-limit and an IPv6 preference. No port — it's a
/// genuine ICMP echo over the unprivileged datagram socket.
@MainActor
@Observable
final class PingViewModel {
    var host = ""

    // Options (mirrors a professional ping tool).
    var countText = "5"          // Number of Requests
    var intervalText = "1"       // Ping Period (s) — gap between echoes
    var timeoutText = "2"        // Ping Timeout (s)
    var payloadText = "56"       // Payload Size (bytes)
    var ttlText = "64"           // TTL / hop-limit
    var preferIPv6 = false       // Prefer IPv6
    var continuous = false       // keep pinging until stopped

    private(set) var attempts: [PingAttempt] = []
    private(set) var summary: PingSummary?
    private(set) var resolvedIP: String?
    private(set) var isRunning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isRunning else { return }
            if isRunning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var errorMessage: String?
    /// This tool's own recent-runs log (newest first), kept while the app runs.
    private(set) var history: [String] = []

    /// Set once by the view so a running operation can flag itself in the
    /// sidebar even after you navigate away.
    var activity: ActivityCenter?
    var toolID = ""

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }

        let count = continuous ? Int.max : max(1, min(1000, Int(countText) ?? 5))
        let interval = max(0.1, Double(intervalText) ?? 1)
        let timeout = max(0.2, Double(timeoutText) ?? 2)
        let payload = max(0, min(65_500, Int(payloadText) ?? 56))
        let ttl = max(1, min(255, Int(ttlText) ?? 64))

        isRunning = true
        errorMessage = nil
        attempts = []
        summary = nil
        resolvedIP = nil

        guard let resolved = ICMPPingEngine.resolve(host: target, preferIPv6: preferIPv6) else {
            errorMessage = L10nString("ping.error.resolve")
            isRunning = false
            return
        }
        resolvedIP = resolved.ip

        var collected: [PingAttempt] = []
        var sequence = 0
        while isRunning, sequence < count {
            sequence += 1
            let reply = await ICMPPingEngine.ping(
                target: resolved, sequence: sequence, ttl: ttl, payloadSize: payload, timeout: timeout
            )
            collected.append(PingAttempt(sequence: sequence, milliseconds: reply.milliseconds))
            attempts = collected
            summary = TCPPingService.summarize(collected)
            if isRunning, sequence < count {
                try? await Task.sleep(for: .seconds(interval))
            }
        }
        isRunning = false

        if let summary {
            let average = summary.avgMs.map { String(format: " · %.0f ms", $0) } ?? ""
            history.insert("\(target) (\(resolved.ip)) — \(summary.received)/\(summary.sent)\(average)", at: 0)
            if history.count > 10 { history.removeLast() }
        }
    }

    func stop() {
        isRunning = false
    }
}
