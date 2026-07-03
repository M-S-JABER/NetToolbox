import Foundation

/// A lightweight assertion suite that runs the engine test vectors
/// on-device. It mirrors `Tests/SubnetEngineTests.swift` so the developer
/// can verify the engines directly from Swift Playgrounds on iPad,
/// where XCTest is not available.
struct EngineTestSuite: Sendable {
    struct Case: Identifiable, Sendable {
        let name: String
        let run: @Sendable () -> String?   // nil = pass, message = failure

        var id: String { name }
    }

    struct Outcome: Identifiable, Equatable, Sendable {
        let name: String
        let failureMessage: String?

        var id: String { name }
        var passed: Bool { failureMessage == nil }
    }

    static func runAll() -> [Outcome] {
        allCases.map { Outcome(name: $0.name, failureMessage: $0.run()) }
    }

    // MARK: - Assertion helpers

    private static func expect<T: Equatable>(
        _ actual: T, equals expected: T, _ label: String
    ) -> String? {
        actual == expected ? nil : "\(label): expected \(expected), got \(actual)"
    }

    private static func expectThrows<E: Error & Equatable, T>(
        _ expected: E, _ label: String, _ body: () throws -> T
    ) -> String? {
        do {
            _ = try body()
            return "\(label): expected error \(expected), but no error was thrown"
        } catch let error as E where error == expected {
            return nil
        } catch {
            return "\(label): expected \(expected), got \(error)"
        }
    }

    // MARK: - Test vectors

