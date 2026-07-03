import Foundation
import Observation

/// Drives a TCP-ping run: repeated handshake attempts with live results.
@MainActor
@Observable
final class PingViewModel {
    var host = ""
    var portText = "443"
    var countText = "5"

    private(set) var attempts: [PingAttempt] = []
    private(set) var summary: PingSummary?
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private let service: any PingProviding

    init(service: any PingProviding = TCPPingService()) {
        self.service = service
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = String(localized: "error.probe.invalidPort", bundle: .module)
            return
        }
        let count = max(1, min(20, Int(countText) ?? 5))

        isRunning = true
        errorMessage = nil
        attempts = []
        summary = nil

        var collected: [PingAttempt] = []
        for sequence in 1...count {
            if !isRunning { break }
            let attempt = await service.attempt(host: target, port: port, timeout: 3)
            let stamped = PingAttempt(sequence: sequence, milliseconds: attempt.milliseconds)
            collected.append(stamped)
            attempts = collected
            summary = TCPPingService.summarize(collected)
        }
        isRunning = false
    }

    func stop() {
        isRunning = false
    }
}
