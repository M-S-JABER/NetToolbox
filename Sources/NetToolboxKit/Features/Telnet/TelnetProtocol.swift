import Foundation

/// Telnet (RFC 854 + options) byte processing: strips IAC command sequences
/// from the display stream and negotiates the options a modern client should,
/// so the session behaves properly against routers, switches and BBS hosts
/// instead of staying in bare line mode. Pure and unit-tested.
///
/// Negotiated: it agrees to send a terminal type (TTYPE → "xterm") and its
/// window size (NAWS → 80×24), suppresses go-ahead (SGA), and lets the server
/// echo (accepts WILL ECHO/SGA). Everything else is politely refused.
enum TelnetProtocol {
    static let iac: UInt8 = 255
    static let dont: UInt8 = 254
    static let doo: UInt8 = 253      // DO
    static let wont: UInt8 = 252
    static let will: UInt8 = 251
    static let sb: UInt8 = 250       // subnegotiation begin
    static let se: UInt8 = 240       // subnegotiation end

    // Options.
    static let optEcho: UInt8 = 1
    static let optSGA: UInt8 = 3     // suppress go-ahead
    static let optTType: UInt8 = 24  // terminal type
    static let optNAWS: UInt8 = 31   // negotiate about window size

    // Sub-negotiation qualifiers.
    static let sbIS: UInt8 = 0
    static let sbSEND: UInt8 = 1

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
                reply.append(contentsOf: response(command: command, option: option))
                index += 3
            case sb:
                // Capture the sub-negotiation payload up to IAC SE.
                var cursor = index + 2
                var content: [UInt8] = []
                while cursor + 1 < bytes.count, !(bytes[cursor] == iac && bytes[cursor + 1] == se) {
                    content.append(bytes[cursor])
                    cursor += 1
                }
                reply.append(contentsOf: subnegotiationReply(content))
                index = cursor + 2
            default:
                index += 2
            }
        }

        return Processed(text: String(decoding: display, as: UTF8.self), reply: reply)
    }

    /// The reply to a DO/WILL negotiation. DONT/WONT are acknowledgements that
    /// need no reply (replying would risk a negotiation loop).
    private static func response(command: UInt8, option: UInt8) -> [UInt8] {
        switch command {
        case doo:   // server asks us to enable an option
            switch option {
            case optTType: return [iac, will, optTType]
            case optSGA:   return [iac, will, optSGA]
            case optNAWS:  return [iac, will, optNAWS] + windowSize()
            default:       return [iac, wont, option]
            }
        case will:  // server offers to enable an option on its side
            switch option {
            case optEcho: return [iac, doo, optEcho]   // let the server echo
            case optSGA:  return [iac, doo, optSGA]
            default:      return [iac, dont, option]
            }
        default:
            return []
        }
    }

    /// IAC SB NAWS <cols:2> <rows:2> IAC SE, advertising an 80×24 window.
    private static func windowSize(cols: UInt16 = 80, rows: UInt16 = 24) -> [UInt8] {
        [iac, sb, optNAWS,
         UInt8(cols >> 8), UInt8(cols & 0xFF),
         UInt8(rows >> 8), UInt8(rows & 0xFF),
         iac, se]
    }

    /// Answers a `SB TTYPE SEND` with `SB TTYPE IS "xterm"`.
    private static func subnegotiationReply(_ content: [UInt8]) -> [UInt8] {
        guard content.count >= 2, content[0] == optTType, content[1] == sbSEND else { return [] }
        return [iac, sb, optTType, sbIS] + Array("xterm".utf8) + [iac, se]
    }
}
