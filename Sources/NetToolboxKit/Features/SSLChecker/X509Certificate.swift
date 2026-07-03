import Foundation

/// A minimal DER (ASN.1) reader: reads one tag/length/value element at a
/// time from a byte buffer. Enough to walk an X.509 certificate to its
/// validity dates — the constants needed for the higher-level API
/// (`SecCertificateCopyValues`, `kSecOID…`) exist only on macOS, not iOS.
struct DERReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    /// Reads the next element, returning its tag and raw value bytes.
    mutating func readElement() -> (tag: UInt8, value: [UInt8])? {
        guard offset < bytes.count else { return nil }
        let tag = bytes[offset]
        offset += 1
        guard offset < bytes.count else { return nil }

        var length = Int(bytes[offset])
        offset += 1
        if length & 0x80 != 0 {
            let count = length & 0x7F
            guard count > 0, offset + count <= bytes.count else { return nil }
            length = 0
            for _ in 0..<count {
                length = (length << 8) | Int(bytes[offset])
                offset += 1
            }
        }
        guard offset + length <= bytes.count else { return nil }
        let value = Array(bytes[offset..<offset + length])
        offset += length
        return (tag, value)
    }
}

/// X.509 parsing helpers (pure, unit-tested).
enum X509 {
    static let utcTimeTag: UInt8 = 0x17
    static let generalizedTimeTag: UInt8 = 0x18

    /// Extracts (notBefore, notAfter) from a DER-encoded certificate by
    /// walking `Certificate → tbsCertificate → validity`.
    static func validity(fromDER data: Data) -> (notBefore: Date?, notAfter: Date?) {
        var certificate = DERReader([UInt8](data))
        // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signature }
        guard let cert = certificate.readElement(), cert.tag == 0x30 else { return (nil, nil) }
        var certBody = DERReader(cert.value)
        guard let tbs = certBody.readElement(), tbs.tag == 0x30 else { return (nil, nil) }

        // TBSCertificate ::= SEQUENCE {
        //   version [0] (optional), serialNumber, signature,
        //   issuer, validity, subject, ... }
        var tbsBody = DERReader(tbs.value)
        guard var element = tbsBody.readElement() else { return (nil, nil) }
        if element.tag == 0xA0 {                 // explicit [0] version — skip
            guard let serial = tbsBody.readElement() else { return (nil, nil) }
            element = serial
        }
        // `element` is now serialNumber; skip signature and issuer.
        guard tbsBody.readElement() != nil else { return (nil, nil) }   // signature
        guard tbsBody.readElement() != nil else { return (nil, nil) }   // issuer
        guard let validity = tbsBody.readElement(), validity.tag == 0x30 else { return (nil, nil) }

        var validityBody = DERReader(validity.value)
        guard let notBefore = validityBody.readElement(),
              let notAfter = validityBody.readElement() else { return (nil, nil) }
        return (
            parseTime(tag: notBefore.tag, bytes: notBefore.value),
            parseTime(tag: notAfter.tag, bytes: notAfter.value)
        )
    }

    /// Parses an ASN.1 UTCTime / GeneralizedTime value into a `Date`.
    static func parseTime(tag: UInt8, bytes: [UInt8]) -> Date? {
        var text = String(decoding: bytes, as: UTF8.self)
        if text.hasSuffix("Z") { text.removeLast() }
        let digits = Array(text)

        func number(_ start: Int, _ length: Int) -> Int? {
            guard start + length <= digits.count else { return nil }
            return Int(String(digits[start..<start + length]))
        }

        var components = DateComponents()
        switch tag {
        case utcTimeTag:
            guard digits.count >= 10,
                  let yy = number(0, 2), let month = number(2, 2), let day = number(4, 2),
                  let hour = number(6, 2), let minute = number(8, 2) else { return nil }
            components.year = yy >= 50 ? 1900 + yy : 2000 + yy
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = number(10, 2) ?? 0
        case generalizedTimeTag:
            guard digits.count >= 12,
                  let year = number(0, 4), let month = number(4, 2), let day = number(6, 2),
                  let hour = number(8, 2), let minute = number(10, 2) else { return nil }
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = number(12, 2) ?? 0
        default:
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components)
    }
}
