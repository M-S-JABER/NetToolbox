import Foundation

/// Supported DNS record types.
enum DNSRecordType: UInt16, CaseIterable, Identifiable, Sendable {
    case a = 1
    case ns = 2
    case cname = 5
    case soa = 6
    case ptr = 12
    case mx = 15
    case txt = 16
    case aaaa = 28

    var id: UInt16 { rawValue }
    var label: String {
        switch self {
        case .a: "A"
        case .ns: "NS"
        case .cname: "CNAME"
        case .soa: "SOA"
        case .ptr: "PTR"
        case .mx: "MX"
        case .txt: "TXT"
        case .aaaa: "AAAA"
        }
    }
}

/// A single parsed answer record (value rendered as display text).
struct DNSRecord: Identifiable, Equatable, Sendable {
    let name: String
    let type: DNSRecordType
    let ttl: UInt32
    let value: String

    var id: String { "\(name)-\(type.label)-\(value)" }
}

/// Errors from the DNS codec.
enum DNSError: LocalizedError, Equatable {
    case emptyName
    case malformedResponse
    case truncated

    var errorDescription: String? {
        switch self {
        case .emptyName: String(localized: "error.dns.emptyName", bundle: .module)
        case .malformedResponse: String(localized: "error.dns.malformed", bundle: .module)
        case .truncated: String(localized: "error.dns.truncated", bundle: .module)
        }
    }
}

/// Pure DNS wire-format encoder/decoder (RFC 1035). No networking — the
/// transport is provided by `UDPExchange`, keeping this fully testable.
enum DNSMessage {

    // MARK: Query encoding

    /// Builds a standard recursive query for `name`/`type` with the given ID.
    static func encodeQuery(name: String, type: DNSRecordType, id: UInt16) throws -> Data {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw DNSError.emptyName }

        var data = Data()
        data.appendUInt16(id)
        data.appendUInt16(0x0100)          // flags: recursion desired
        data.appendUInt16(1)               // QDCOUNT
        data.appendUInt16(0)               // ANCOUNT
        data.appendUInt16(0)               // NSCOUNT
        data.appendUInt16(0)               // ARCOUNT
        data.append(encodeName(trimmed))
        data.appendUInt16(type.rawValue)   // QTYPE
        data.appendUInt16(1)               // QCLASS = IN
        return data
    }

    /// Encodes a domain name as a sequence of length-prefixed labels.
    static func encodeName(_ name: String) -> Data {
        var data = Data()
        let labels = name.split(separator: ".", omittingEmptySubsequences: true)
        for label in labels {
            let bytes = Array(label.utf8.prefix(63))
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
        data.append(0)
        return data
    }

    // MARK: Response decoding

    /// Parses the answer section of a response into records.
    static func decodeAnswers(_ data: Data) throws -> [DNSRecord] {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { throw DNSError.truncated }

        let questionCount = Int(bytes.readUInt16(at: 4))
        let answerCount = Int(bytes.readUInt16(at: 6))

        var offset = 12
        for _ in 0..<questionCount {
            offset = try skipName(bytes, at: offset)
            offset += 4                    // QTYPE + QCLASS
        }

        var records: [DNSRecord] = []
        for _ in 0..<answerCount {
            let (name, afterName) = try readName(bytes, at: offset)
            offset = afterName
            guard offset + 10 <= bytes.count else { throw DNSError.truncated }
            let rawType = bytes.readUInt16(at: offset)
            let ttl = bytes.readUInt32(at: offset + 4)
            let rdLength = Int(bytes.readUInt16(at: offset + 8))
            let rdStart = offset + 10
            guard rdStart + rdLength <= bytes.count else { throw DNSError.truncated }

            if let type = DNSRecordType(rawValue: rawType) {
                let value = try renderRData(
                    bytes, type: type, rdStart: rdStart, rdLength: rdLength
                )
                records.append(DNSRecord(name: name, type: type, ttl: ttl, value: value))
            }
            offset = rdStart + rdLength
        }
        return records
    }

    // MARK: RDATA rendering

    private static func renderRData(
        _ bytes: [UInt8], type: DNSRecordType, rdStart: Int, rdLength: Int
    ) throws -> String {
        switch type {
        case .a:
            guard rdLength == 4 else { throw DNSError.malformedResponse }
            return "\(bytes[rdStart]).\(bytes[rdStart + 1]).\(bytes[rdStart + 2]).\(bytes[rdStart + 3])"
        case .aaaa:
            guard rdLength == 16 else { throw DNSError.malformedResponse }
            var hextets: [String] = []
            var index = rdStart
            while index < rdStart + 16 {
                let value = (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
                hextets.append(String(value, radix: 16))
                index += 2
            }
            return hextets.joined(separator: ":")
        case .ns, .cname, .ptr:
            return try readName(bytes, at: rdStart).0
        case .mx:
            guard rdLength >= 3 else { throw DNSError.malformedResponse }
            let preference = bytes.readUInt16(at: rdStart)
            let exchange = try readName(bytes, at: rdStart + 2).0
            return "\(preference) \(exchange)"
        case .txt:
            var parts: [String] = []
            var index = rdStart
            let end = rdStart + rdLength
            while index < end {
                let length = Int(bytes[index])
                index += 1
                guard index + length <= end else { break }
                parts.append(String(decoding: bytes[index..<index + length], as: UTF8.self))
                index += length
            }
            return parts.joined()
        case .soa:
            let (mname, afterM) = try readName(bytes, at: rdStart)
            let (rname, _) = try readName(bytes, at: afterM)
            return "\(mname) \(rname)"
        }
    }

    // MARK: Name reading (with compression pointers)

    /// Reads a possibly-compressed domain name, returning the text and the
    /// offset just past the name in the record stream.
    static func readName(_ bytes: [UInt8], at start: Int) throws -> (String, Int) {
        var labels: [String] = []
        var offset = start
        var jumped = false
        var afterPointer = start
        var safety = 0

        while true {
            safety += 1
            guard safety < 128 else { throw DNSError.malformedResponse }
            guard offset < bytes.count else { throw DNSError.truncated }
            let length = bytes[offset]

            if length & 0xC0 == 0xC0 {
                guard offset + 1 < bytes.count else { throw DNSError.truncated }
                let pointer = (Int(length & 0x3F) << 8) | Int(bytes[offset + 1])
                if !jumped { afterPointer = offset + 2 }
                jumped = true
                offset = pointer
                continue
            }
            if length == 0 {
                offset += 1
                break
            }
            let labelStart = offset + 1
            let labelEnd = labelStart + Int(length)
            guard labelEnd <= bytes.count else { throw DNSError.truncated }
            labels.append(String(decoding: bytes[labelStart..<labelEnd], as: UTF8.self))
            offset = labelEnd
        }

        let name = labels.joined(separator: ".")
        return (name, jumped ? afterPointer : offset)
    }

    private static func skipName(_ bytes: [UInt8], at start: Int) throws -> Int {
        try readName(bytes, at: start).1
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }
}

private extension Array where Element == UInt8 {
    func readUInt16(at index: Int) -> UInt16 {
        (UInt16(self[index]) << 8) | UInt16(self[index + 1])
    }
    func readUInt32(at index: Int) -> UInt32 {
        (UInt32(self[index]) << 24) | (UInt32(self[index + 1]) << 16)
            | (UInt32(self[index + 2]) << 8) | UInt32(self[index + 3])
    }
}
