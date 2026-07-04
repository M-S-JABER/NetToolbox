import Foundation

/// Errors from the SNMP codec.
enum SNMPError: LocalizedError, Equatable {
    case invalidOID
    case encodingFailed
    case malformedResponse
    case noVarbind

    var errorDescription: String? {
        switch self {
        case .invalidOID: String(localized: "error.snmp.invalidOID", bundle: .module)
        case .encodingFailed: String(localized: "error.snmp.encoding", bundle: .module)
        case .malformedResponse: String(localized: "error.snmp.malformed", bundle: .module)
        case .noVarbind: String(localized: "error.snmp.noVarbind", bundle: .module)
        }
    }
}

/// A decoded SNMP variable binding.
struct SNMPVarbind: Equatable, Sendable {
    let oid: String
    let typeName: String
    let value: String
}

/// Minimal BER/DER codec for SNMP v2c GET requests (RFC 1157/3416).
/// Pure and unit-tested; the transport is `UDPExchange`.
enum SNMPMessage {

    // MARK: BER primitives

    /// Encodes a definite BER length.
    static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 0x80 { return [UInt8(length)] }
        var value = length
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    /// Wraps content in a tag + length + value triple.
    static func encodeTLV(tag: UInt8, content: [UInt8]) -> [UInt8] {
        [tag] + encodeLength(content.count) + content
    }

    static func encodeInteger(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var current = value
        if current == 0 {
            bytes = [0]
        } else {
            while current != 0 && current != -1 {
                bytes.insert(UInt8(current & 0xFF), at: 0)
                current >>= 8
            }
            // Ensure correct sign bit for positive values.
            if value > 0, let first = bytes.first, first & 0x80 != 0 {
                bytes.insert(0, at: 0)
            }
            if bytes.isEmpty { bytes = [0] }
        }
        return encodeTLV(tag: 0x02, content: bytes)
    }

    static func encodeOctetString(_ text: String) -> [UInt8] {
        encodeTLV(tag: 0x04, content: Array(text.utf8))
    }

    /// Encodes a dotted OID such as "1.3.6.1.2.1.1.1.0".
    static func encodeOID(_ oid: String) throws -> [UInt8] {
        let parts = oid.split(separator: ".").map { Int($0) }
        guard parts.count >= 2, !parts.contains(where: { $0 == nil }) else {
            throw SNMPError.invalidOID
        }
        let numbers = parts.compactMap { $0 }
        guard numbers[0] <= 6, numbers[1] < 40 else { throw SNMPError.invalidOID }

        var content: [UInt8] = [UInt8(numbers[0] * 40 + numbers[1])]
        for number in numbers.dropFirst(2) {
            content.append(contentsOf: encodeBase128(number))
        }
        return encodeTLV(tag: 0x06, content: content)
    }

    /// Base-128 with continuation bits, used for OID sub-identifiers.
    static func encodeBase128(_ value: Int) -> [UInt8] {
        guard value > 0 else { return [0] }
        var bytes: [UInt8] = []
        var current = value
        while current > 0 {
            bytes.insert(UInt8(current & 0x7F), at: 0)
            current >>= 7
        }
        for index in 0..<(bytes.count - 1) {
            bytes[index] |= 0x80
        }
        return bytes
    }

    // MARK: GET request

    /// Builds a full SNMP v2c GET request PDU.
    static func encodeGet(oid: String, community: String, requestID: Int) throws -> Data {
        try encodeRequest(pduTag: 0xA0, oid: oid, community: community, requestID: requestID)
    }

    /// Builds a GetNextRequest PDU — the basis for SNMP walks.
    static func encodeGetNext(oid: String, community: String, requestID: Int) throws -> Data {
        try encodeRequest(pduTag: 0xA1, oid: oid, community: community, requestID: requestID)
    }

    private static func encodeRequest(pduTag: UInt8, oid: String, community: String, requestID: Int) throws -> Data {
        let oidBytes = try encodeOID(oid)
        let nullValue: [UInt8] = [0x05, 0x00]
        let varbind = encodeTLV(tag: 0x30, content: oidBytes + nullValue)
        let varbindList = encodeTLV(tag: 0x30, content: varbind)

        let pduBody = encodeInteger(requestID)
            + encodeInteger(0)             // error-status
            + encodeInteger(0)             // error-index
            + varbindList
        let pdu = encodeTLV(tag: pduTag, content: pduBody)

        let message = encodeInteger(1)     // version = 1 (v2c)
            + encodeOctetString(community)
            + pdu
        let full = encodeTLV(tag: 0x30, content: message)
        return Data(full)
    }

    // MARK: Response decoding

