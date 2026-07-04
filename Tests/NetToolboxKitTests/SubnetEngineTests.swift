// XCTest mirror of the on-device `EngineTestSuite`.
//
// Swift Playgrounds on iPad cannot run XCTest, so the same vectors ship
// twice:
//   * Sources/NetToolboxKit/Features/SelfTest/EngineTestSuite.swift —
//     run inside the app (Diagnostics → Engine Self-Tests) on iPad.
//   * This target — run with `swift test` / Xcode when the repo is
//     opened as a package on macOS.

import XCTest
@testable import NetToolboxKit

final class SubnetEngineTests: XCTestCase {

    // MARK: IPv4

    func testStandardSlash24() throws {
        let r = try SubnetEngine.calculateIPv4(address: "192.168.1.130", mask: "24")
        XCTAssertEqual(r.networkAddress, "192.168.1.0")
        XCTAssertEqual(r.broadcastAddress, "192.168.1.255")
        XCTAssertEqual(r.firstUsableHost, "192.168.1.1")
        XCTAssertEqual(r.lastUsableHost, "192.168.1.254")
        XCTAssertEqual(r.usableHostCount, 254)
        XCTAssertEqual(r.subnetMask, "255.255.255.0")
        XCTAssertEqual(r.wildcardMask, "0.0.0.255")
        XCTAssertEqual(r.ipClass, .c)
        XCTAssertTrue(r.isPrivate)
    }

    func testSlash30PointToPoint() throws {
        let r = try SubnetEngine.calculateIPv4(address: "10.0.0.5", mask: "/30")
        XCTAssertEqual(r.networkAddress, "10.0.0.4")
        XCTAssertEqual(r.broadcastAddress, "10.0.0.7")
        XCTAssertEqual(r.firstUsableHost, "10.0.0.5")
        XCTAssertEqual(r.lastUsableHost, "10.0.0.6")
        XCTAssertEqual(r.usableHostCount, 2)
    }

    func testSlash31RFC3021() throws {
        let r = try SubnetEngine.calculateIPv4(address: "172.16.0.0", mask: "31")
        XCTAssertEqual(r.usableHostCount, 2)
        XCTAssertEqual(r.firstUsableHost, "172.16.0.0")
        XCTAssertEqual(r.lastUsableHost, "172.16.0.1")
        XCTAssertTrue(r.isPrivate)
    }

    func testSlash32HostRoute() throws {
        let r = try SubnetEngine.calculateIPv4(address: "8.8.8.8", mask: "32")
        XCTAssertEqual(r.usableHostCount, 1)
        XCTAssertEqual(r.networkAddress, "8.8.8.8")
        XCTAssertEqual(r.scope, .publicRange)
    }

    func testDottedMaskInput() throws {
        let r = try SubnetEngine.calculateIPv4(address: "192.168.10.77", mask: "255.255.255.192")
        XCTAssertEqual(r.prefix, 26)
        XCTAssertEqual(r.networkAddress, "192.168.10.64")
        XCTAssertEqual(r.usableHostCount, 62)
    }

    func testInlineCIDRWinsOverMaskField() throws {
        let r = try SubnetEngine.calculateIPv4(address: "10.1.2.3/8", mask: "24")
        XCTAssertEqual(r.prefix, 8)
        XCTAssertEqual(r.networkAddress, "10.0.0.0")
    }

    func testBinaryRendering() throws {
        let r = try SubnetEngine.calculateIPv4(address: "192.168.1.10", mask: "24")
        XCTAssertEqual(r.addressBinary, "11000000.10101000.00000001.00001010")
        XCTAssertEqual(r.maskBinary, "11111111.11111111.11111111.00000000")
    }

    func testSpecialScopes() {
        XCTAssertEqual(SubnetEngine.scope(of: 0x7F00_0001), .loopback)
        XCTAssertEqual(SubnetEngine.scope(of: 0xA9FE_0101), .linkLocal)
        XCTAssertEqual(SubnetEngine.scope(of: 0x6440_0001), .cgNAT)
        XCTAssertEqual(SubnetEngine.scope(of: 0xE000_0001), .multicast)
    }

