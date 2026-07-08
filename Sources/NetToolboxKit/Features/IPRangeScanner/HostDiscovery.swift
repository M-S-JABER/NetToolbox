import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Reads the device's own IPv4 address and subnet from the active Wi-Fi
/// interface, so the scanner can pre-fill the local range instead of making
/// the user type a CIDR.
enum LocalNetworkInfo {
    #if canImport(Darwin)
    /// The primary local IPv4 network as a CIDR (e.g. "192.168.1.0/24"),
    /// derived from the Wi-Fi interface's address and netmask.
    static func primaryIPv4CIDR() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = pointer {
            pointer = entry.pointee.ifa_next
            let flags = Int32(bitPattern: entry.pointee.ifa_flags)
            guard let addr = entry.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET),
                  (flags & IFF_UP) == IFF_UP,
                  (flags & IFF_LOOPBACK) == 0 else { continue }
            // Wi-Fi is en0 on iOS; skip cellular (pdp_ip*) and virtual links.
            let name = String(cString: entry.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            let ipValue = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            var prefix = 24
            if let mask = entry.pointee.ifa_netmask {
                prefix = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt32(bigEndian: $0.pointee.sin_addr.s_addr).nonzeroBitCount
                }
            }
            let maskBits: UInt32 = prefix == 0 ? 0 : (~UInt32(0) << (32 - prefix))
            let network = ipValue & maskBits
            return "\(SubnetEngine.format(ipv4: network))/\(prefix)"
        }
        return nil
    }
    #else
    static func primaryIPv4CIDR() -> String? { nil }
    #endif
}

/// Detects a live host with a TCP handshake instead of ICMP. A host counts as
/// "up" if any probed port either accepts the connection or actively refuses
/// it (a RST proves something is there). This works on networks and in the
/// Swift Playgrounds sandbox where ICMP echo is filtered.
enum TCPHostProbe {
    /// Ports common enough that most devices expose or actively refuse one.
    static let ports: [UInt16] = [80, 443, 22, 445, 139, 8080, 62078, 53]

    static func probe(ip: String, timeout: Double) async -> Double? {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(blockingProbe(ip: ip, timeout: timeout))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingProbe(ip: String, timeout: Double) -> Double? {
        var template = sockaddr_in()
        template.sin_family = sa_family_t(AF_INET)
        guard ip.withCString({ inet_pton(AF_INET, $0, &template.sin_addr) }) == 1 else { return nil }

        let clock = ContinuousClock()
        let start = clock.now
        var descriptors: [Int32] = []
        var polls: [pollfd] = []
        defer { descriptors.forEach { close($0) } }

        for port in ports {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK)

            var addr = template
            addr.sin_port = port.bigEndian
            let result = withUnsafePointer(to: &addr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if result == 0 { close(fd); return elapsedMs(start, clock) }   // instant accept
            if result < 0, errno == ECONNREFUSED { close(fd); return elapsedMs(start, clock) }
            if result < 0, errno != EINPROGRESS { close(fd); continue }
            descriptors.append(fd)
            polls.append(pollfd(fd: fd, events: Int16(POLLOUT), revents: 0))
        }

        guard !polls.isEmpty else { return nil }
        let milliseconds = Int32(max(1, timeout * 1000))
        guard poll(&polls, nfds_t(polls.count), milliseconds) > 0 else { return nil }   // all timed out

        for (index, entry) in polls.enumerated() where entry.revents != 0 {
            var socketError: Int32 = 0
            var length = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(descriptors[index], SOL_SOCKET, SO_ERROR, &socketError, &length)
            if socketError == 0 || socketError == ECONNREFUSED { return elapsedMs(start, clock) }
        }
        return nil
    }

    private static func elapsedMs(_ start: ContinuousClock.Instant, _ clock: ContinuousClock) -> Double {
        let elapsed = start.duration(to: clock.now)
        return Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
    }
    #else
    private static func blockingProbe(ip: String, timeout: Double) -> Double? { nil }
    #endif
}