    /// Extracts the first variable binding from a response PDU.
    static func decodeResponse(_ data: Data) throws -> SNMPVarbind {
        let bytes = [UInt8](data)
        var cursor = 0

        func readTLV() throws -> (tag: UInt8, valueRange: Range<Int>) {
            guard cursor < bytes.count else { throw SNMPError.malformedResponse }
            let tag = bytes[cursor]
            cursor += 1
            guard cursor < bytes.count else { throw SNMPError.malformedResponse }
            var length = Int(bytes[cursor])
            cursor += 1
            if length & 0x80 != 0 {
                let count = length & 0x7F
                guard count > 0, cursor + count <= bytes.count else {
                    throw SNMPError.malformedResponse
                }
                length = 0
                for _ in 0..<count {
                    length = (length << 8) | Int(bytes[cursor])
                    cursor += 1
                }
            }
            let start = cursor
            let end = start + length
            guard end <= bytes.count else { throw SNMPError.malformedResponse }
            return (tag, start..<end)
        }

        // Reads a primitive TLV and advances the cursor past its value.
        func readPrimitive() throws -> (tag: UInt8, valueRange: Range<Int>) {
            let tlv = try readTLV()
            cursor = tlv.valueRange.endIndex
            return tlv
        }

        // SEQUENCE { version, community, PDU }.  Constructed types are
        // descended into (cursor left at their content); primitives are
        // skipped over.
        let outer = try readTLV()
        guard outer.tag == 0x30 else { throw SNMPError.malformedResponse }
        _ = try readPrimitive()             // version
        _ = try readPrimitive()             // community

        _ = try readTLV()                   // Response PDU (0xA2) — descend
        _ = try readPrimitive()             // request-id
        _ = try readPrimitive()             // error-status
        _ = try readPrimitive()             // error-index

        let varbindList = try readTLV()     // SEQUENCE OF varbind — descend
        guard varbindList.tag == 0x30 else { throw SNMPError.malformedResponse }

        let varbind = try readTLV()         // first varbind SEQUENCE — descend
        guard varbind.tag == 0x30 else { throw SNMPError.noVarbind }

        let oidTLV = try readPrimitive()    // OID
        guard oidTLV.tag == 0x06 else { throw SNMPError.noVarbind }
        let oid = decodeOID(Array(bytes[oidTLV.valueRange]))

        let valueTLV = try readPrimitive()  // value
        let (typeName, valueText) = renderValue(tag: valueTLV.tag, bytes: Array(bytes[valueTLV.valueRange]))
        return SNMPVarbind(oid: oid, typeName: typeName, value: valueText)
    }

    static func decodeOID(_ content: [UInt8]) -> String {
        guard let first = content.first else { return "" }
        var parts = [Int(first) / 40, Int(first) % 40]
        var value = 0
        for byte in content.dropFirst() {
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                parts.append(value)
                value = 0
            }
        }
        return parts.map(String.init).joined(separator: ".")
    }

    private static func renderValue(tag: UInt8, bytes: [UInt8]) -> (String, String) {
        switch tag {
        case 0x04:
            let printable = bytes.allSatisfy { $0 == 0x09 || $0 == 0x0A || $0 == 0x0D || (0x20...0x7E).contains($0) }
            let text = printable
                ? String(decoding: bytes, as: UTF8.self)
                : bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            return ("OCTET STRING", text)
        case 0x02:
            return ("INTEGER", String(decodeSignedInteger(bytes)))
        case 0x06:
            return ("OID", decodeOID(bytes))
        case 0x40:
            return ("IpAddress", bytes.map(String.init).joined(separator: "."))
        case 0x41:
            return ("Counter32", String(decodeUnsignedInteger(bytes)))
        case 0x42:
            return ("Gauge32", String(decodeUnsignedInteger(bytes)))
        case 0x43:
            let ticks = decodeUnsignedInteger(bytes)
            return ("TimeTicks", "\(ticks) (\(ticks / 100)s)")
        case 0x46:
            return ("Counter64", String(decodeUnsignedInteger(bytes)))
        case 0x05:
            return ("NULL", "")
        default:
            return ("0x\(String(format: "%02X", tag))", bytes.map { String(format: "%02X", $0) }.joined())
        }
    }

    static func decodeUnsignedInteger(_ bytes: [UInt8]) -> UInt64 {
        bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    static func decodeSignedInteger(_ bytes: [UInt8]) -> Int64 {
        guard let first = bytes.first else { return 0 }
        var value = Int64(first & 0x7F)
        if first & 0x80 != 0 { value -= Int64(0x80) }
        for byte in bytes.dropFirst() {
            value = (value << 8) | Int64(byte)
        }
        return value
    }
}
