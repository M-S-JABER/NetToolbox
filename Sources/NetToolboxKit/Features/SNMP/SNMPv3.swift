import Foundation
import CryptoKit

// MARK: - USM authentication (RFC 3414)

/// Authentication protocol for SNMPv3 User-based Security Model.
/// Only the two historic HMAC protocols are offered — they are the ones
/// available from CryptoKit's `Insecure` hashes with zero dependencies.
enum SNMPv3Auth: String, CaseIterable, Identifiable, Sendable {
    case md5, sha

    var id: String { rawValue }
    var displayName: String { self == .md5 ? "HMAC-MD5" : "HMAC-SHA1" }
    /// Full digest length; also the length of the localized key.
    var digestLength: Int { self == .md5 ? 16 : 20 }
    /// Bytes of the HMAC kept in msgAuthenticationParameters.
    var truncatedLength: Int { 12 }
}

/// The User-based Security Model key-derivation and message digest.
/// All functions are pure and covered by RFC 3414 test vectors.
enum SNMPv3USM {

    /// RFC 3414 §A.2 — expand the password to one megabyte, then hash it.
    static func passwordToKey(password: String, auth: SNMPv3Auth) -> [UInt8] {
        let pass = Array(password.utf8)
        guard !pass.isEmpty else { return hash([], auth: auth) }
        var buffer = [UInt8](repeating: 0, count: 64)
        var index = 0
        var count = 0
        var md5 = Insecure.MD5()
        var sha = Insecure.SHA1()
        while count < 1_048_576 {
            for position in 0..<64 {
                buffer[position] = pass[index % pass.count]
                index += 1
            }
            let chunk = Data(buffer)
            switch auth {
            case .md5: md5.update(data: chunk)
            case .sha: sha.update(data: chunk)
            }
            count += 64
        }
        switch auth {
        case .md5: return Array(md5.finalize())
        case .sha: return Array(sha.finalize())
        }
    }

    /// RFC 3414 §2.6 — localize the key to an engine: Kul = H(Ku ‖ engineID ‖ Ku).
    static func localizedKey(password: String, engineID: [UInt8], auth: SNMPv3Auth) -> [UInt8] {
        let ku = passwordToKey(password: password, auth: auth)
        return hash(ku + engineID + ku, auth: auth)
    }

    static func hash(_ bytes: [UInt8], auth: SNMPv3Auth) -> [UInt8] {
        let data = Data(bytes)
        switch auth {
        case .md5: return Array(Insecure.MD5.hash(data: data))
        case .sha: return Array(Insecure.SHA1.hash(data: data))
        }
    }

    /// HMAC over `message` with the localized key, truncated per RFC 3414 §6.3.1.
    static func authParameters(key: [UInt8], message: [UInt8], auth: SNMPv3Auth) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))
        let data = Data(message)
        let full: [UInt8]
        switch auth {
        case .md5:
            full = Array(HMAC<Insecure.MD5>.authenticationCode(for: data, using: symmetricKey))
        case .sha:
            full = Array(HMAC<Insecure.SHA1>.authenticationCode(for: data, using: symmetricKey))
        }
        return Array(full.prefix(auth.truncatedLength))
    }
}

// MARK: - v3 message codec

/// Builds and parses SNMPv3 messages for engine discovery and authNoPriv GET.
/// Privacy (encryption) is intentionally out of scope — authNoPriv only.
enum SNMPv3Message {

    struct Engine: Equatable, Sendable {
        var id: [UInt8]
        var boots: Int
        var time: Int
    }

    struct Decoded: Sendable {
        var engine: Engine
        var varbind: SNMPVarbind?
        var reportOID: String?
    }

    private static func octetString(_ bytes: [UInt8]) -> [UInt8] {
        SNMPMessage.encodeTLV(tag: 0x04, content: bytes)
    }

    /// Scoped PDU: SEQUENCE { contextEngineID, contextName, PDU }.
    private static func scopedPDU(engineID: [UInt8], pdu: [UInt8]) -> [UInt8] {
        SNMPMessage.encodeTLV(tag: 0x30, content: octetString(engineID) + octetString([]) + pdu)
    }