    func testInvalidIPv4Rejected() {
        XCTAssertThrowsError(try SubnetEngine.parseIPv4("192.168.1.256"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv4("10.0.0"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv4("abc.def.ghi.jkl"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv4(""))
    }

    func testInvalidPrefixRejected() {
        XCTAssertThrowsError(try SubnetEngine.parseIPv4Prefix("33"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv4Prefix("-1"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv4Prefix("/"))
    }

    func testNonContiguousMaskRejected() {
        XCTAssertThrowsError(try SubnetEngine.parseIPv4Prefix("255.0.255.0")) { error in
            XCTAssertEqual(error as? SubnetEngineError, .nonContiguousMask)
        }
    }

    // MARK: IPv6

    func testIPv6ExpandAndCompress() throws {
        let groups = try SubnetEngine.parseIPv6("2001:db8::1")
        XCTAssertEqual(SubnetEngine.expanded(ipv6: groups), "2001:0db8:0000:0000:0000:0000:0000:0001")
        XCTAssertEqual(SubnetEngine.compressed(ipv6: groups), "2001:db8::1")
    }

    func testIPv6NetworkPrefix() throws {
        let r = try SubnetEngine.calculateIPv6(
            address: "2001:db8:aaaa:bbbb:cccc:dddd:eeee:ffff", prefix: "64"
        )
        XCTAssertEqual(r.networkPrefix, "2001:db8:aaaa:bbbb::")
        XCTAssertEqual(r.hostBits, 64)
    }

    func testIPv6AddressTypes() throws {
        XCTAssertEqual(try SubnetEngine.calculateIPv6(address: "fe80::1", prefix: "64").addressType, .linkLocal)
        XCTAssertEqual(try SubnetEngine.calculateIPv6(address: "fd12:3456::1", prefix: "48").addressType, .uniqueLocal)
        XCTAssertEqual(try SubnetEngine.calculateIPv6(address: "ff02::fb", prefix: "128").addressType, .multicast)
        XCTAssertEqual(try SubnetEngine.calculateIPv6(address: "::1", prefix: "128").addressType, .loopback)
    }

    func testIPv6InvalidRejected() {
        XCTAssertThrowsError(try SubnetEngine.parseIPv6("2001::db8::1"))
        XCTAssertThrowsError(try SubnetEngine.parseIPv6("1:2:3:4:5:6:7:8:9"))
        XCTAssertThrowsError(try SubnetEngine.calculateIPv6(address: "2001:db8::1", prefix: "129"))
    }

    // MARK: MAC / OUI

    func testMACNormalizationAllFormats() throws {
        let colon = try MACAddress(parsing: "f0:18:9d:aa:bb:cc")
        XCTAssertEqual(colon.normalized, "F0:18:9D:AA:BB:CC")
        XCTAssertEqual(try MACAddress(parsing: "F0-18-9D-AA-BB-CC").normalized, colon.normalized)
        XCTAssertEqual(try MACAddress(parsing: "f018.9daa.bbcc").normalized, colon.normalized)
        XCTAssertEqual(try MACAddress(parsing: "F0189DAABBCC").normalized, colon.normalized)
        XCTAssertEqual(colon.ouiKey, "F0189D")
        XCTAssertEqual(colon.ciscoNotation, "f018.9daa.bbcc")
    }

    func testMACFlagBits() throws {
        XCTAssertTrue(try MACAddress(parsing: "01:00:5E:00:00:01").isMulticast)
        XCTAssertTrue(try MACAddress(parsing: "DA:A1:19:12:34:56").isLocallyAdministered)
        let universal = try MACAddress(parsing: "F0:18:9D:00:00:01")
        XCTAssertFalse(universal.isLocallyAdministered)
        XCTAssertFalse(universal.isMulticast)
    }

    func testMACInvalidRejected() {
        XCTAssertThrowsError(try MACAddress(parsing: "F0:18:9D"))
        XCTAssertThrowsError(try MACAddress(parsing: "GG:18:9D:AA:BB:CC"))
    }

    func testOUILookup() {
        let database = BundledOUIDatabase(vendors: ["F0189D": "Test Vendor"])
        XCTAssertEqual(database.vendor(forOUI: "F0189D"), "Test Vendor")
        XCTAssertEqual(database.vendor(forOUI: "f0189d"), "Test Vendor")
        XCTAssertNil(database.vendor(forOUI: "000000"))
    }

    // MARK: Phase 2 & 3 codecs

    func testWakeOnLANMagicPacket() throws {
        let mac = try MACAddress(parsing: "F0:18:9D:AA:BB:CC")
        let packet = [UInt8](WakeOnLAN.magicPacket(for: mac))
        XCTAssertEqual(packet.count, 102)
        XCTAssertEqual(Array(packet.prefix(6)), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(Array(packet[6..<12]), [0xF0, 0x18, 0x9D, 0xAA, 0xBB, 0xCC])
    }

    func testMikroTikLengthCoding() {
        XCTAssertEqual(MikroTikProtocol.encodeLength(0x7F), [0x7F])
        XCTAssertEqual(MikroTikProtocol.encodeLength(0x80), [0x80, 0x80])
        let decoded = MikroTikProtocol.decodeLength([0x80, 0x80], at: 0)
        XCTAssertEqual(decoded?.length, 0x80)
        XCTAssertEqual(decoded?.consumed, 2)
    }

    func testMikroTikSentenceRoundTrip() {
        let encoded = MikroTikProtocol.encodeSentence(["/login", "=name=admin"])
        let sentences = MikroTikProtocol.decodeSentences(encoded)
        XCTAssertEqual(sentences, [["/login", "=name=admin"]])
    }

    func testDNSNameEncoding() {
        XCTAssertEqual([UInt8](DNSMessage.encodeName("a.bc")), [1, 0x61, 2, 0x62, 0x63, 0])
    }

    func testDNSCompressionPointer() throws {
        let bytes: [UInt8] = [0x01, 0x61, 0x00, 0xC0, 0x01]
        let (name, next) = try DNSMessage.readName(bytes, at: 3)
        XCTAssertEqual(name, "a")
        XCTAssertEqual(next, 5)
    }

    func testDNSARecordDecode() throws {
        let response: [UInt8] = [
            0x12, 0x34, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x01, 0x61, 0x00, 0x00, 0x01, 0x00, 0x01,
            0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x3C,
            0x00, 0x04, 0x01, 0x02, 0x03, 0x04,
        ]
        let records = try DNSMessage.decodeAnswers(Data(response))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.type, .a)
        XCTAssertEqual(records.first?.value, "1.2.3.4")
        XCTAssertEqual(records.first?.ttl, 60)
    }

    func testSNMPBERPrimitives() throws {
        XCTAssertEqual(SNMPMessage.encodeLength(200), [0x81, 0xC8])
        XCTAssertEqual(SNMPMessage.encodeBase128(300), [0x82, 0x2C])
        XCTAssertEqual(try SNMPMessage.encodeOID("1.3.6.1"), [0x06, 0x03, 0x2B, 0x06, 0x01])
        XCTAssertEqual(SNMPMessage.decodeOID([0x2B, 0x06, 0x01]), "1.3.6.1")
    }

    func testSNMPResponseDecode() throws {
        let oidBytes = try SNMPMessage.encodeOID("1.3.6.1.2.1.1.5.0")
        let varbind = SNMPMessage.encodeTLV(tag: 0x30, content: oidBytes + SNMPMessage.encodeOctetString("rtr"))
        let varbindList = SNMPMessage.encodeTLV(tag: 0x30, content: varbind)
        let pduBody = SNMPMessage.encodeInteger(1) + SNMPMessage.encodeInteger(0)
            + SNMPMessage.encodeInteger(0) + varbindList
        let pdu = SNMPMessage.encodeTLV(tag: 0xA2, content: pduBody)
        let message = SNMPMessage.encodeInteger(1) + SNMPMessage.encodeOctetString("public") + pdu
        let full = SNMPMessage.encodeTLV(tag: 0x30, content: message)
        let result = try SNMPMessage.decodeResponse(Data(full))
        XCTAssertEqual(result.oid, "1.3.6.1.2.1.1.5.0")
        XCTAssertEqual(result.typeName, "OCTET STRING")
        XCTAssertEqual(result.value, "rtr")
    }

    func testTelnetNegotiation() {
        let doEcho = TelnetProtocol.process([TelnetProtocol.iac, TelnetProtocol.doo, 1, 0x68, 0x69])
        XCTAssertEqual(doEcho.text, "hi")
        XCTAssertEqual(doEcho.reply, [255, 252, 1])
        let willSup = TelnetProtocol.process([TelnetProtocol.iac, TelnetProtocol.will, 3])
        XCTAssertEqual(willSup.reply, [255, 254, 3])
    }

    func testX509TimeParsing() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let utc = X509.parseTime(tag: X509.utcTimeTag, bytes: Array("230615120000Z".utf8))
        XCTAssertEqual(utc.map(formatter.string(from:)), "2023-06-15")

        let generalized = X509.parseTime(tag: X509.generalizedTimeTag, bytes: Array("20230615120000Z".utf8))
        XCTAssertEqual(generalized.map(formatter.string(from:)), "2023-06-15")
    }

    func testTextConversions() throws {
        XCTAssertEqual(try TextConverter.apply(.base64Encode, to: "hi"), "aGk=")
        XCTAssertEqual(try TextConverter.apply(.base64Decode, to: "aGk="), "hi")
        XCTAssertEqual(try TextConverter.apply(.hexEncode, to: "hi"), "6869")
        XCTAssertEqual(try TextConverter.apply(.hexDecode, to: "6869"), "hi")
        XCTAssertThrowsError(try TextConverter.apply(.hexDecode, to: "xyz"))
    }

    func testICMPEchoRequest() {
        XCTAssertEqual(ICMP.checksum([0x08, 0, 0, 0, 0, 1, 0, 1]), 0xF7FD)
        let packet = ICMP.echoRequest(identifier: 1, sequence: 1)
        XCTAssertEqual(Array(packet.prefix(4)), [0x08, 0x00, 0xF7, 0xFD])
        XCTAssertEqual(Array(packet[4..<8]), [0x00, 0x01, 0x00, 0x01])
    }

    func testNTPRequestAndParse() {
        let request = [UInt8](NTP.request())
        XCTAssertEqual(request.count, 48)
        XCTAssertEqual(request.first, 0x1B)

        let unix: UInt32 = 1_000_000_000
        let ntpSeconds = unix + NTP.ntpToUnixOffset
        var response = [UInt8](repeating: 0, count: 48)
        response[40] = UInt8((ntpSeconds >> 24) & 0xFF)
        response[41] = UInt8((ntpSeconds >> 16) & 0xFF)
        response[42] = UInt8((ntpSeconds >> 8) & 0xFF)
        response[43] = UInt8(ntpSeconds & 0xFF)
        let parsed = NTP.parse(Data(response))
        XCTAssertEqual(parsed.map { Int($0.timeIntervalSince1970) }, 1_000_000_000)
    }

    func testWiFiQRPayload() {
        XCTAssertEqual(
            WiFiQR.payload(ssid: "MyNet", security: .wpa, password: "p;w", hidden: false),
            "WIFI:T:WPA;S:MyNet;P:p\\;w;H:false;;"
        )
        XCTAssertEqual(
            WiFiQR.payload(ssid: "Open", security: .none, password: "", hidden: false),
            "WIFI:T:nopass;S:Open;H:false;;"
        )
    }

    func testBaseConversion() throws {
        XCTAssertEqual(try NumberConverter.parse("0xFF"), 255)
        XCTAssertEqual(try NumberConverter.parse("0b1010"), 10)
        XCTAssertEqual(try NumberConverter.parse("255"), 255)
        XCTAssertEqual(NumberConverter.format(255).hex, "FF")
        XCTAssertEqual(NumberConverter.format(10).binary, "1010")
        XCTAssertThrowsError(try NumberConverter.parse("nope"))
    }

    func testVLSMAllocation() throws {
        let allocations = try VLSMEngine.allocate(
            baseCIDR: "192.168.1.0/24",
            requests: [
                VLSMRequest(name: "A", hosts: 50),
                VLSMRequest(name: "B", hosts: 20),
                VLSMRequest(name: "C", hosts: 10),
            ]
        )
        XCTAssertEqual(allocations.map(\.cidr), ["192.168.1.0/26", "192.168.1.64/27", "192.168.1.96/28"])
        XCTAssertEqual(VLSMEngine.prefixFor(hosts: 50), 26)
        XCTAssertEqual(VLSMEngine.prefixFor(hosts: 100), 25)
    }

    func testPasswordStrength() {
        let options = PasswordGenerator.Options()
        XCTAssertEqual(PasswordGenerator.pool(for: options).count, 86)
        XCTAssertEqual(PasswordGenerator.generate(options).count, 16)
        XCTAssertGreaterThan(PasswordGenerator.entropyBits(for: options), 100)
        XCTAssertEqual(PasswordGenerator.strength(bits: 30), .weak)
    }

    func testInputClassification() {
        XCTAssertEqual(InputClassifier.classify("192.168.1.1"), .ipv4)
        XCTAssertEqual(InputClassifier.classify("aa:bb:cc:dd:ee:ff"), .mac)
        XCTAssertEqual(InputClassifier.classify("https://apple.com"), .url)
        XCTAssertEqual(InputClassifier.classify("apple.com"), .domain)
        XCTAssertEqual(InputClassifier.classify("hello"), .none)
    }

    func testIPRangeEnumeration() throws {
        XCTAssertEqual(try IPRangeScanner.hosts(cidr: "192.168.1.0/30"), ["192.168.1.1", "192.168.1.2"])
        let slash24 = try IPRangeScanner.hosts(cidr: "10.0.0.0/24")
        XCTAssertEqual(slash24.count, 254)
        XCTAssertEqual(slash24.first, "10.0.0.1")
        XCTAssertEqual(slash24.last, "10.0.0.254")
        XCTAssertThrowsError(try IPRangeScanner.hosts(cidr: "10.0.0.0/16"))
    }

    func testEmailValidation() {
        XCTAssertTrue(EmailValidator.isValidSyntax("a@b.com"))
        XCTAssertFalse(EmailValidator.isValidSyntax("a@b"))
        XCTAssertFalse(EmailValidator.isValidSyntax("a b@c.com"))
        XCTAssertFalse(EmailValidator.isValidSyntax("@c.com"))
        XCTAssertEqual(EmailValidator.domain(of: "user@example.com"), "example.com")
    }

    func testRBLQuery() {
        XCTAssertEqual(RBL.query(ip: "1.2.3.4", zone: "zen.spamhaus.org"), "4.3.2.1.zen.spamhaus.org")
        XCTAssertNil(RBL.query(ip: "bad", zone: "z"))
    }

    func testPortListParsing() {
        XCTAssertEqual(PortList.parse("22,80,443"), [22, 80, 443])
        XCTAssertEqual(PortList.parse("1-3"), [1, 2, 3])
        XCTAssertEqual(PortList.parse("80, 100-102"), [80, 100, 101, 102])
        XCTAssertNil(PortList.parse("70000"))
        XCTAssertNil(PortList.parse(""))
    }

    func testFTPPasvParsing() {
        let endpoint = FTP.parsePASV("227 Entering Passive Mode (192,168,1,10,195,80).")
        XCTAssertEqual(endpoint?.host, "192.168.1.10")
        XCTAssertEqual(endpoint?.port, 195 * 256 + 80)
        XCTAssertNil(FTP.parsePASV("500 error"))
    }

    func testSNMPGetNextEncoding() throws {
        let get = [UInt8](try SNMPMessage.encodeGet(oid: "1.3.6.1", community: "public", requestID: 1))
        let next = [UInt8](try SNMPMessage.encodeGetNext(oid: "1.3.6.1", community: "public", requestID: 1))
        XCTAssertEqual(get.count, next.count)
        XCTAssertTrue(get.contains(0xA0))
        XCTAssertTrue(next.contains(0xA1))
    }
}
