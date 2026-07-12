import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// A real ICMP / ICMPv6 echo ping over the unprivileged
/// `SOCK_DGRAM` socket (the same kind Apple's SimplePing uses — no
/// entitlement, no port). Supports host resolution, IPv4 and IPv6, a
/// configurable TTL / hop-limit, payload size and per-echo timeout.
enum ICMPPingEngine {
    struct Target: Sendable, Equatable {
        let ip: String
        let isIPv6: Bool
    }

    struct Reply: Sendable {
        let sequence: Int
        let milliseconds: Double?   // nil = timeout / no reply
        let bytes: Int
    }

    /// Resolves a hostname/IP to a numeric address, honouring the IPv6
    /// preference and falling back to the other family.
    static func resolve(host: String, preferIPv6: Bool) -> Target? {
        #if canImport(Darwin)
        let families: [Int32] = preferIPv6 ? [AF_INET6, AF_INET] : [AF_INET, AF_INET6]
        for family in families {
            var hints = addrinfo(
                ai_flags: 0, ai_family: family, ai_socktype: SOCK_DGRAM,
                ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
            )
            var info: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, nil, &hints, &info) == 0, let info else { continue }
            defer { freeaddrinfo(info) }
            guard let addr = info.pointee.ai_addr else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, info.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                return Target(ip: String(cBuffer: buffer), isIPv6: family == AF_INET6)
            }
        }
        #endif
        return nil
    }

    static func ping(
        target: Target, sequence: Int, ttl: Int, payloadSize: Int, timeout: Double
    ) async -> Reply {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(blockingPing(target: target, sequence: sequence, ttl: ttl, payloadSize: payloadSize, timeout: timeout))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingPing(
        target: Target, sequence: Int, ttl: Int, payloadSize: Int, timeout: Double
    ) -> Reply {
        let totalBytes = 8 + max(0, payloadSize)
        func fail() -> Reply { Reply(sequence: sequence, milliseconds: nil, bytes: totalBytes) }

        let identifier = UInt16(getpid() & 0xFFFF)
        let payload = [UInt8](repeating: 0x61, count: max(0, payloadSize))   // 'a' fill
        let clock = ContinuousClock()

        if target.isIPv6 {
            var address = sockaddr_in6()
            address.sin6_family = sa_family_t(AF_INET6)
            guard target.ip.withCString({ inet_pton(AF_INET6, $0, &address.sin6_addr) }) == 1 else { return fail() }

            let fd = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
            guard fd >= 0 else { return fail() }
            defer { close(fd) }

            var hops = Int32(ttl)
            _ = setsockopt(fd, IPPROTO_IPV6, IPV6_UNICAST_HOPS, &hops, socklen_t(MemoryLayout<Int32>.size))
            setTimeout(fd, timeout)

            // ICMPv6 echo request: type 128, code 0, checksum 0 (kernel fills).
            var packet: [UInt8] = [128, 0, 0, 0,
                                   UInt8(identifier >> 8), UInt8(identifier & 0xFF),
                                   UInt8((sequence >> 8) & 0xFF), UInt8(sequence & 0xFF)]
            packet.append(contentsOf: payload)

            let start = clock.now
            let sent = packet.withUnsafeBytes { buffer in
                withUnsafePointer(to: &address) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                        sendto(fd, buffer.baseAddress, buffer.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in6>.size))
                    }
                }
            }
            guard sent > 0 else { return fail() }

            var response = [UInt8](repeating: 0, count: 1500)
            let received = recvfrom(fd, &response, response.count, 0, nil, nil)
            guard received > 0, (response.first ?? 0xFF) == 129 else { return fail() }   // echo reply
            return Reply(sequence: sequence, milliseconds: elapsedMs(start, clock), bytes: totalBytes)
        } else {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            guard target.ip.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else { return fail() }

            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            guard fd >= 0 else { return fail() }
            defer { close(fd) }

            var ttlValue = Int32(ttl)
            _ = setsockopt(fd, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))
            setTimeout(fd, timeout)

            let packet = ICMP.echoRequest(identifier: identifier, sequence: UInt16(sequence & 0xFFFF), payload: payload)
            let start = clock.now
            let sent = packet.withUnsafeBytes { buffer in
                withUnsafePointer(to: &address) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                        sendto(fd, buffer.baseAddress, buffer.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            guard sent > 0 else { return fail() }

            var response = [UInt8](repeating: 0, count: 1500)
            let received = recvfrom(fd, &response, response.count, 0, nil, nil)
            guard received > 0, (response.first ?? 0xFF) == ICMP.echoReplyType else { return fail() }
            return Reply(sequence: sequence, milliseconds: elapsedMs(start, clock), bytes: totalBytes)
        }
    }

    private static func setTimeout(_ fd: Int32, _ timeout: Double) {
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    private static func elapsedMs(_ start: ContinuousClock.Instant, _ clock: ContinuousClock) -> Double {
        let elapsed = start.duration(to: clock.now)
        return Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
    }
    #else
    private static func blockingPing(target: Target, sequence: Int, ttl: Int, payloadSize: Int, timeout: Double) -> Reply {
        Reply(sequence: sequence, milliseconds: nil, bytes: 8 + max(0, payloadSize))
    }
    #endif
}
