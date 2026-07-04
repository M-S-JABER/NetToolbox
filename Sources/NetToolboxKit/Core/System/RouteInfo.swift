import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Reads the routing table to find the default gateway (router) address.
/// iOS exposes no high-level API for this, so it parses the `PF_ROUTE`
/// `NET_RT_DUMP` sysctl output defensively (bounds-checked; returns nil on
/// any inconsistency rather than crashing).
enum RouteInfo {
    static func defaultGatewayIPv4() -> String? {
        #if canImport(Darwin)
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }

        let headerSize = MemoryLayout<rt_msghdr>.stride
        return buffer.withUnsafeBytes { raw -> String? in
            var offset = 0
            while offset + headerSize <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: rt_msghdr.self)
                let messageLength = Int(header.rtm_msglen)
                guard messageLength >= headerSize, offset + messageLength <= length else { break }

                if header.rtm_flags & RTF_GATEWAY != 0 {
                    if let gateway = gatewayIfDefault(
                        raw: raw, start: offset + headerSize,
                        limit: offset + messageLength, addressMask: Int(header.rtm_addrs)
                    ) {
                        return gateway
                    }
                }
                offset += messageLength
            }
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(Darwin)
    /// Walks the sockaddr list of one route message; if the destination is
    /// 0.0.0.0 (default route) returns the gateway address string.
    private static func gatewayIfDefault(
        raw: UnsafeRawBufferPointer, start: Int, limit: Int, addressMask: Int
    ) -> String? {
        var cursor = start
        var destinationIsDefault = false
        var gateway: String?

        for index in 0..<Int(RTAX_MAX) {
            guard addressMask & (1 << index) != 0 else { continue }
            guard cursor + MemoryLayout<sockaddr>.stride <= limit else { break }

            let sa = raw.loadUnaligned(fromByteOffset: cursor, as: sockaddr.self)
            let saLen = Int(sa.sa_len)
            let advance = saLen == 0 ? 4 : (saLen + 3) & ~3

            if sa.sa_family == UInt8(AF_INET), cursor + MemoryLayout<sockaddr_in>.stride <= limit {
                let sin = raw.loadUnaligned(fromByteOffset: cursor, as: sockaddr_in.self)
                if index == Int(RTAX_DST), sin.sin_addr.s_addr == 0 {
                    destinationIsDefault = true
                } else if index == Int(RTAX_GATEWAY) {
                    gateway = format(sin.sin_addr)
                }
            }

            guard advance > 0 else { break }
            cursor += advance
        }
        return destinationIsDefault ? gateway : nil
    }

    private static func format(_ addr: in_addr) -> String? {
        var value = addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &value, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
        return String(cString: buffer)
    }
    #endif
}