    /// A GET PDU (tag 0xA0). A nil OID yields an empty varbind list — used for discovery.
    private static func getPDU(oid: String?, requestID: Int) throws -> [UInt8] {
        var varbindList: [UInt8] = []
        if let oid {
            let varbind = SNMPMessage.encodeTLV(tag: 0x30, content: try SNMPMessage.encodeOID(oid) + [0x05, 0x00])
            varbindList = varbind
        }
        let list = SNMPMessage.encodeTLV(tag: 0x30, content: varbindList)
        let body = SNMPMessage.encodeInteger(requestID)
            + SNMPMessage.encodeInteger(0)   // error-status
            + SNMPMessage.encodeInteger(0)   // error-index
            + list
        return SNMPMessage.encodeTLV(tag: 0xA0, content: body)
    }

    private static func globalData(msgID: Int, flags: UInt8) -> [UInt8] {
        let content = SNMPMessage.encodeInteger(msgID)
            + SNMPMessage.encodeInteger(65_507)          // msgMaxSize
            + SNMPMessage.encodeTLV(tag: 0x04, content: [flags])
            + SNMPMessage.encodeInteger(3)               // msgSecurityModel = USM
        return SNMPMessage.encodeTLV(tag: 0x30, content: content)
    }

    /// Discovery probe: noAuthNoPriv, empty engine, reportable flag set.
    static func encodeDiscovery(msgID: Int) throws -> Data {
        let usm = SNMPMessage.encodeTLV(tag: 0x30, content:
            octetString([])                              // engineID
            + SNMPMessage.encodeInteger(0)               // boots
            + SNMPMessage.encodeInteger(0)               // time
            + octetString([])                            // userName
            + octetString([])                            // authParams
            + octetString([]))                           // privParams
        let message = SNMPMessage.encodeInteger(3)
            + globalData(msgID: msgID, flags: 0x04)      // reportable only
            + octetString(usm)
            + scopedPDU(engineID: [], pdu: try getPDU(oid: nil, requestID: msgID))
        return Data(SNMPMessage.encodeTLV(tag: 0x30, content: message))
    }

    /// authNoPriv GET. Assembles the message with a zeroed auth field, HMACs
    /// the whole datagram, then patches the 12-byte authentication parameters
    /// back in (RFC 3414 §6.3.1).
    static func encodeAuthGet(
        msgID: Int, oid: String, user: String,
        engine: Engine, authKey: [UInt8], auth: SNMPv3Auth
    ) throws -> Data {
        let engineOctet = octetString(engine.id)
        let bootsInt = SNMPMessage.encodeInteger(engine.boots)
        let timeInt = SNMPMessage.encodeInteger(engine.time)
        let userOctet = octetString(Array(user.utf8))
        let placeholder = [UInt8](repeating: 0, count: auth.truncatedLength)
        let authOctet = octetString(placeholder)          // [0x04, len] + zeros
        let privOctet = octetString([])

        let usmContent = engineOctet + bootsInt + timeInt + userOctet + authOctet + privOctet
        let usmSeq = SNMPMessage.encodeTLV(tag: 0x30, content: usmContent)
        let secParams = octetString(usmSeq)

        let version = SNMPMessage.encodeInteger(3)
        let header = globalData(msgID: msgID, flags: 0x05)   // reportable + auth
        let scoped = scopedPDU(engineID: engine.id, pdu: try getPDU(oid: oid, requestID: msgID))

        let body = version + header + secParams + scoped
        var full = SNMPMessage.encodeTLV(tag: 0x30, content: body)

        // Absolute offset of the auth-parameter value inside `full`.
        let messageHeader = 1 + SNMPMessage.encodeLength(body.count).count
        let secParamsHeader = 1 + SNMPMessage.encodeLength(usmSeq.count).count
        let usmSeqHeader = 1 + SNMPMessage.encodeLength(usmContent.count).count
        let authValueOffset = messageHeader
            + version.count + header.count
            + secParamsHeader + usmSeqHeader
            + engineOctet.count + bootsInt.count + timeInt.count + userOctet.count
            + 2                                              // authOctet tag + length
        guard authValueOffset + auth.truncatedLength <= full.count,
              full[authValueOffset - 2] == 0x04,
              full[authValueOffset - 1] == UInt8(auth.truncatedLength) else {
            throw SNMPError.encodingFailed
        }

        let mac = SNMPv3USM.authParameters(key: authKey, message: full, auth: auth)
        for index in 0..<auth.truncatedLength { full[authValueOffset + index] = mac[index] }
        return Data(full)
    }

