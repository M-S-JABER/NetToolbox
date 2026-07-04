import Foundation

/// Discovers likely IP cameras by unicast TCP-probing the device's own /24 for
/// the RTSP port. WS-Discovery multicast needs an entitlement unavailable to a
/// Playgrounds-distributed app, so a direct port sweep is used instead.
struct CameraScanner: Sendable {
    private let provider: LocalIPProviding

    init(provider: LocalIPProviding = SystemLocalIPProvider()) {
        self.provider = provider
    }

    /// The `a.b.c.` prefix of the first non-loopback IPv4 address, if any.
    func subnetBase() -> String? {
        guard let address = provider.addresses().first(where: { !$0.isIPv6 }) else { return nil }
        let parts = address.address.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2])."
    }

    /// Probes `base`1…254 on `port`, returning the reachable hosts.
    func scan(base: String, port: UInt16 = 554, timeout: Double = 1.0, concurrency: Int = 24) async -> [String] {
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var next = 1
            while next <= 254, next <= concurrency {
                let host = next
                group.addTask { await Self.probe(base: base, host: host, port: port, timeout: timeout) }
                next += 1
            }
            while let result = await group.next() {
                if let ip = result { found.append(ip) }
                if next <= 254 {
                    let host = next
                    group.addTask { await Self.probe(base: base, host: host, port: port, timeout: timeout) }
                    next += 1
                }
            }
        }
        return found.sorted { lastOctet($0) < lastOctet($1) }
    }

    private static func probe(base: String, host: Int, port: UInt16, timeout: Double) async -> String? {
        let ip = "\(base)\(host)"
        if case .success = await TCPProbe.connectLatency(host: ip, port: port, timeout: timeout) {
            return ip
        }
        return nil
    }

    private func lastOctet(_ ip: String) -> Int {
        Int(ip.split(separator: ".").last ?? "0") ?? 0
    }
}
