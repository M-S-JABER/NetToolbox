import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Reads the ARP cache (via `PF_ROUTE` `NET_RT_FLAGS`) to find the MAC of a
/// local IP — used to name the router vendor. Bounds-checked; returns nil
/// on any inconsistency rather than crashing.
enum ARPTable {
    static func macAddress(for ip: String) -> String? {
        #if canImport(Darwin)
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
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

                let sinOffset = offset + headerSize
                if sinOffset + MemoryLayout<sockaddr_in>.stride <= length {
                    let sin = raw.loadUnaligned(fromByteOffset: sinOffset, as: sockaddr_in.self)
                    if sin.sin_family == UInt8(AF_INET), formatIPv4(sin.sin_addr) == ip {
                        let saLen = Int(raw.load(fromByteOffset: sinOffset, as: UInt8.self))
                        let advance = saLen == 0 ? 16 : (saLen + 3) & ~3
                        if let mac = readMAC(raw: raw, offset: sinOffset + advance, limit: offset + messageLength) {
                            return mac
                        }
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
    private static func readMAC(raw: UnsafeRawBufferPointer, offset: Int, limit: Int) -> String? {
        guard offset + 8 <= limit else { return nil }
        guard raw.load(fromByteOffset: offset + 1, as: UInt8.self) == UInt8(AF_LINK) else { return nil }
        let nameLength = Int(raw.load(fromByteOffset: offset + 5, as: UInt8.self))
        let addressLength = Int(raw.load(fromByteOffset: offset + 6, as: UInt8.self))
        guard addressLength == 6 else { return nil }
        let macStart = offset + 8 + nameLength
        guard macStart + 6 <= limit else { return nil }

        var octets: [UInt8] = []
        for index in 0..<6 {
            octets.append(raw.load(fromByteOffset: macStart + index, as: UInt8.self))
        }
        // Ignore all-zero entries (incomplete ARP).
        guard octets.contains(where: { $0 != 0 }) else { return nil }
        return octets.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    private static func formatIPv4(_ addr: in_addr) -> String {
        let bytes = withUnsafeBytes(of: addr.s_addr) { Array($0) }
        guard bytes.count == 4 else { return "" }
        return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
    }
    #endif
}
