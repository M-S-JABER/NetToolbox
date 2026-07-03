// XCTest mirror of the on-device `EngineTestSuite`.
//
// Swift Playgrounds on iPad cannot run XCTest, so this project ships the
// same vectors twice:
//   * Features/SelfTest/EngineTestSuite.swift — run inside the app
//     (Diagnostics → Engine Self-Tests) directly on iPad.
//   * This file — for Xcode users: add a unit-test target to the package
//     (or open the folder as a package) and include this file in it.
//
// This file is excluded from the app target in Package.swift.

import XCTest

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
}