    /// Parses a v3 response — pulls the authoritative engine params out of the
    /// USM security parameters and, if present, the first varbind or report OID.
    static func decode(_ data: Data) throws -> Decoded {
        let bytes = [UInt8](data)
        var cursor = 0

        func readTLV() throws -> (tag: UInt8, range: Range<Int>) {
            guard cursor < bytes.count else { throw SNMPError.malformedResponse }
            let tag = bytes[cursor]; cursor += 1
            guard cursor < bytes.count else { throw SNMPError.malformedResponse }
            var length = Int(bytes[cursor]); cursor += 1
            if length & 0x80 != 0 {
                let count = length & 0x7F
                guard count > 0, cursor + count <= bytes.count else { throw SNMPError.malformedResponse }
                length = 0
                for _ in 0..<count { length = (length << 8) | Int(bytes[cursor]); cursor += 1 }
            }
            let start = cursor
            let end = start + length
            guard end <= bytes.count else { throw SNMPError.malformedResponse }
            return (tag, start..<end)
        }
        func skip() throws { let tlv = try readTLV(); cursor = tlv.range.endIndex }

        let outer = try readTLV()
        guard outer.tag == 0x30 else { throw SNMPError.malformedResponse }
        try skip()                                  // msgVersion
        try skip()                                  // msgGlobalData

        // msgSecurityParameters: OCTET STRING wrapping a USM SEQUENCE.
        let secParams = try readTLV()
        guard secParams.tag == 0x04 else { throw SNMPError.malformedResponse }
        var engine = Engine(id: [], boots: 0, time: 0)
        do {
            let saved = secParams.range.endIndex   // resume at msgData afterwards
            cursor = secParams.range.startIndex
            let usm = try readTLV()
            guard usm.tag == 0x30 else { throw SNMPError.malformedResponse }
            let engineTLV = try readTLV(); cursor = engineTLV.range.endIndex
            engine.id = Array(bytes[engineTLV.range])
            let bootsTLV = try readTLV(); cursor = bootsTLV.range.endIndex
            engine.boots = Int(SNMPMessage.decodeUnsignedInteger(Array(bytes[bootsTLV.range])))
            let timeTLV = try readTLV(); cursor = timeTLV.range.endIndex
            engine.time = Int(SNMPMessage.decodeUnsignedInteger(Array(bytes[timeTLV.range])))
            cursor = saved
        }

        // msgData: plaintext scoped PDU (authNoPriv / noAuthNoPriv).
        let scoped = try readTLV()
        guard scoped.tag == 0x30 else {
            // Encrypted payload — privacy is unsupported.
            return Decoded(engine: engine, varbind: nil, reportOID: nil)
        }
        try skip()                                  // contextEngineID
        try skip()                                  // contextName

        let pdu = try readTLV()                      // Response (0xA2) or Report (0xA8)
        try skip()                                  // request-id
        try skip()                                  // error-status
        try skip()                                  // error-index
        let list = try readTLV()
        guard list.tag == 0x30 else { return Decoded(engine: engine, varbind: nil, reportOID: nil) }

        guard cursor < list.range.endIndex else {
            return Decoded(engine: engine, varbind: nil, reportOID: nil)
        }
        let varbind = try readTLV()
        guard varbind.tag == 0x30 else { return Decoded(engine: engine, varbind: nil, reportOID: nil) }
        let oidTLV = try readTLV(); cursor = oidTLV.range.endIndex
        guard oidTLV.tag == 0x06 else { return Decoded(engine: engine, varbind: nil, reportOID: nil) }
        let oid = SNMPMessage.decodeOID(Array(bytes[oidTLV.range]))
        let valueTLV = try readTLV(); cursor = valueTLV.range.endIndex

        if pdu.tag == 0xA8 {
            // Report PDU — engine returns a counter OID, not real data.
            return Decoded(engine: engine, varbind: nil, reportOID: oid)
        }
        let rendered = renderValue(tag: valueTLV.tag, bytes: Array(bytes[valueTLV.range]))
        return Decoded(
            engine: engine,
            varbind: SNMPVarbind(oid: oid, typeName: rendered.0, value: rendered.1),
            reportOID: nil
        )
    }

