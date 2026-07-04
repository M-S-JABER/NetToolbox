import Foundation

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

    static let allCases: [Case] = ipv4Cases + ipv6Cases + macCases + codecCases

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
            // "a" at offset 1, then a pointer to it at offset 3.
            let bytes: [UInt8] = [0x01, 0x61, 0x00, 0xC0, 0x01]
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
}
