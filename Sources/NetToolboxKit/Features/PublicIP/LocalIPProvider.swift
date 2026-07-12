import Foundation

/// One local network interface address (e.g. en0 → 192.168.1.20).
struct LocalInterfaceAddress: Identifiable, Equatable, Sendable {
    let interface: String
    let address: String
    let isIPv6: Bool

    var id: String { "\(interface)-\(address)" }
}

/// Abstraction over local address enumeration (mockable in tests).
protocol LocalIPProviding: Sendable {
    func addresses() -> [LocalInterfaceAddress]
}

/// Reads device interface addresses via `getifaddrs`.
/// No special entitlement is required for the device's own addresses.
struct SystemLocalIPProvider: LocalIPProviding {
    func addresses() -> [LocalInterfaceAddress] {
        #if canImport(Darwin)
        var result: [LocalInterfaceAddress] = []
        var ifaddrsPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPointer) == 0, let first = ifaddrsPointer else {
            return []
        }
        defer { freeifaddrs(ifaddrsPointer) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = pointer.pointee
            guard let sockaddrPointer = ifa.ifa_addr else { continue }
            let family = sockaddrPointer.pointee.sa_family
            guard family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) else {
                continue
            }
            // Skip interfaces that are down or loopback.
            let flags = Int32(ifa.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }

            let name = String(cString: ifa.ifa_name)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = family == sa_family_t(AF_INET)
                ? socklen_t(MemoryLayout<sockaddr_in>.size)
                : socklen_t(MemoryLayout<sockaddr_in6>.size)
            guard getnameinfo(
                sockaddrPointer, length,
                &host, socklen_t(host.count),
                nil, 0,
                NI_NUMERICHOST
            ) == 0 else { continue }

            var address = String(cBuffer: host)
            // Strip IPv6 scope suffix ("fe80::1%en0" → "fe80::1").
            if let percent = address.firstIndex(of: "%") {
                address = String(address[..<percent])
            }
            result.append(
                LocalInterfaceAddress(
                    interface: name,
                    address: address,
                    isIPv6: family == sa_family_t(AF_INET6)
                )
            )
        }
        // IPv4 first, then by interface name (en0 before utun/awdl).
        return result.sorted {
            if $0.isIPv6 != $1.isIPv6 { return !$0.isIPv6 }
            return $0.interface < $1.interface
        }
        #else
        return []
        #endif
    }
}
