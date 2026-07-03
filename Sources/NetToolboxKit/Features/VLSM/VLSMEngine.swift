import Foundation

/// A subnet request: a label and the number of usable hosts required.
struct VLSMRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    var name: String
    var hosts: Int
}

/// A computed subnet allocation.
struct VLSMAllocation: Identifiable, Equatable, Sendable {
    let name: String
    let network: String
    let prefix: Int
    let mask: String
    let firstHost: String
    let lastHost: String
    let broadcast: String
    let usableHosts: UInt64
    let requestedHosts: Int

    var id: String { "\(name)-\(network)/\(prefix)" }
    var cidr: String { "\(network)/\(prefix)" }
}

enum VLSMError: LocalizedError, Equatable {
    case noRequests
    case doesNotFit

    var errorDescription: String? {
        switch self {
        case .noRequests: String(localized: "error.vlsm.noRequests", bundle: .module)
        case .doesNotFit: String(localized: "error.vlsm.doesNotFit", bundle: .module)
        }
    }
}

/// Variable-Length Subnet Masking: packs the requested subnets, largest
/// first, into a base network. Pure and unit-tested (reuses `SubnetEngine`).
enum VLSMEngine {
    static func allocate(baseCIDR: String, requests: [VLSMRequest]) throws -> [VLSMAllocation] {
        let valid = requests.filter { $0.hosts > 0 }
        guard !valid.isEmpty else { throw VLSMError.noRequests }

        let base = try SubnetEngine.calculateIPv4(address: baseCIDR, mask: baseCIDR.contains("/") ? "" : "24")
        let baseNetwork = try SubnetEngine.parseIPv4(base.networkAddress)

        // All address math in UInt64 so edge prefixes never overflow UInt32.
        let baseStart = UInt64(baseNetwork)
        let baseEnd = baseStart + base.totalAddressCount - 1

        // Largest requests first for tight packing.
        let sorted = valid.sorted { $0.hosts > $1.hosts }
        var cursor = baseStart
        var allocations: [VLSMAllocation] = []

        for request in sorted {
            let prefix = prefixFor(hosts: request.hosts)
            let blockSize = UInt64(1) << UInt64(32 - prefix)

            // Align the cursor up to the next block boundary.
            let aligned = (cursor / blockSize) * blockSize
            let start = aligned >= cursor ? aligned : aligned + blockSize
            let end = start + blockSize - 1
            guard end <= baseEnd else { throw VLSMError.doesNotFit }

            let subnet = try SubnetEngine.calculateIPv4(
                address: SubnetEngine.format(ipv4: UInt32(start)), mask: String(prefix)
            )
            allocations.append(
                VLSMAllocation(
                    name: request.name.isEmpty ? "Subnet" : request.name,
                    network: subnet.networkAddress,
                    prefix: prefix,
                    mask: subnet.subnetMask,
                    firstHost: subnet.firstUsableHost,
                    lastHost: subnet.lastUsableHost,
                    broadcast: subnet.broadcastAddress,
                    usableHosts: subnet.usableHostCount,
                    requestedHosts: request.hosts
                )
            )
            cursor = end + 1
        }
        return allocations
    }

    /// Smallest prefix whose usable-host capacity covers `hosts`.
    static func prefixFor(hosts: Int) -> Int {
        // Need hosts + 2 (network + broadcast) for prefixes ≤ /30.
        var prefix = 30
        while prefix >= 1 {
            let usable = usableHosts(forPrefix: prefix)
            if usable >= UInt64(hosts) { return prefix }
            prefix -= 1
        }
        return 1
    }

    static func usableHosts(forPrefix prefix: Int) -> UInt64 {
        let total = UInt64(1) << UInt64(32 - prefix)
        switch prefix {
        case 32: return 1
        case 31: return 2
        default: return total - 2
        }
    }
}
