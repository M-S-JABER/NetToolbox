import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Errors from Wake-on-LAN.
enum WakeOnLANError: LocalizedError, Equatable {
    case invalidMAC
    case socketFailed
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .invalidMAC: String(localized: "error.wol.invalidMAC", bundle: .module)
        case .socketFailed: String(localized: "error.wol.socket", bundle: .module)
        case .sendFailed: String(localized: "error.wol.send", bundle: .module)
        }
    }
}

/// Builds and sends Wake-on-LAN magic packets. The packet builder is pure
/// and unit-tested; sending uses a broadcast-enabled UDP socket.
enum WakeOnLAN {

    /// A magic packet: 6 bytes of 0xFF followed by the target MAC repeated
    /// 16 times (102 bytes total).
    static func magicPacket(for mac: MACAddress) -> Data {
        var data = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            data.append(contentsOf: mac.octets)
        }
        return data
    }

    /// Sends the magic packet to a broadcast address on the given UDP port
    /// (typically 9, sometimes 7).
    static func send(
        macText: String, broadcast: String = "255.255.255.255", port: UInt16 = 9
    ) -> Result<Void, WakeOnLANError> {
        let mac: MACAddress
        do {
            mac = try MACAddress(parsing: macText)
        } catch {
            return .failure(.invalidMAC)
        }
        let packet = magicPacket(for: mac)

        #if canImport(Darwin)
        let handle = socket(AF_INET, SOCK_DGRAM, 0)
        guard handle >= 0 else { return .failure(.socketFailed) }
        defer { close(handle) }

        var broadcastEnable: Int32 = 1
        guard setsockopt(
            handle, SOL_SOCKET, SO_BROADCAST,
            &broadcastEnable, socklen_t(MemoryLayout<Int32>.size)
        ) == 0 else { return .failure(.socketFailed) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        // inet_pton handles 255.255.255.255 correctly (inet_addr can't —
        // its all-ones result is indistinguishable from its error value).
        let parsed = broadcast.withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        guard parsed == 1 else { return .failure(.sendFailed) }

        let sent = packet.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &address) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(
                        handle, buffer.baseAddress, buffer.count, 0,
                        sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
        return sent == packet.count ? .success(()) : .failure(.sendFailed)
        #else
        return .failure(.socketFailed)
        #endif
    }
}
