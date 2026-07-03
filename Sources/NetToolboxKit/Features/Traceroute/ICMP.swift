import Foundation

/// Pure ICMP echo-request construction and checksum (RFC 792).
/// Unit-tested; the socket I/O lives in the traceroute service.
enum ICMP {
    static let echoRequestType: UInt8 = 8
    static let echoReplyType: UInt8 = 0
    static let timeExceededType: UInt8 = 11
    static let destinationUnreachableType: UInt8 = 3

    /// Internet checksum: one's-complement sum of 16-bit words.
    static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < bytes.count {
            sum += (UInt32(bytes[index]) << 8) | UInt32(bytes[index + 1])
            index += 2
        }
        if index < bytes.count {
            sum += UInt32(bytes[index]) << 8   // pad final odd byte
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return UInt16(~sum & 0xFFFF)
    }

    /// Builds an ICMP echo request with a correct checksum.
    static func echoRequest(identifier: UInt16, sequence: UInt16, payload: [UInt8] = []) -> [UInt8] {
        var packet: [UInt8] = [
            echoRequestType, 0,          // type, code
            0, 0,                        // checksum placeholder
            UInt8(identifier >> 8), UInt8(identifier & 0xFF),
            UInt8(sequence >> 8), UInt8(sequence & 0xFF),
        ]
        packet.append(contentsOf: payload)
        let sum = checksum(packet)
        packet[2] = UInt8(sum >> 8)
        packet[3] = UInt8(sum & 0xFF)
        return packet
    }
}
