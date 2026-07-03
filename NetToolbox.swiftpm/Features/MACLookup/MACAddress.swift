import Foundation

/// Errors thrown while parsing MAC addresses.
enum MACAddressError: LocalizedError, Equatable {
    case invalidFormat

    var errorDescription: String? {
        String(localized: "error.mac.invalid")
    }
}

/// A parsed, normalized 48-bit MAC address.
/// Accepts any common input format: "AA:BB:CC:DD:EE:FF", "aa-bb-cc-dd-ee-ff",
/// "aabb.ccdd.eeff" (Cisco), or a raw "aabbccddeeff".
struct MACAddress: Equatable, Sendable {
    /// Six octets, most significant first.
    let octets: [UInt8]

    init(parsing text: String) throws {
        let separators = CharacterSet(charactersIn: ":-. \t")
        let hex = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: separators)
            .joined()
            .uppercased()

        guard hex.count == 12, hex.allSatisfy(\.isHexDigit) else {
            throw MACAddressError.invalidFormat
        }

        var parsed: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let octet = UInt8(hex[index..<next], radix: 16) else {
                throw MACAddressError.invalidFormat
            }
            parsed.append(octet)
            index = next
        }
        octets = parsed
    }

    /// Canonical colon form: "AA:BB:CC:DD:EE:FF".
    var normalized: String {
        octets.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Cisco dotted form: "aabb.ccdd.eeff".
    var ciscoNotation: String {
        let flat = octets.map { String(format: "%02x", $0) }.joined()
        return stride(from: 0, to: 12, by: 4)
            .map { offset -> String in
                let start = flat.index(flat.startIndex, offsetBy: offset)
                let end = flat.index(start, offsetBy: 4)
                return String(flat[start..<end])
            }
            .joined(separator: ".")
    }

    /// First three octets as an uppercase hex key, e.g. "F0189D".
    var ouiKey: String {
        octets.prefix(3).map { String(format: "%02X", $0) }.joined()
    }

    /// I/G bit — `true` when the address targets a group (multicast).
    var isMulticast: Bool {
        octets[0] & 0b0000_0001 != 0
    }

    /// U/L bit — `true` when locally administered (randomized/private MACs
    /// on iOS and Android set this bit).
    var isLocallyAdministered: Bool {
        octets[0] & 0b0000_0010 != 0
    }
}
