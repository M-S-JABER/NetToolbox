import Foundation

/// Minimal Telnet (RFC 854) byte processing: strips IAC command sequences
/// from the display stream and generates polite refusals so a session can
/// proceed in line mode. Pure and unit-tested.
enum TelnetProtocol {
    static let iac: UInt8 = 255
    static let dont: UInt8 = 254
    static let doo: UInt8 = 253      // DO
    static let wont: UInt8 = 252
    static let will: UInt8 = 251
    static let sb: UInt8 = 250       // subnegotiation begin
    static let se: UInt8 = 240       // subnegotiation end

    struct Processed: Equatable {
        let text: String
        let reply: [UInt8]
    }

    /// Splits an incoming buffer into printable text plus the bytes to send
    /// back in response to option negotiation.
    static func process(_ bytes: [UInt8]) -> Processed {
        var display: [UInt8] = []
        var reply: [UInt8] = []
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]
            guard byte == iac else {
                display.append(byte)
                index += 1
                continue
            }
            // IAC encountered.
            guard index + 1 < bytes.count else { break }
            let command = bytes[index + 1]

            switch command {
            case iac:
                // Escaped 0xFF literal.
                display.append(iac)
                index += 2
            case doo, dont, will, wont:
                guard index + 2 < bytes.count else { index = bytes.count; break }
                let option = bytes[index + 2]
                switch command {
                case doo:  reply.append(contentsOf: [iac, wont, option])
                case will: reply.append(contentsOf: [iac, dont, option])
                default:   break   // peer's DONT/WONT need no reply
                }
                index += 3
            case sb:
                // Skip to the matching IAC SE.
                var cursor = index + 2
                while cursor + 1 < bytes.count, !(bytes[cursor] == iac && bytes[cursor + 1] == se) {
                    cursor += 1
                }
                index = cursor + 2
            default:
                index += 2
            }
        }

        return Processed(text: String(decoding: display, as: UTF8.self), reply: reply)
    }
}
