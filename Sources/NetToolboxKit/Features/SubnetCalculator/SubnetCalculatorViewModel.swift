import Foundation
import Observation
import SwiftData

/// State holder for the Subnet Calculator. All math lives in `SubnetEngine`.
@MainActor
@Observable
final class SubnetCalculatorViewModel {
    enum Output: Equatable {
        case idle
        case ipv4(IPv4SubnetResult)
        case ipv6(IPv6SubnetResult)
        case failure(String)
    }

    var addressInput = ""
    var maskInput = ""
    var output: Output = .idle

    /// IPv6 mode is auto-detected from the address text.
    var isIPv6Input: Bool {
        addressInput.contains(":")
    }

    func calculate(context: ModelContext?) {
        let address = addressInput.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else {
            output = .idle
            return
        }

        do {
            if isIPv6Input {
                let mask = maskInput.isEmpty ? "64" : maskInput
                let result = try SubnetEngine.calculateIPv6(address: address, prefix: mask)
                output = .ipv6(result)
                saveHistory(input: "\(address) /\(result.prefix)",
                            summary: result.cidrNotation,
                            context: context)
            } else {
                let mask = maskInput.isEmpty ? "24" : maskInput
                let result = try SubnetEngine.calculateIPv4(address: address, mask: mask)
                output = .ipv4(result)
                saveHistory(input: "\(address) \(mask)",
                            summary: result.cidrNotation,
                            context: context)
            }
        } catch {
            output = .failure(error.localizedDescription)
        }
    }

    func clear() {
        addressInput = ""
        maskInput = ""
        output = .idle
    }

    /// Restores a previous calculation from history.
    func load(historyInput: String) {
        let parts = historyInput.split(separator: " ", maxSplits: 1)
        addressInput = parts.first.map(String.init) ?? historyInput
        maskInput = parts.count > 1 ? String(parts[1]) : ""
        calculate(context: nil)
    }

    private func saveHistory(input: String, summary: String, context: ModelContext?) {
        guard let context else { return }
        context.insert(HistoryEntry(toolID: "subnet-calculator", input: input, summary: summary))
    }
}