    static let allCases: [Case] = [
        Case(name: "IPv4 /24 standard network") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "192.168.1.130", mask: "24")
                return expect(r.networkAddress, equals: "192.168.1.0", "network")
                    ?? expect(r.broadcastAddress, equals: "192.168.1.255", "broadcast")
                    ?? expect(r.firstUsableHost, equals: "192.168.1.1", "first host")
                    ?? expect(r.lastUsableHost, equals: "192.168.1.254", "last host")
                    ?? expect(r.usableHostCount, equals: 254, "usable hosts")
                    ?? expect(r.subnetMask, equals: "255.255.255.0", "mask")
                    ?? expect(r.wildcardMask, equals: "0.0.0.255", "wildcard")
                    ?? expect(r.ipClass, equals: .c, "class")
                    ?? expect(r.isPrivate, equals: true, "private")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 /30 point-to-point") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "10.0.0.5", mask: "/30")
                return expect(r.networkAddress, equals: "10.0.0.4", "network")
                    ?? expect(r.broadcastAddress, equals: "10.0.0.7", "broadcast")
                    ?? expect(r.firstUsableHost, equals: "10.0.0.5", "first host")
                    ?? expect(r.lastUsableHost, equals: "10.0.0.6", "last host")
                    ?? expect(r.usableHostCount, equals: 2, "usable hosts")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 /31 RFC 3021") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "172.16.0.0", mask: "31")
                return expect(r.usableHostCount, equals: 2, "usable hosts")
                    ?? expect(r.firstUsableHost, equals: "172.16.0.0", "first host")
                    ?? expect(r.lastUsableHost, equals: "172.16.0.1", "last host")
                    ?? expect(r.isPrivate, equals: true, "private 172.16/12")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 /32 host route") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "8.8.8.8", mask: "32")
                return expect(r.usableHostCount, equals: 1, "usable hosts")
                    ?? expect(r.networkAddress, equals: "8.8.8.8", "network")
                    ?? expect(r.scope, equals: .publicRange, "public scope")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 dotted mask input") {
            do {
                let r = try SubnetEngine.calculateIPv4(
                    address: "192.168.10.77", mask: "255.255.255.192"
                )
                return expect(r.prefix, equals: 26, "prefix from dotted mask")
                    ?? expect(r.networkAddress, equals: "192.168.10.64", "network")
                    ?? expect(r.usableHostCount, equals: 62, "usable hosts")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 inline CIDR in address") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "10.1.2.3/8", mask: "24")
                return expect(r.prefix, equals: 8, "inline prefix wins")
                    ?? expect(r.networkAddress, equals: "10.0.0.0", "network")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 binary rendering") {
            do {
                let r = try SubnetEngine.calculateIPv4(address: "192.168.1.10", mask: "24")
                return expect(
                    r.addressBinary,
                    equals: "11000000.10101000.00000001.00001010",
                    "address binary"
                ) ?? expect(
                    r.maskBinary,
                    equals: "11111111.11111111.11111111.00000000",
                    "mask binary"
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv4 special scopes") {
            expect(SubnetEngine.scope(of: 0x7F00_0001), equals: .loopback, "127.0.0.1")
                ?? expect(SubnetEngine.scope(of: 0xA9FE_0101), equals: .linkLocal, "169.254.1.1")
                ?? expect(SubnetEngine.scope(of: 0x6440_0001), equals: .cgNAT, "100.64.0.1")
                ?? expect(SubnetEngine.scope(of: 0xE000_0001), equals: .multicast, "224.0.0.1")
        },
        Case(name: "IPv4 invalid address rejected") {
            expectThrows(SubnetEngineError.invalidIPv4Address, "256 octet") {
                try SubnetEngine.parseIPv4("192.168.1.256")
            }
            ?? expectThrows(SubnetEngineError.invalidIPv4Address, "3 octets") {
                try SubnetEngine.parseIPv4("10.0.0")
            }
            ?? expectThrows(SubnetEngineError.invalidIPv4Address, "text") {
                try SubnetEngine.parseIPv4("abc.def.ghi.jkl")
            }
        },
        Case(name: "IPv4 invalid prefix rejected") {
            expectThrows(SubnetEngineError.invalidPrefix, "/33") {
                try SubnetEngine.parseIPv4Prefix("33")
            }
            ?? expectThrows(SubnetEngineError.invalidPrefix, "negative") {
                try SubnetEngine.parseIPv4Prefix("-1")
            }
            ?? expectThrows(SubnetEngineError.invalidPrefix, "empty") {
                try SubnetEngine.parseIPv4Prefix("/")
            }
        },
        Case(name: "IPv4 non-contiguous mask rejected") {
            expectThrows(SubnetEngineError.nonContiguousMask, "255.0.255.0") {
                try SubnetEngine.parseIPv4Prefix("255.0.255.0")
            }
        },
        Case(name: "IPv6 parse + expand + compress") {
            do {
                let groups = try SubnetEngine.parseIPv6("2001:db8::1")
                return expect(
                    SubnetEngine.expanded(ipv6: groups),
                    equals: "2001:0db8:0000:0000:0000:0000:0000:0001",
                    "expanded"
                ) ?? expect(
                    SubnetEngine.compressed(ipv6: groups),
                    equals: "2001:db8::1",
                    "compressed round-trip"
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv6 /64 network prefix") {
            do {
                let r = try SubnetEngine.calculateIPv6(
                    address: "2001:db8:aaaa:bbbb:cccc:dddd:eeee:ffff", prefix: "64"
                )
                return expect(r.networkPrefix, equals: "2001:db8:aaaa:bbbb::", "network prefix")
                    ?? expect(r.hostBits, equals: 64, "host bits")
                    ?? expect(r.addressType, equals: .documentation, "2001:db8 documentation")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv6 address types") {
            do {
                let linkLocal = try SubnetEngine.calculateIPv6(address: "fe80::1", prefix: "64")
                let uniqueLocal = try SubnetEngine.calculateIPv6(address: "fd12:3456::1", prefix: "48")
                let multicast = try SubnetEngine.calculateIPv6(address: "ff02::fb", prefix: "128")
                let loopback = try SubnetEngine.calculateIPv6(address: "::1", prefix: "128")
                return expect(linkLocal.addressType, equals: .linkLocal, "fe80::/10")
                    ?? expect(uniqueLocal.addressType, equals: .uniqueLocal, "fc00::/7")
                    ?? expect(multicast.addressType, equals: .multicast, "ff00::/8")
                    ?? expect(loopback.addressType, equals: .loopback, "::1")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "IPv6 invalid input rejected") {
            expectThrows(SubnetEngineError.invalidIPv6Address, "double ::") {
                try SubnetEngine.parseIPv6("2001::db8::1")
            }
            ?? expectThrows(SubnetEngineError.invalidIPv6Address, "too many groups") {
                try SubnetEngine.parseIPv6("1:2:3:4:5:6:7:8:9")
            }
            ?? expectThrows(SubnetEngineError.invalidPrefix, "/129") {
                try SubnetEngine.calculateIPv6(address: "2001:db8::1", prefix: "129")
            }
        },
        Case(name: "MAC normalization from all formats") {
            do {
                let colon = try MACAddress(parsing: "f0:18:9d:aa:bb:cc")
                let dash = try MACAddress(parsing: "F0-18-9D-AA-BB-CC")
                let cisco = try MACAddress(parsing: "f018.9daa.bbcc")
                let raw = try MACAddress(parsing: "F0189DAABBCC")
                return expect(colon.normalized, equals: "F0:18:9D:AA:BB:CC", "colon")
                    ?? expect(dash.normalized, equals: colon.normalized, "dash == colon")
                    ?? expect(cisco.normalized, equals: colon.normalized, "cisco == colon")
                    ?? expect(raw.normalized, equals: colon.normalized, "raw == colon")
                    ?? expect(colon.ouiKey, equals: "F0189D", "OUI key")
                    ?? expect(colon.ciscoNotation, equals: "f018.9daa.bbcc", "cisco notation")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "MAC flag bits") {
            do {
                let multicast = try MACAddress(parsing: "01:00:5E:00:00:01")
                let randomized = try MACAddress(parsing: "DA:A1:19:12:34:56")
                let universal = try MACAddress(parsing: "F0:18:9D:00:00:01")
                return expect(multicast.isMulticast, equals: true, "01:...:01 multicast")
                    ?? expect(randomized.isLocallyAdministered, equals: true, "DA locally administered")
                    ?? expect(universal.isLocallyAdministered, equals: false, "F0 universal")
                    ?? expect(universal.isMulticast, equals: false, "F0 unicast")
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "MAC invalid input rejected") {
            expectThrows(MACAddressError.invalidFormat, "too short") {
                try MACAddress(parsing: "F0:18:9D")
            }
            ?? expectThrows(MACAddressError.invalidFormat, "non-hex") {
                try MACAddress(parsing: "GG:18:9D:AA:BB:CC")
            }
        },
        Case(name: "OUI database lookup") {
            let database = BundledOUIDatabase(vendors: ["F0189D": "Test Vendor"])
            return expect(database.vendor(forOUI: "F0189D") ?? "", equals: "Test Vendor", "hit")
                ?? expect(database.vendor(forOUI: "f0189d") ?? "", equals: "Test Vendor", "case-insensitive")
                ?? expect(database.vendor(forOUI: "000000") == nil, equals: true, "miss")
        },
        Case(name: "Bundled oui.json loads") {
            let database = BundledOUIDatabase()
            return database.count > 100
                ? nil
                : "bundled database has only \(database.count) entries"
        },
    ]
}
