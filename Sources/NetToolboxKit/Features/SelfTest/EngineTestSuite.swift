import Foundation
import CryptoKit

/// A lightweight assertion suite that runs the engine test vectors
/// on-device. It mirrors `Tests/NetToolboxKitTests/SubnetEngineTests.swift`
/// so the developer can verify the engines directly from Swift Playgrounds
/// on iPad, where XCTest is not available.
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

    /// First failure among the given checks, or nil when all pass.
    /// Deliberately variadic instead of chaining `??` — long chains of
    /// nil-coalescing over generic calls blow up type-checking time on
    /// the Swift Playgrounds (iPad) toolchain.
    private static func firstFailure(_ checks: String?...) -> String? {
        for check in checks {
            if let check { return check }
        }
        return nil
    }

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

    static let allCases: [Case] = ipv4Cases + ipv6Cases + macCases + codecCases + sshCases + curve25519Cases + cryptoCases + featureCases

    /// Parses a lowercase hex string into bytes (test helper).
    private static func hexBytes(_ string: String) -> [UInt8] {
        var result: [UInt8] = []
        var index = string.startIndex
        while index < string.endIndex, let next = string.index(index, offsetBy: 2, limitedBy: string.endIndex) {
            result.append(UInt8(string[index..<next], radix: 16) ?? 0)
            index = next
        }
        return result
    }

    private static let ipv4Cases: [Case] = [
        Case(name: "IPv4 /24 standard network") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "192.168.1.130", mask: "24")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.networkAddress, equals: "192.168.1.0", "network"),
                expect(r.broadcastAddress, equals: "192.168.1.255", "broadcast"),
                expect(r.firstUsableHost, equals: "192.168.1.1", "first host"),
                expect(r.lastUsableHost, equals: "192.168.1.254", "last host"),
                expect(r.usableHostCount, equals: 254, "usable hosts"),
                expect(r.subnetMask, equals: "255.255.255.0", "mask"),
                expect(r.wildcardMask, equals: "0.0.0.255", "wildcard"),
                expect(r.ipClass, equals: .c, "class"),
                expect(r.isPrivate, equals: true, "private")
            )
        },
        Case(name: "IPv4 /30 point-to-point") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "10.0.0.5", mask: "/30")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.networkAddress, equals: "10.0.0.4", "network"),
                expect(r.broadcastAddress, equals: "10.0.0.7", "broadcast"),
                expect(r.firstUsableHost, equals: "10.0.0.5", "first host"),
                expect(r.lastUsableHost, equals: "10.0.0.6", "last host"),
                expect(r.usableHostCount, equals: 2, "usable hosts")
            )
        },
        Case(name: "IPv4 /31 RFC 3021") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "172.16.0.0", mask: "31")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.usableHostCount, equals: 2, "usable hosts"),
                expect(r.firstUsableHost, equals: "172.16.0.0", "first host"),
                expect(r.lastUsableHost, equals: "172.16.0.1", "last host"),
                expect(r.isPrivate, equals: true, "private 172.16/12")
            )
        },
        Case(name: "IPv4 /32 host route") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "8.8.8.8", mask: "32")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.usableHostCount, equals: 1, "usable hosts"),
                expect(r.networkAddress, equals: "8.8.8.8", "network"),
                expect(r.scope, equals: .publicRange, "public scope")
            )
        },
        Case(name: "IPv4 dotted mask input") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "192.168.10.77", mask: "255.255.255.192")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.prefix, equals: 26, "prefix from dotted mask"),
                expect(r.networkAddress, equals: "192.168.10.64", "network"),
                expect(r.usableHostCount, equals: 62, "usable hosts")
            )
        },
        Case(name: "IPv4 inline CIDR in address") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "10.1.2.3/8", mask: "24")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.prefix, equals: 8, "inline prefix wins"),
                expect(r.networkAddress, equals: "10.0.0.0", "network")
            )
        },
        Case(name: "IPv4 binary rendering") {
            let r: IPv4SubnetResult
            do {
                r = try SubnetEngine.calculateIPv4(address: "192.168.1.10", mask: "24")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.addressBinary, equals: "11000000.10101000.00000001.00001010", "address binary"),
                expect(r.maskBinary, equals: "11111111.11111111.11111111.00000000", "mask binary")
            )
        },
        Case(name: "IPv4 special scopes") {
            firstFailure(
                expect(SubnetEngine.scope(of: 0x7F00_0001), equals: .loopback, "127.0.0.1"),
                expect(SubnetEngine.scope(of: 0xA9FE_0101), equals: .linkLocal, "169.254.1.1"),
                expect(SubnetEngine.scope(of: 0x6440_0001), equals: .cgNAT, "100.64.0.1"),
                expect(SubnetEngine.scope(of: 0xE000_0001), equals: .multicast, "224.0.0.1")
            )
        },
        Case(name: "IPv4 invalid address rejected") {
            firstFailure(
                expectThrows(SubnetEngineError.invalidIPv4Address, "256 octet") {
                    try SubnetEngine.parseIPv4("192.168.1.256")
                },
                expectThrows(SubnetEngineError.invalidIPv4Address, "3 octets") {
                    try SubnetEngine.parseIPv4("10.0.0")
                },
                expectThrows(SubnetEngineError.invalidIPv4Address, "text") {
                    try SubnetEngine.parseIPv4("abc.def.ghi.jkl")
                }
            )
        },
        Case(name: "IPv4 invalid prefix rejected") {
            firstFailure(
                expectThrows(SubnetEngineError.invalidPrefix, "/33") {
                    try SubnetEngine.parseIPv4Prefix("33")
                },
                expectThrows(SubnetEngineError.invalidPrefix, "negative") {
                    try SubnetEngine.parseIPv4Prefix("-1")
                },
                expectThrows(SubnetEngineError.invalidPrefix, "empty") {
                    try SubnetEngine.parseIPv4Prefix("/")
                }
            )
        },
        Case(name: "IPv4 non-contiguous mask rejected") {
            expectThrows(SubnetEngineError.nonContiguousMask, "255.0.255.0") {
                try SubnetEngine.parseIPv4Prefix("255.0.255.0")
            }
        },
    ]

    private static let ipv6Cases: [Case] = [
        Case(name: "IPv6 parse + expand + compress") {
            let groups: [UInt16]
            do {
                groups = try SubnetEngine.parseIPv6("2001:db8::1")
            } catch { return "unexpected error: \(error)" }
            let expanded = SubnetEngine.expanded(ipv6: groups)
            let compressed = SubnetEngine.compressed(ipv6: groups)
            return firstFailure(
                expect(expanded, equals: "2001:0db8:0000:0000:0000:0000:0000:0001", "expanded"),
                expect(compressed, equals: "2001:db8::1", "compressed round-trip")
            )
        },
        Case(name: "IPv6 /64 network prefix") {
            let r: IPv6SubnetResult
            do {
                r = try SubnetEngine.calculateIPv6(
                    address: "2001:db8:aaaa:bbbb:cccc:dddd:eeee:ffff", prefix: "64"
                )
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(r.networkPrefix, equals: "2001:db8:aaaa:bbbb::", "network prefix"),
                expect(r.hostBits, equals: 64, "host bits"),
                expect(r.addressType, equals: .documentation, "2001:db8 documentation")
            )
        },
        Case(name: "IPv6 address types") {
            let linkLocal: IPv6SubnetResult
            let uniqueLocal: IPv6SubnetResult
            let multicast: IPv6SubnetResult
            let loopback: IPv6SubnetResult
            do {
                linkLocal = try SubnetEngine.calculateIPv6(address: "fe80::1", prefix: "64")
                uniqueLocal = try SubnetEngine.calculateIPv6(address: "fd12:3456::1", prefix: "48")
                multicast = try SubnetEngine.calculateIPv6(address: "ff02::fb", prefix: "128")
                loopback = try SubnetEngine.calculateIPv6(address: "::1", prefix: "128")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(linkLocal.addressType, equals: .linkLocal, "fe80::/10"),
                expect(uniqueLocal.addressType, equals: .uniqueLocal, "fc00::/7"),
                expect(multicast.addressType, equals: .multicast, "ff00::/8"),
                expect(loopback.addressType, equals: .loopback, "::1")
            )
        },
        Case(name: "IPv6 invalid input rejected") {
            firstFailure(
                expectThrows(SubnetEngineError.invalidIPv6Address, "double ::") {
                    try SubnetEngine.parseIPv6("2001::db8::1")
                },
                expectThrows(SubnetEngineError.invalidIPv6Address, "too many groups") {
                    try SubnetEngine.parseIPv6("1:2:3:4:5:6:7:8:9")
                },
                expectThrows(SubnetEngineError.invalidPrefix, "/129") {
                    try SubnetEngine.calculateIPv6(address: "2001:db8::1", prefix: "129")
                }
            )
        },
    ]

    private static let macCases: [Case] = [
        Case(name: "MAC normalization from all formats") {
            let colon: MACAddress
            let dash: MACAddress
            let cisco: MACAddress
            let raw: MACAddress
            do {
                colon = try MACAddress(parsing: "f0:18:9d:aa:bb:cc")
                dash = try MACAddress(parsing: "F0-18-9D-AA-BB-CC")
                cisco = try MACAddress(parsing: "f018.9daa.bbcc")
                raw = try MACAddress(parsing: "F0189DAABBCC")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(colon.normalized, equals: "F0:18:9D:AA:BB:CC", "colon"),
                expect(dash.normalized, equals: colon.normalized, "dash == colon"),
                expect(cisco.normalized, equals: colon.normalized, "cisco == colon"),
                expect(raw.normalized, equals: colon.normalized, "raw == colon"),
                expect(colon.ouiKey, equals: "F0189D", "OUI key"),
                expect(colon.ciscoNotation, equals: "f018.9daa.bbcc", "cisco notation")
            )
        },
        Case(name: "MAC flag bits") {
            let multicast: MACAddress
            let randomized: MACAddress
            let universal: MACAddress
            do {
                multicast = try MACAddress(parsing: "01:00:5E:00:00:01")
                randomized = try MACAddress(parsing: "DA:A1:19:12:34:56")
                universal = try MACAddress(parsing: "F0:18:9D:00:00:01")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(multicast.isMulticast, equals: true, "01:...:01 multicast"),
                expect(randomized.isLocallyAdministered, equals: true, "DA locally administered"),
                expect(universal.isLocallyAdministered, equals: false, "F0 universal"),
                expect(universal.isMulticast, equals: false, "F0 unicast")
            )
        },
        Case(name: "MAC invalid input rejected") {
            firstFailure(
                expectThrows(MACAddressError.invalidFormat, "too short") {
                    try MACAddress(parsing: "F0:18:9D")
                },
                expectThrows(MACAddressError.invalidFormat, "non-hex") {
                    try MACAddress(parsing: "GG:18:9D:AA:BB:CC")
                }
            )
        },
        Case(name: "OUI database lookup") {
            let database = BundledOUIDatabase(vendors: ["F0189D": "Test Vendor"])
            let hit = database.vendor(forOUI: "F0189D") ?? ""
            let caseInsensitive = database.vendor(forOUI: "f0189d") ?? ""
            let miss = database.vendor(forOUI: "000000")
            return firstFailure(
                expect(hit, equals: "Test Vendor", "hit"),
                expect(caseInsensitive, equals: "Test Vendor", "case-insensitive"),
                expect(miss == nil, equals: true, "miss")
            )
        },
        Case(name: "Bundled oui.json loads") {
            let database = BundledOUIDatabase()
            return database.count > 100
                ? nil
                : "bundled database has only \(database.count) entries"
        },
    ]

    private static let codecCases: [Case] = [
        Case(name: "Wake-on-LAN magic packet") {
            let mac: MACAddress
            do {
                mac = try MACAddress(parsing: "F0:18:9D:AA:BB:CC")
            } catch { return "unexpected error: \(error)" }
            let packet = [UInt8](WakeOnLAN.magicPacket(for: mac))
            let header = Array(packet.prefix(6))
            let firstRepeat = Array(packet[6..<12])
            return firstFailure(
                expect(packet.count, equals: 102, "packet length"),
                expect(header, equals: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF], "sync stream"),
                expect(firstRepeat, equals: [0xF0, 0x18, 0x9D, 0xAA, 0xBB, 0xCC], "first MAC copy")
            )
        },
        Case(name: "MikroTik length encoding") {
            let short = MikroTikProtocol.encodeLength(0x7F)
            let medium = MikroTikProtocol.encodeLength(0x80)
            let decoded = MikroTikProtocol.decodeLength(medium, at: 0)
            return firstFailure(
                expect(short, equals: [0x7F], "short length"),
                expect(medium, equals: [0x80, 0x80], "medium length"),
                expect(decoded?.length, equals: 0x80, "decoded length"),
                expect(decoded?.consumed, equals: 2, "decoded consumed")
            )
        },
        Case(name: "MikroTik sentence round-trip") {
            let encoded = MikroTikProtocol.encodeSentence(["/login", "=name=admin"])
            let sentences = MikroTikProtocol.decodeSentences(encoded)
            return firstFailure(
                expect(sentences.count, equals: 1, "sentence count"),
                expect(sentences.first ?? [], equals: ["/login", "=name=admin"], "words")
            )
        },
        Case(name: "DNS name encoding") {
            let encoded = [UInt8](DNSMessage.encodeName("a.bc"))
            return expect(encoded, equals: [1, 0x61, 2, 0x62, 0x63, 0], "encoded labels")
        },
        Case(name: "DNS name compression pointer") {
            // Label "a" at offset 0 (len 0x01, 'a', root 0x00), then a
            // pointer to it (0xC0 0x00) at offset 3.
            let bytes: [UInt8] = [0x01, 0x61, 0x00, 0xC0, 0x00]
            do {
                let (name, next) = try DNSMessage.readName(bytes, at: 3)
                return firstFailure(
                    expect(name, equals: "a", "pointer name"),
                    expect(next, equals: 5, "offset past pointer")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "DNS A-record response decode") {
            let response: [UInt8] = [
                0x12, 0x34, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
                0x01, 0x61, 0x00, 0x00, 0x01, 0x00, 0x01,          // question "a" A IN
                0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01,               // answer name ptr, A, IN
                0x00, 0x00, 0x00, 0x3C,                           // TTL 60
                0x00, 0x04, 0x01, 0x02, 0x03, 0x04,               // rdlength 4, 1.2.3.4
            ]
            do {
                let records = try DNSMessage.decodeAnswers(Data(response))
                guard let first = records.first else { return "no records decoded" }
                return firstFailure(
                    expect(records.count, equals: 1, "record count"),
                    expect(first.type, equals: .a, "type"),
                    expect(first.value, equals: "1.2.3.4", "value"),
                    expect(first.ttl, equals: 60, "ttl")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "SNMP BER primitives") {
            let oid: [UInt8]
            do {
                oid = try SNMPMessage.encodeOID("1.3.6.1")
            } catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(SNMPMessage.encodeLength(200), equals: [0x81, 0xC8], "long-form length"),
                expect(SNMPMessage.encodeBase128(300), equals: [0x82, 0x2C], "base-128"),
                expect(oid, equals: [0x06, 0x03, 0x2B, 0x06, 0x01], "OID TLV"),
                expect(SNMPMessage.decodeOID([0x2B, 0x06, 0x01]), equals: "1.3.6.1", "OID decode")
            )
        },
        Case(name: "SNMP response decode") {
            let oidBytes: [UInt8]
            do {
                oidBytes = try SNMPMessage.encodeOID("1.3.6.1.2.1.1.5.0")
            } catch { return "unexpected error: \(error)" }
            let varbind = SNMPMessage.encodeTLV(tag: 0x30, content: oidBytes + SNMPMessage.encodeOctetString("rtr"))
            let varbindList = SNMPMessage.encodeTLV(tag: 0x30, content: varbind)
            let pduBody = SNMPMessage.encodeInteger(1) + SNMPMessage.encodeInteger(0)
                + SNMPMessage.encodeInteger(0) + varbindList
            let pdu = SNMPMessage.encodeTLV(tag: 0xA2, content: pduBody)
            let message = SNMPMessage.encodeInteger(1) + SNMPMessage.encodeOctetString("public") + pdu
            let full = SNMPMessage.encodeTLV(tag: 0x30, content: message)
            do {
                let result = try SNMPMessage.decodeResponse(Data(full))
                return firstFailure(
                    expect(result.oid, equals: "1.3.6.1.2.1.1.5.0", "oid"),
                    expect(result.typeName, equals: "OCTET STRING", "type"),
                    expect(result.value, equals: "rtr", "value")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "Telnet option negotiation") {
            let doEcho = TelnetProtocol.process([TelnetProtocol.iac, TelnetProtocol.doo, 1, 0x68, 0x69])
            let willSup = TelnetProtocol.process([TelnetProtocol.iac, TelnetProtocol.will, 3])
            return firstFailure(
                expect(doEcho.text, equals: "hi", "stripped text"),
                expect(doEcho.reply, equals: [255, 252, 1], "WONT reply"),
                expect(willSup.reply, equals: [255, 254, 3], "DONT reply")
            )
        },
        Case(name: "X.509 time parsing") {
            let utc = X509.parseTime(tag: X509.utcTimeTag, bytes: Array("230615120000Z".utf8))
            let generalized = X509.parseTime(tag: X509.generalizedTimeTag, bytes: Array("20230615120000Z".utf8))
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return firstFailure(
                expect(utc.map(formatter.string(from:)) ?? "nil", equals: "2023-06-15", "UTCTime"),
                expect(generalized.map(formatter.string(from:)) ?? "nil", equals: "2023-06-15", "GeneralizedTime")
            )
        },
        Case(name: "Text conversions") {
            do {
                let b64 = try TextConverter.apply(.base64Encode, to: "hi")
                let b64Back = try TextConverter.apply(.base64Decode, to: "aGk=")
                let hex = try TextConverter.apply(.hexEncode, to: "hi")
                let hexBack = try TextConverter.apply(.hexDecode, to: "6869")
                return firstFailure(
                    expect(b64, equals: "aGk=", "base64 encode"),
                    expect(b64Back, equals: "hi", "base64 decode"),
                    expect(hex, equals: "6869", "hex encode"),
                    expect(hexBack, equals: "hi", "hex decode")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "ICMP echo request") {
            let sum = ICMP.checksum([0x08, 0, 0, 0, 0, 1, 0, 1])
            let packet = ICMP.echoRequest(identifier: 1, sequence: 1)
            return firstFailure(
                expect(sum, equals: 0xF7FD, "checksum"),
                expect(Array(packet.prefix(4)), equals: [0x08, 0x00, 0xF7, 0xFD], "header + checksum"),
                expect(Array(packet[4..<8]), equals: [0x00, 0x01, 0x00, 0x01], "id + sequence")
            )
        },
        Case(name: "NTP request and parse") {
            let request = [UInt8](NTP.request())
            let unix: UInt32 = 1_000_000_000
            let ntpSeconds = unix + NTP.ntpToUnixOffset
            var response = [UInt8](repeating: 0, count: 48)
            response[40] = UInt8((ntpSeconds >> 24) & 0xFF)
            response[41] = UInt8((ntpSeconds >> 16) & 0xFF)
            response[42] = UInt8((ntpSeconds >> 8) & 0xFF)
            response[43] = UInt8(ntpSeconds & 0xFF)
            let parsed = NTP.parse(Data(response))
            let parsedUnix = parsed.map { Int($0.timeIntervalSince1970) } ?? -1
            return firstFailure(
                expect(request.count, equals: 48, "request length"),
                expect(request.first ?? 0, equals: 0x1B, "LI/VN/Mode byte"),
                expect(parsedUnix, equals: 1_000_000_000, "parsed transmit time")
            )
        },
        Case(name: "Wi-Fi QR payload") {
            let wpa = WiFiQR.payload(ssid: "MyNet", security: .wpa, password: "p;w", hidden: false)
            let open = WiFiQR.payload(ssid: "Open", security: .none, password: "", hidden: false)
            return firstFailure(
                expect(wpa, equals: "WIFI:T:WPA;S:MyNet;P:p\\;w;H:false;;", "WPA payload with escaping"),
                expect(open, equals: "WIFI:T:nopass;S:Open;H:false;;", "open payload")
            )
        },
        Case(name: "Base conversion") {
            do {
                let hex = try NumberConverter.parse("0xFF")
                let bin = try NumberConverter.parse("0b1010")
                let dec = try NumberConverter.parse("255")
                return firstFailure(
                    expect(hex, equals: 255, "0xFF"),
                    expect(bin, equals: 10, "0b1010"),
                    expect(dec, equals: 255, "decimal"),
                    expect(NumberConverter.format(255).hex, equals: "FF", "format hex"),
                    expect(NumberConverter.format(10).binary, equals: "1010", "format binary")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "VLSM allocation") {
            do {
                let allocations = try VLSMEngine.allocate(
                    baseCIDR: "192.168.1.0/24",
                    requests: [
                        VLSMRequest(name: "A", hosts: 50),
                        VLSMRequest(name: "B", hosts: 20),
                        VLSMRequest(name: "C", hosts: 10),
                    ]
                )
                guard allocations.count == 3 else { return "expected 3 allocations, got \(allocations.count)" }
                return firstFailure(
                    expect(VLSMEngine.prefixFor(hosts: 50), equals: 26, "prefix for 50"),
                    expect(allocations[0].cidr, equals: "192.168.1.0/26", "first block"),
                    expect(allocations[1].cidr, equals: "192.168.1.64/27", "second block"),
                    expect(allocations[2].cidr, equals: "192.168.1.96/28", "third block")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "Password strength maths") {
            let options = PasswordGenerator.Options()
            let pool = PasswordGenerator.pool(for: options)
            let generated = PasswordGenerator.generate(options)
            let bits = PasswordGenerator.entropyBits(for: options)
            return firstFailure(
                expect(pool.count, equals: 86, "full pool size"),
                expect(generated.count, equals: 16, "default length"),
                expect(bits > 100, equals: true, "entropy over 100 bits"),
                expect(PasswordGenerator.strength(bits: 30), equals: .weak, "weak threshold")
            )
        },
        Case(name: "Smart input classification") {
            firstFailure(
                expect(InputClassifier.classify("192.168.1.1"), equals: .ipv4, "ipv4"),
                expect(InputClassifier.classify("aa:bb:cc:dd:ee:ff"), equals: .mac, "mac"),
                expect(InputClassifier.classify("https://apple.com"), equals: .url, "url"),
                expect(InputClassifier.classify("apple.com"), equals: .domain, "domain"),
                expect(InputClassifier.classify("hello"), equals: .none, "plain text")
            )
        },
        Case(name: "IP range enumeration") {
            do {
                let slash30 = try IPRangeScanner.hosts(cidr: "192.168.1.0/30")
                let slash24 = try IPRangeScanner.hosts(cidr: "10.0.0.0/24")
                return firstFailure(
                    expect(slash30, equals: ["192.168.1.1", "192.168.1.2"], "/30 usable hosts"),
                    expect(slash24.count, equals: 254, "/24 host count"),
                    expect(slash24.first ?? "", equals: "10.0.0.1", "first host"),
                    expect(slash24.last ?? "", equals: "10.0.0.254", "last host")
                )
            } catch { return "unexpected error: \(error)" }
        },
        Case(name: "Email syntax validation") {
            firstFailure(
                expect(EmailValidator.isValidSyntax("a@b.com"), equals: true, "valid"),
                expect(EmailValidator.isValidSyntax("a@b"), equals: false, "no TLD"),
                expect(EmailValidator.isValidSyntax("a b@c.com"), equals: false, "space"),
                expect(EmailValidator.isValidSyntax("@c.com"), equals: false, "empty local"),
                expect(EmailValidator.domain(of: "user@example.com") ?? "", equals: "example.com", "domain")
            )
        },
        Case(name: "RBL query building") {
            firstFailure(
                expect(RBL.query(ip: "1.2.3.4", zone: "zen.spamhaus.org") ?? "", equals: "4.3.2.1.zen.spamhaus.org", "reversed query"),
                expect(RBL.query(ip: "bad", zone: "z") == nil, equals: true, "reject non-IP")
            )
        },
        Case(name: "Port list parsing") {
            firstFailure(
                expect(PortList.parse("22,80,443") ?? [], equals: [22, 80, 443], "list"),
                expect(PortList.parse("1-3") ?? [], equals: [1, 2, 3], "range"),
                expect(PortList.parse("80, 100-102") ?? [], equals: [80, 100, 101, 102], "mixed"),
                expect(PortList.parse("70000") == nil, equals: true, "reject out of range")
            )
        },
        Case(name: "FTP PASV parsing") {
            let endpoint = FTP.parsePASV("227 Entering Passive Mode (192,168,1,10,195,80).")
            return firstFailure(
                expect(endpoint?.host ?? "", equals: "192.168.1.10", "data host"),
                expect(endpoint?.port ?? 0, equals: 195 * 256 + 80, "data port"),
                expect(FTP.parsePASV("500 error") == nil, equals: true, "reject non-PASV")
            )
        },
        Case(name: "Subnet membership") {
            firstFailure(
                expect(IPTools.contains(ip: "10.0.0.5", cidr: "10.0.0.0/24") ?? false, equals: true, "inside"),
                expect(IPTools.contains(ip: "10.0.1.5", cidr: "10.0.0.0/24") ?? true, equals: false, "outside"),
                expect(IPTools.contains(ip: "192.168.1.255", cidr: "192.168.1.0/24") ?? false, equals: true, "broadcast in range")
            )
        },
        Case(name: "WHOIS field parsing") {
            let sample = "Registrar: Example Registrar\nCreation Date: 2020-01-02\nRegistry Expiry Date: 2030-01-02\nName Server: NS1.EXAMPLE.COM\nName Server: NS2.EXAMPLE.COM"
            let fields = WhoisParser.parse(sample)
            return firstFailure(
                expect(fields.registrar ?? "", equals: "Example Registrar", "registrar"),
                expect(fields.created ?? "", equals: "2020-01-02", "created"),
                expect(fields.expires ?? "", equals: "2030-01-02", "expires"),
                expect(fields.nameServers.count, equals: 2, "name servers")
            )
        },
        Case(name: "SNMP GETNEXT encoding") {
            do {
                let getRequest = try SNMPMessage.encodeGet(oid: "1.3.6.1", community: "public", requestID: 1)
                let nextRequest = try SNMPMessage.encodeGetNext(oid: "1.3.6.1", community: "public", requestID: 1)
                let getBytes = [UInt8](getRequest)
                let nextBytes = [UInt8](nextRequest)
                // Same length; only the PDU tag differs (0xA0 GET vs 0xA1 GETNEXT).
                return firstFailure(
                    expect(getBytes.count, equals: nextBytes.count, "same length"),
                    expect(getBytes.contains(0xA0), equals: true, "GET PDU tag"),
                    expect(nextBytes.contains(0xA1), equals: true, "GETNEXT PDU tag")
                )
            } catch { return "unexpected error: \(error)" }
        },
    ]

    private static let cryptoCases: [Case] = [
        Case(name: "Hash known-answer vectors") {
            let hashes = CryptoTools.hashes(of: "abc")
            return firstFailure(
                expect(hashes.md5, equals: "900150983cd24fb0d6963f7d28e17f72", "MD5(abc)"),
                expect(hashes.sha1, equals: "a9993e364706816aba3e25717850c26c9cd0d89d", "SHA1(abc)"),
                expect(hashes.sha256, equals: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA256(abc)")
            )
        },
        Case(name: "JWT decode (header + payload)") {
            let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.sig"
            guard let jwt = CryptoTools.decodeJWT(token) else { return "JWT did not decode" }
            return firstFailure(
                expect(jwt.algorithm, equals: "HS256", "alg"),
                expect(jwt.payload.contains("John Doe"), equals: true, "payload claim")
            )
        },
        Case(name: "Pwned SHA-1 + range parse") {
            let (prefix, suffix) = PwnedCheck.split("password")
            let body = "0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n1E4C9B93F3F0682250B6CF8331B7EE68FD8:9999"
            return firstFailure(
                expect(prefix, equals: "5BAA6", "SHA-1 prefix"),
                expect(suffix, equals: "1E4C9B93F3F0682250B6CF8331B7EE68FD8", "SHA-1 suffix"),
                expect(PwnedCheck.countInResponse(body, suffix: suffix), equals: 9999, "matched count")
            )
        },
        Case(name: "Encrypted backup round-trip") {
            let plaintext = Data("{\"secret\":\"hunter2\"}".utf8)
            do {
                let box = try BackupCrypto.encrypt(plaintext, password: "correct horse")
                let isEnc = BackupCrypto.isEncrypted(box)
                let back = try BackupCrypto.decrypt(box, password: "correct horse")
                var wrongRejected = false
                do { _ = try BackupCrypto.decrypt(box, password: "wrong") }
                catch BackupCrypto.CryptoError.wrongPassword { wrongRejected = true }
                return firstFailure(
                    expect(isEnc, equals: true, "magic detected"),
                    expect(back, equals: plaintext, "decrypts to original"),
                    expect(wrongRejected, equals: true, "wrong password rejected"),
                    expect(BackupCrypto.isEncrypted(plaintext), equals: false, "plain not flagged")
                )
            } catch {
                return "unexpected error: \(error)"
            }
        },
        Case(name: "DNS reliability stats") {
            func probe(_ ms: Double?) -> DNSProbe { DNSProbe(timestamp: 0, latencyMs: ms, detail: "") }
            let probes = [probe(10), probe(20), probe(nil), probe(nil), probe(30), probe(nil), probe(40)]
            let summary = DNSReliabilityEngine.summarize(probes)
            let thresholded = DNSReliabilityEngine.summarize(probes, thresholdMs: 25)
            return firstFailure(
                expect(summary.total, equals: 7, "total"),
                expect(summary.successes, equals: 4, "successes"),
                expect(summary.failures, equals: 3, "failures"),
                expect(summary.dropEpisodes, equals: 2, "drop episodes"),
                expect(summary.longestDropStreak, equals: 2, "longest streak"),
                expect(summary.minLatency ?? -1, equals: 10, "min"),
                expect(summary.maxLatency ?? -1, equals: 40, "max"),
                expect(summary.avgLatency ?? -1, equals: 25, "avg"),
                expect(summary.jitter ?? -1, equals: 10, "jitter"),
                expect(Int(summary.successRate.rounded()), equals: 57, "success rate"),
                expect(summary.slowCount, equals: 0, "slow disabled"),
                expect(thresholded.slowCount, equals: 2, "slow over 25ms")
            )
        },
        Case(name: "MTR hop aggregation + Cymru ASN") {
            var hop = MTRHop(ttl: 3)
            MTREngine.record(&hop, address: "10.0.0.1", rttMs: 10, reached: false)
            MTREngine.record(&hop, address: "10.0.0.1", rttMs: nil, reached: false)   // a drop
            MTREngine.record(&hop, address: "10.0.0.1", rttMs: 30, reached: false)
            return firstFailure(
                expect(hop.sent, equals: 3, "sent"),
                expect(hop.received, equals: 2, "received"),
                expect(Int(hop.lossPercent.rounded()), equals: 33, "loss"),
                expect(hop.best ?? -1, equals: 10, "best"),
                expect(hop.worst ?? -1, equals: 30, "worst"),
                expect(hop.avg ?? -1, equals: 20, "avg"),
                expect(MTREngine.cymruQuery(for: "1.2.3.4"), equals: "4.3.2.1.origin.asn.cymru.com", "cymru query"),
                expect(MTREngine.cymruQuery(for: "apple.com"), equals: nil, "cymru non-ip"),
                expect(MTREngine.parseASN("13335 | 104.16.0.0/12 | US | arin | 2011"), equals: "AS13335", "parse asn")
            )
        },
        Case(name: "TLS grade heuristics") {
            let modern = TLSAudit.grade(protocols: ["TLS 1.2", "TLS 1.3"], daysRemaining: 200, trusted: true, keyBits: 256, keyType: "EC")
            let legacy = TLSAudit.grade(protocols: ["TLS 1.0", "TLS 1.1", "TLS 1.2"], daysRemaining: 200, trusted: true, keyBits: 2048, keyType: "RSA")
            let expired = TLSAudit.grade(protocols: ["TLS 1.3"], daysRemaining: -1, trusted: true, keyBits: 2048, keyType: "RSA")
            let weak = TLSAudit.grade(protocols: ["TLS 1.2"], daysRemaining: 100, trusted: true, keyBits: 1024, keyType: "RSA")
            let untrusted = TLSAudit.grade(protocols: ["TLS 1.3"], daysRemaining: 100, trusted: false, keyBits: 2048, keyType: "RSA")
            return firstFailure(
                expect(modern.grade, equals: "A+", "modern EC"),
                expect(legacy.grade, equals: "C", "legacy downgrade"),
                expect(expired.grade, equals: "F", "expired"),
                expect(weak.grade, equals: "F", "weak RSA key"),
                expect(untrusted.grade, equals: "T", "untrusted")
            )
        },
        Case(name: "Bufferbloat grade") {
            return firstFailure(
                expect(BufferbloatGrade.grade(increaseMs: 2), equals: "A+", "excellent"),
                expect(BufferbloatGrade.grade(increaseMs: 20), equals: "A", "good"),
                expect(BufferbloatGrade.grade(increaseMs: 45), equals: "B", "ok"),
                expect(BufferbloatGrade.grade(increaseMs: 80), equals: "C", "fair"),
                expect(BufferbloatGrade.grade(increaseMs: 150), equals: "D", "poor"),
                expect(BufferbloatGrade.grade(increaseMs: 400), equals: "F", "bad")
            )
        },
        Case(name: "DNS propagation consistency + DNSSEC query") {
            let a = DNSResolverResult(name: "A", server: "1.1.1.1", values: ["1.2.3.4"])
            let b = DNSResolverResult(name: "B", server: "8.8.8.8", values: ["1.2.3.4"])
            let c = DNSResolverResult(name: "C", server: "9.9.9.9", values: ["9.9.9.9"])
            var d = DNSResolverResult(name: "D", server: "4.2.2.2"); d.error = "timeout"
            let signedQuery = (try? DNSMessage.encodeQuery(name: "cloudflare.com", type: .a, id: 1, dnssecOK: true)) ?? Data()
            let plainQuery = (try? DNSMessage.encodeQuery(name: "cloudflare.com", type: .a, id: 1)) ?? Data()
            return firstFailure(
                expect(DNSHealthEngine.consistent([a, b]), equals: true, "same answers"),
                expect(DNSHealthEngine.consistent([a, c]), equals: false, "different answers"),
                expect(DNSHealthEngine.consistent([a, b, d]), equals: true, "errors ignored"),
                expect(signedQuery.count > plainQuery.count, equals: true, "EDNS OPT appended")
            )
        },
        Case(name: "Ping stddev + security grade") {
            let summary = TCPPingService.summarize([
                PingAttempt(sequence: 1, milliseconds: 10),
                PingAttempt(sequence: 2, milliseconds: 20),
                PingAttempt(sequence: 3, milliseconds: nil),
                PingAttempt(sequence: 4, milliseconds: 30),
            ])
            return firstFailure(
                expect(summary.sent, equals: 4, "sent"),
                expect(summary.received, equals: 3, "received"),
                expect(summary.lossPercent, equals: 25, "loss"),
                expect(summary.avgMs ?? -1, equals: 20, "avg"),
                expect(Int((summary.mdevMs ?? -1).rounded()), equals: 8, "stddev"),
                expect(SecurityGrade.letter(100), equals: "A+", "perfect"),
                expect(SecurityGrade.letter(72), equals: "B", "b grade"),
                expect(SecurityGrade.letter(10), equals: "F", "f grade")
            )
        },
        Case(name: "RPKI ASN + status parsing") {
            return firstFailure(
                expect(RPKIEngine.normalizeASN("AS13335"), equals: "13335", "strip AS"),
                expect(RPKIEngine.normalizeASN("as 7018"), equals: "7018", "lowercase + space"),
                expect(RPKIEngine.normalizeASN("15169"), equals: "15169", "digits only"),
                expect(RPKIStatus.from("valid"), equals: .valid, "valid"),
                expect(RPKIStatus.from("invalid_asn"), equals: .invalid, "invalid asn"),
                expect(RPKIStatus.from("weird"), equals: .unknown, "unknown")
            )
        },
        Case(name: "Certificate expiry buckets") {
            return firstFailure(
                expect(CertExpiryEngine.level(days: 90), equals: .ok, "healthy"),
                expect(CertExpiryEngine.level(days: 20), equals: .warning, "warning"),
                expect(CertExpiryEngine.level(days: 5), equals: .critical, "critical"),
                expect(CertExpiryEngine.level(days: -1), equals: .expired, "expired"),
                expect(CertExpiryEngine.level(days: nil), equals: .unknown, "unknown")
            )
        },
        Case(name: "Service fingerprint heuristics") {
            let ssh = ServiceFingerprint.identify(banner: "SSH-2.0-OpenSSH_8.9p1 Ubuntu-3", port: 22)
            let http = ServiceFingerprint.identify(banner: "HTTP/1.1 200 OK\r\nServer: nginx/1.25.3\r\n", port: 80)
            let ftp = ServiceFingerprint.identify(banner: "220 (vsFTPd 3.0.5)", port: 21)
            let pop = ServiceFingerprint.identify(banner: "+OK Dovecot ready.", port: 110)
            return firstFailure(
                expect(ssh.service, equals: "SSH", "ssh service"),
                expect(ssh.product, equals: "OpenSSH_8.9p1 Ubuntu-3", "ssh product"),
                expect(http.service, equals: "HTTP", "http service"),
                expect(http.product, equals: "nginx/1.25.3", "http server"),
                expect(ftp.service, equals: "FTP", "ftp service"),
                expect(pop.service, equals: "POP3", "pop3 service")
            )
        },
        Case(name: "CSV export encoding") {
            return firstFailure(
                expect(CSV.field("plain"), equals: "plain", "plain"),
                expect(CSV.field("a,b"), equals: "\"a,b\"", "comma quoted"),
                expect(CSV.field("say \"hi\""), equals: "\"say \"\"hi\"\"\"", "quote escaped"),
                expect(CSV.row(["a", "b,c"]), equals: "a,\"b,c\"", "row"),
                expect(CSV.table(header: ["x"], rows: [["1"], ["2"]]), equals: "x\n1\n2", "table")
            )
        },
        Case(name: "IPv6 address range") {
            let result: IPv6SubnetResult
            do { result = try SubnetEngine.calculateIPv6(address: "2001:db8::", prefix: "32") }
            catch { return "unexpected error: \(error)" }
            return firstFailure(
                expect(result.firstAddress, equals: "2001:db8::", "first"),
                expect(result.lastAddress, equals: "2001:db8:ffff:ffff:ffff:ffff:ffff:ffff", "last")
            )
        },
        Case(name: "SSDP response parsing") {
            let response = "HTTP/1.1 200 OK\r\nLOCATION: http://192.168.1.1:5000/rootDesc.xml\r\nSERVER: Linux/3.14 UPnP/1.0\r\nST: upnp:rootdevice\r\nUSN: uuid:abcd::upnp:rootdevice\r\n\r\n"
            let device = SSDPEngine.parse(response, address: "192.168.1.1")
            return firstFailure(
                expect(device.location, equals: "http://192.168.1.1:5000/rootDesc.xml", "location"),
                expect(device.server, equals: "Linux/3.14 UPnP/1.0", "server"),
                expect(device.searchTarget, equals: "upnp:rootdevice", "st"),
                expect(device.usn, equals: "uuid:abcd::upnp:rootdevice", "usn")
            )
        },
        Case(name: "Hash identifier heuristics") {
            return firstFailure(
                expect(HashID.identify("5f4dcc3b5aa765d61d8327deb882cf99").contains("MD5"), equals: true, "MD5 length"),
                expect(HashID.identify("a9993e364706816aba3e25717850c26c9cd0d89d").contains("SHA-1"), equals: true, "SHA-1 length"),
                expect(HashID.identify("$2b$12$abcdefghijklmnopqrstuv"), equals: ["bcrypt"], "bcrypt prefix"),
                expect(HashID.identify("xyz").isEmpty, equals: true, "unknown")
            )
        },
        Case(name: "Base64url decoding") {
            let data = CryptoTools.base64urlDecode("SGVsbG8t"[...]) ?? Data()
            return expect(String(decoding: data, as: UTF8.self), equals: "Hello-", "base64url")
        },
    ]

    private static let featureCases: [Case] = [
        Case(name: "WireGuard config assembly") {
            let config = WireGuardQR.config(
                privateKey: "PRIV", address: "10.0.0.2/32", dns: "1.1.1.1",
                peerPublicKey: "PUB", presharedKey: "", endpoint: "vpn:51820",
                allowedIPs: "0.0.0.0/0", keepalive: "25"
            )
            let expected = "[Interface]\nPrivateKey = PRIV\nAddress = 10.0.0.2/32\nDNS = 1.1.1.1\n\n[Peer]\nPublicKey = PUB\nEndpoint = vpn:51820\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25"
            return firstFailure(
                expect(config, equals: expected, "config text (empty PSK omitted)"),
                expect(config.contains("PresharedKey"), equals: false, "no empty PSK line")
            )
        },
        Case(name: "WireGuard Curve25519 key derivation") {
            let pair = WireGuardQR.generateKeypair()
            let derived = WireGuardQR.publicKey(for: pair.privateKey) ?? ""
            return expect(derived, equals: pair.publicKey, "public key matches private")
        },
        Case(name: "SDP video parse (H.264)") {
            let sdp = "v=0\r\nm=video 0 RTP/AVP 96\r\na=rtpmap:96 H264/90000\r\na=fmtp:96 sprop-parameter-sets=Z0IACpZTBYmI,aMljiA==\r\na=control:trackID=1\r\n"
            guard let media = SDPParser.parseVideo(sdp) else { return "no video media parsed" }
            return firstFailure(
                expect(media.codec, equals: .h264, "codec"),
                expect(media.payloadType, equals: 96, "payload type"),
                expect(media.control, equals: "trackID=1", "control"),
                expect(media.parameterSets.count, equals: 2, "SPS+PPS")
            )
        },
        Case(name: "ONVIF profiles parse") {
            let xml = "<Profiles token=\"P1\"><Name>main</Name><VideoEncoderConfiguration><Resolution><Width>1920</Width><Height>1080</Height></Resolution><Encoding>H264</Encoding></VideoEncoderConfiguration></Profiles>"
            let parser = ONVIFProfilesParser()
            parser.run(xml)
            guard let first = parser.profiles.first else { return "no profile parsed" }
            return firstFailure(
                expect(parser.profiles.count, equals: 1, "profile count"),
                expect(first.token, equals: "P1", "token"),
                expect(first.name, equals: "main", "name"),
                expect(first.width ?? 0, equals: 1920, "width"),
                expect(first.height ?? 0, equals: 1080, "height")
            )
        },
        Case(name: "EUI-64 / SLAAC") {
            guard let iface = EUI64.interfaceID(fromMAC: "00:1a:2b:3c:4d:5e") else { return "interface ID nil" }
            let address = EUI64.slaac(prefix: "fe80::/64", mac: "00:1a:2b:3c:4d:5e") ?? ""
            return firstFailure(
                expect(iface, equals: "021a:2bff:fe3c:4d5e", "modified EUI-64"),
                expect(address, equals: "fe80::21a:2bff:fe3c:4d5e", "SLAAC address")
            )
        },
        Case(name: "CIDR aggregation") {
            let merged = CIDRAggregate.aggregate("192.168.0.0/24\n192.168.1.0/24")
            let split = CIDRAggregate.aggregate("10.0.0.1, 10.0.0.2, 10.0.0.3")
            return firstFailure(
                expect(merged, equals: ["192.168.0.0/23"], "adjacent /24s merge"),
                expect(split, equals: ["10.0.0.1/32", "10.0.0.2/31"], "host range to CIDRs")
            )
        },
        Case(name: "JSON format / minify") {
            guard case .success(let minified) = JSONTools.transform("{\"b\":1,\"a\":2}", minify: true) else {
                return "minify failed"
            }
            guard case .failure = JSONTools.transform("{bad}", minify: false) else {
                return "invalid JSON was not rejected"
            }
            return expect(minified, equals: "{\"a\":2,\"b\":1}", "sorted minified JSON")
        },
        Case(name: "RESP formatting") {
            let simple = RESP.format(Data("+OK\r\n".utf8))
            let integer = RESP.format(Data(":42\r\n".utf8))
            let bulk = RESP.format(Data("$3\r\nfoo\r\n".utf8))
            return firstFailure(
                expect(simple, equals: "OK", "simple string"),
                expect(integer, equals: "(integer) 42", "integer"),
                expect(bulk, equals: "\"foo\"", "bulk string")
            )
        },
        Case(name: "Modbus request + parse") {
            let request = [UInt8](Modbus.request(transaction: 1, unit: 1, function: 3, address: 0, quantity: 2))
            guard let parsed = Modbus.parse(Data([0, 1, 0, 0, 0, 5, 1, 3, 4, 0, 10, 0, 20])) else {
                return "Modbus response did not parse"
            }
            return firstFailure(
                expect(request, equals: [0, 1, 0, 0, 0, 6, 1, 3, 0, 0, 0, 2], "read-holding request"),
                expect(parsed, equals: Modbus.ParseResult.registers([10, 20]), "parsed registers")
            )
        },
        Case(name: "Regex matching + groups") {
            guard case .success(let matches) = RegexTools.matches(pattern: "(\\d)(\\d)", text: "a12b34", caseInsensitive: false) else {
                return "regex failed to compile"
            }
            guard case .failure = RegexTools.matches(pattern: "(", text: "x", caseInsensitive: false) else {
                return "invalid pattern was not rejected"
            }
            return firstFailure(
                expect(matches.count, equals: 2, "match count"),
                expect(matches.first?.full ?? "", equals: "12", "first match"),
                expect(matches.first?.groups ?? [], equals: ["1", "2"], "capture groups")
            )
        },
        Case(name: "URL component parsing") {
            guard let rows = URLParse.components("https://user@host.com:8080/a/b?x=1&y=2#frag") else {
                return "URL did not parse"
            }
            let map = Dictionary(rows.map { ($0.label, $0.value) }, uniquingKeysWith: { a, _ in a })
            return firstFailure(
                expect(map["Scheme"] ?? "", equals: "https", "scheme"),
                expect(map["Host"] ?? "", equals: "host.com", "host"),
                expect(map["Port"] ?? "", equals: "8080", "port"),
                expect(map["Path"] ?? "", equals: "/a/b", "path"),
                expect(map["query: x"] ?? "", equals: "1", "query x")
            )
        },
        Case(name: "Data transfer time") {
            let seconds = DataCalc.transferSeconds(
                sizeBytes: DataCalc.bytes(value: 1, unit: "GB"),
                bitsPerSecond: DataCalc.bitsPerSecond(value: 100, unit: "Mbps")
            )
            return expect(seconds, equals: 80, "1GB over 100Mbps = 80s")
        },
        Case(name: "TFTP read request") {
            let rrq = TFTPClient.rrqPacket(filename: "boot.cfg")
            var expected: [UInt8] = [0x00, 0x01]
            expected.append(contentsOf: Array("boot.cfg".utf8)); expected.append(0)
            expected.append(contentsOf: Array("octet".utf8)); expected.append(0)
            return expect(rrq, equals: expected, "RRQ packet")
        },
        Case(name: "CoAP GET encode + parse") {
            let request = [UInt8](CoAP.get(path: "test", messageID: 0x1234))
            guard let parsed = CoAP.parse(Data([0x60, 0x45, 0, 0, 0xFF, 0x68, 0x69])) else {
                return "CoAP response did not parse"
            }
            return firstFailure(
                expect(request, equals: [0x40, 0x01, 0x12, 0x34, 0xB4, 0x74, 0x65, 0x73, 0x74], "GET /test"),
                expect(parsed.code, equals: "2.05", "response code"),
                expect(parsed.payload, equals: "hi", "payload")
            )
        },
        Case(name: "SNMP trap community decode") {
            let message = Data([0x30, 0x0B, 0x02, 0x01, 0x01, 0x04, 0x06, 0x70, 0x75, 0x62, 0x6C, 0x69, 0x63])
            return expect(SNMPTrapDecode.summary(message), equals: "SNMP v2c · community: public", "v2c community")
        },
        Case(name: "MQTT wire encoding") {
            let string = MQTTClient.encodeString("MQTT")
            let long = MQTTClient.encodeRemainingLength(321)
            let short = MQTTClient.encodeRemainingLength(64)
            guard let decoded = MQTTClient.decodeRemainingLength(Data([0xC1, 0x02]), from: 0) else {
                return "remaining length did not decode"
            }
            return firstFailure(
                expect(string, equals: [0x00, 0x04, 0x4D, 0x51, 0x54, 0x54], "encoded MQTT string"),
                expect(short, equals: [0x40], "short remaining length"),
                expect(long, equals: [0xC1, 0x02], "multi-byte remaining length (321)"),
                expect(decoded.value, equals: 321, "decoded remaining length"),
                expect(decoded.bytes, equals: 2, "decoded byte count")
            )
        },
        Case(name: "Backup JSON round-trip") {
            var backup = AppBackup()
            backup.hosts = [SavedHostsStore.Host(name: "h", address: "1.2.3.4", notes: "")]
            backup.cameras = [CameraStore.Camera(name: "cam", host: "10.0.0.9")]
            guard let data = try? JSONEncoder().encode(backup),
                  let decoded = try? JSONDecoder().decode(AppBackup.self, from: data) else {
                return "encode/decode failed"
            }
            return firstFailure(
                expect(decoded.hosts.count, equals: 1, "hosts"),
                expect(decoded.hosts.first?.address ?? "", equals: "1.2.3.4", "host address"),
                expect(decoded.cameras.first?.host ?? "", equals: "10.0.0.9", "camera host")
            )
        },
    ]

    private static let sshCases: [Case] = [
        Case(name: "SSH wire string + uint32 round-trip") {
            var data = Data()
            SSHWire.putUInt32(0x0102_0304, into: &data)
            SSHWire.putString("hello", into: &data)
            var reader = SSHWire.Reader(data)
            return firstFailure(
                expect(reader.readUInt32() ?? 0, equals: UInt32(0x0102_0304), "uint32"),
                expect(reader.readStringUTF8() ?? "", equals: "hello", "string")
            )
        },
        Case(name: "SSH name-list round-trip") {
            var data = Data()
            SSHWire.putNameList(["ssh-ed25519", "rsa-sha2-256"], into: &data)
            var reader = SSHWire.Reader(data)
            return expect(reader.readNameList() ?? [], equals: ["ssh-ed25519", "rsa-sha2-256"], "name-list")
        },
        Case(name: "SSH mpint encoding") {
            var high = Data(); SSHWire.putMPInt(Data([0x80, 0x00]), into: &high)
            var zero = Data(); SSHWire.putMPInt(Data([0x00, 0x00]), into: &zero)
            var lead = Data(); SSHWire.putMPInt(Data([0x00, 0x12, 0x34]), into: &lead)
            return firstFailure(
                expect([UInt8](high), equals: [0, 0, 0, 3, 0, 0x80, 0x00], "high bit gets a leading zero"),
                expect([UInt8](zero), equals: [0, 0, 0, 0], "zero encodes empty"),
                expect([UInt8](lead), equals: [0, 0, 0, 2, 0x12, 0x34], "leading zeros stripped")
            )
        },
    ]

    /// Known-answer tests for the X25519 layer SSH key exchange depends on,
    /// using the RFC 7748 §6.1 vectors. If these pass, CryptoKit's raw
    /// Curve25519 bytes match the wire format an SSH server expects, so a
    /// key-exchange interop failure must lie elsewhere (hash assembly / KDF).
    private static let curve25519Cases: [Case] = [
        Case(name: "X25519 public key (RFC 7748)") {
            let priv = Data(hexBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
            guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: priv) else {
                return "could not build private key"
            }
            return expect(
                [UInt8](key.publicKey.rawRepresentation),
                equals: hexBytes("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"),
                "derived public key"
            )
        },
        Case(name: "X25519 shared secret (RFC 7748)") {
            let priv = Data(hexBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
            let peer = Data(hexBytes("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f"))
            guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: priv),
                  let peerKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peer),
                  let shared = try? key.sharedSecretFromKeyAgreement(with: peerKey) else {
                return "key agreement failed"
            }
            return expect(
                shared.withUnsafeBytes { [UInt8]($0) },
                equals: hexBytes("4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"),
                "shared secret"
            )
        },
        Case(name: "SSH AES-GCM packet round-trip") {
            var sender = SSHGCMCipher(key: Data(repeating: 0x42, count: 32), iv: Data(repeating: 0x01, count: 12))
            var receiver = SSHGCMCipher(key: Data(repeating: 0x42, count: 32), iv: Data(repeating: 0x01, count: 12))
            let payload = Data("hello ssh world".utf8)
            var lengthField = Data(); SSHWire.putUInt32(UInt32(payload.count), into: &lengthField)
            guard let sealed = sender.seal(plaintext: payload, lengthField: lengthField) else { return "seal failed" }
            let ciphertext = Data(sealed.prefix(payload.count))
            let tag = Data(sealed.suffix(16))
            guard let opened = receiver.open(ciphertext: ciphertext, tag: tag, lengthField: lengthField) else {
                return "open failed"
            }
            return expect([UInt8](opened), equals: [UInt8](payload), "gcm round-trip")
        },
    ]
}