    private static func renderValue(tag: UInt8, bytes: [UInt8]) -> (String, String) {
        switch tag {
        case 0x04:
            let printable = bytes.allSatisfy { $0 == 0x09 || $0 == 0x0A || $0 == 0x0D || (0x20...0x7E).contains($0) }
            return ("OCTET STRING", printable
                ? String(decoding: bytes, as: UTF8.self)
                : bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
        case 0x02: return ("INTEGER", String(SNMPMessage.decodeSignedInteger(bytes)))
        case 0x06: return ("OID", SNMPMessage.decodeOID(bytes))
        case 0x40: return ("IpAddress", bytes.map(String.init).joined(separator: "."))
        case 0x41: return ("Counter32", String(SNMPMessage.decodeUnsignedInteger(bytes)))
        case 0x42: return ("Gauge32", String(SNMPMessage.decodeUnsignedInteger(bytes)))
        case 0x43:
            let ticks = SNMPMessage.decodeUnsignedInteger(bytes)
            return ("TimeTicks", "\(ticks) (\(ticks / 100)s)")
        case 0x46: return ("Counter64", String(SNMPMessage.decodeUnsignedInteger(bytes)))
        case 0x05: return ("NULL", "")
        default: return ("0x\(String(format: "%02X", tag))", bytes.map { String(format: "%02X", $0) }.joined())
        }
    }
}

// MARK: - v3 query service

/// Two-step USM query: discover the authoritative engine, then issue an
/// authenticated GET. Transport is the shared `UDPExchange`.
struct SNMPv3Service: Sendable {
    func get(
        host: String, port: UInt16, user: String,
        password: String, auth: SNMPv3Auth, oid: String
    ) async throws -> SNMPVarbind {
        // 1. Engine discovery.
        let discovery = try SNMPv3Message.encodeDiscovery(msgID: 1)
        let discoveryResponse = await UDPExchange.request(host: host, port: port, payload: discovery, timeout: 5)
        guard case .success(let discoveryData) = discoveryResponse else {
            if case .failure(let error) = discoveryResponse { throw error }
            throw SNMPError.malformedResponse
        }
        let engine = try SNMPv3Message.decode(discoveryData).engine
        guard !engine.id.isEmpty else { throw SNMPError.malformedResponse }

        // 2. Authenticated GET against the discovered engine.
        let key = SNMPv3USM.localizedKey(password: password, engineID: engine.id, auth: auth)
        let request = try SNMPv3Message.encodeAuthGet(
            msgID: 2, oid: oid, user: user, engine: engine, authKey: key, auth: auth
        )
        let response = await UDPExchange.request(host: host, port: port, payload: request, timeout: 5)
        guard case .success(let data) = response else {
            if case .failure(let error) = response { throw error }
            throw SNMPError.malformedResponse
        }
        let decoded = try SNMPv3Message.decode(data)
        if let varbind = decoded.varbind { return varbind }
        if decoded.reportOID != nil { throw SNMPv3Error.authFailed }
        throw SNMPError.noVarbind
    }
}

enum SNMPv3Error: LocalizedError {
    case authFailed
    var errorDescription: String? {
        String(localized: "error.snmpv3.auth", bundle: .module)
    }
}
