import Foundation

/// Errors thrown by `SubnetEngine`, with bilingual user-facing descriptions.
enum SubnetEngineError: LocalizedError, Equatable {
    case invalidIPv4Address
    case invalidIPv6Address
    case invalidPrefix
    case invalidSubnetMask
    case nonContiguousMask

    var errorDescription: String? {
        switch self {
        case .invalidIPv4Address: String(localized: "error.subnet.invalidIPv4", bundle: .module)
        case .invalidIPv6Address: String(localized: "error.subnet.invalidIPv6", bundle: .module)
        case .invalidPrefix: String(localized: "error.subnet.invalidPrefix", bundle: .module)
        case .invalidSubnetMask: String(localized: "error.subnet.invalidMask", bundle: .module)
        case .nonContiguousMask: String(localized: "error.subnet.nonContiguous", bundle: .module)
        }
    }
}

/// IPv4 address classes (informational; classless routing is the norm).
enum IPv4Class: String, Sendable {
    case a = "A", b = "B", c = "C"
    case d = "D (Multicast)"
    case e = "E (Reserved)"
}

/// Scope of an IPv4 address.
enum IPv4Scope: Sendable, Equatable {
    case privateRange
    case publicRange
    case loopback
    case linkLocal
    case cgNAT
    case thisNetwork
    case multicast
    case reserved
    case broadcast

    var labelKey: String {
        switch self {
        case .privateRange: "subnet.scope.private"
        case .publicRange: "subnet.scope.public"
        case .loopback: "subnet.scope.loopback"
        case .linkLocal: "subnet.scope.linkLocal"
        case .cgNAT: "subnet.scope.cgnat"
        case .thisNetwork: "subnet.scope.thisNetwork"
        case .multicast: "subnet.scope.multicast"
        case .reserved: "subnet.scope.reserved"
        case .broadcast: "subnet.scope.broadcast"
        }
    }
}

/// Full IPv4 subnet calculation output. All strings are display-ready.
struct IPv4SubnetResult: Sendable, Equatable {
    let address: String
    let prefix: Int
    let subnetMask: String
    let wildcardMask: String
    let networkAddress: String
    let broadcastAddress: String
    let firstUsableHost: String
    let lastUsableHost: String
    let usableHostCount: UInt64
    let totalAddressCount: UInt64
    let addressBinary: String
    let maskBinary: String
    let ipClass: IPv4Class
    let scope: IPv4Scope

    var cidrNotation: String { "\(networkAddress)/\(prefix)" }
    var isPrivate: Bool { scope == .privateRange }
}

/// IPv6 address types by leading bits.
enum IPv6AddressType: Sendable, Equatable {
    case loopback
    case unspecified
    case linkLocal
    case uniqueLocal
    case multicast
    case globalUnicast
    case documentation

    var labelKey: String {
        switch self {
        case .loopback: "subnet.v6.loopback"
        case .unspecified: "subnet.v6.unspecified"
        case .linkLocal: "subnet.v6.linkLocal"
        case .uniqueLocal: "subnet.v6.uniqueLocal"
        case .multicast: "subnet.v6.multicast"
        case .globalUnicast: "subnet.v6.globalUnicast"
        case .documentation: "subnet.v6.documentation"
        }
    }
}

/// Basic IPv6 calculation output.
struct IPv6SubnetResult: Sendable, Equatable {
    let compressed: String
    let expanded: String
    let networkPrefix: String
    let prefix: Int
    let addressType: IPv6AddressType
    /// Host bits (128 - prefix); total addresses = 2^hostBits.
    let hostBits: Int

    var cidrNotation: String { "\(networkPrefix)/\(prefix)" }
    /// Human-friendly total ("2^64" for large values, exact number otherwise).
    var totalAddressesDescription: String {
        hostBits > 40 ? "2^\(hostBits)" : String(UInt64(1) << UInt64(hostBits))
    }
}

/// Pure subnetting math. No UI, no I/O — fully unit-testable.
enum SubnetEngine {

    // MARK: - IPv4 parsing

    /// Parses dotted-quad IPv4 into a host-order 32-bit value.
    static func parseIPv4(_ text: String) throws -> UInt32 {
        let parts = text.trimmingCharacters(in: .whitespaces).split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard parts.count == 4 else { throw SubnetEngineError.invalidIPv4Address }

        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty,
                  part.count <= 3,
                  part.allSatisfy(\.isNumber),
                  let octet = UInt32(part),
                  octet <= 255
            else { throw SubnetEngineError.invalidIPv4Address }
            value = (value << 8) | octet
        }
        return value
    }

    /// Parses a prefix from "/24", "24", or a dotted mask "255.255.255.0".
    /// Dotted masks must be contiguous (ones followed by zeros).
    static func parseIPv4Prefix(_ text: String) throws -> Int {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("/") { trimmed.removeFirst() }
        guard !trimmed.isEmpty else { throw SubnetEngineError.invalidPrefix }

        if trimmed.contains(".") {
            let mask: UInt32
            do {
                mask = try parseIPv4(trimmed)
            } catch {
                throw SubnetEngineError.invalidSubnetMask
            }
            return try prefix(fromMask: mask)
        }

        guard trimmed.allSatisfy(\.isNumber),
              let prefix = Int(trimmed),
              (0...32).contains(prefix)
        else { throw SubnetEngineError.invalidPrefix }
        return prefix
    }

    /// Converts a mask value to a prefix length, rejecting non-contiguous masks.
    static func prefix(fromMask mask: UInt32) throws -> Int {
        let ones = mask.leadingZeroBitCount == 0
            ? (~mask).leadingZeroBitCount
            : (mask == 0 ? 0 : -1)
        guard ones >= 0, mask == maskValue(forPrefix: ones) else {
            throw SubnetEngineError.nonContiguousMask
        }
        return ones
    }

    /// Mask value for a prefix (0...32). `/0` → 0, `/32` → all ones.
    static func maskValue(forPrefix prefix: Int) -> UInt32 {
        guard prefix > 0 else { return 0 }
        guard prefix < 32 else { return ~UInt32(0) }
        return ~UInt32(0) << (32 - UInt32(prefix))
    }

    // MARK: - IPv4 calculation

    /// Calculates the full subnet breakdown for an IPv4 address.
    /// - Parameters:
    ///   - address: dotted quad, optionally with an inline prefix ("10.0.0.1/24").
    ///   - mask: CIDR ("24" / "/24") or dotted mask; ignored when the
    ///     address carries an inline prefix.
    static func calculateIPv4(address: String, mask: String) throws -> IPv4SubnetResult {
        var addressText = address.trimmingCharacters(in: .whitespaces)
        var maskText = mask.trimmingCharacters(in: .whitespaces)

        if let slash = addressText.firstIndex(of: "/") {
            maskText = String(addressText[addressText.index(after: slash)...])
            addressText = String(addressText[..<slash])
        }

        let ip = try parseIPv4(addressText)
        let prefix = try parseIPv4Prefix(maskText)
        let mask = maskValue(forPrefix: prefix)

        let network = ip & mask
        let broadcast = network | ~mask
        let totalAddresses = UInt64(1) << UInt64(32 - prefix)

        let firstHost: UInt32
        let lastHost: UInt32
        let usableHosts: UInt64
        switch prefix {
        case 32:
            // Single host route.
            firstHost = ip; lastHost = ip; usableHosts = 1
        case 31:
            // RFC 3021 point-to-point: both addresses are usable.
            firstHost = network; lastHost = broadcast; usableHosts = 2
        default:
            firstHost = network &+ 1
            lastHost = broadcast &- 1
            usableHosts = totalAddresses - 2
        }

        return IPv4SubnetResult(
            address: format(ipv4: ip),
            prefix: prefix,
            subnetMask: format(ipv4: mask),
            wildcardMask: format(ipv4: ~mask),
            networkAddress: format(ipv4: network),
            broadcastAddress: format(ipv4: broadcast),
            firstUsableHost: format(ipv4: firstHost),
            lastUsableHost: format(ipv4: lastHost),
            usableHostCount: usableHosts,
            totalAddressCount: totalAddresses,
            addressBinary: binary(ipv4: ip),
            maskBinary: binary(ipv4: mask),
            ipClass: ipClass(of: ip),
            scope: scope(of: ip)
        )
    }

    /// Formats a host-order value as a dotted quad.
    static func format(ipv4 value: UInt32) -> String {
        "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
    }

    /// Dotted binary representation, e.g. "11000000.10101000.00000001.00001010".
    static func binary(ipv4 value: UInt32) -> String {
        (0..<4)
            .map { octetIndex -> String in
                let octet = (value >> UInt32(8 * (3 - octetIndex))) & 0xFF
                let bits = String(octet, radix: 2)
                return String(repeating: "0", count: 8 - bits.count) + bits
            }
            .joined(separator: ".")
    }

    static func ipClass(of ip: UInt32) -> IPv4Class {
        switch ip >> 24 {
        case 0..<128: .a
        case 128..<192: .b
        case 192..<224: .c
        case 224..<240: .d
        default: .e
        }
    }

    /// Classifies special-use ranges (RFC 1918, 3927, 6598, 5735...).
    static func scope(of ip: UInt32) -> IPv4Scope {
        let o1 = ip >> 24
        let o2 = (ip >> 16) & 0xFF

        if ip == 0xFFFF_FFFF { return .broadcast }
        switch o1 {
        case 0: return .thisNetwork
        case 10: return .privateRange
        case 100 where (64...127).contains(o2): return .cgNAT
        case 127: return .loopback
        case 169 where o2 == 254: return .linkLocal
        case 172 where (16...31).contains(o2): return .privateRange
        case 192 where o2 == 168: return .privateRange
        case 224..<240: return .multicast
        case 240...: return .reserved
        default: return .publicRange
        }
    }

    // MARK: - IPv6 parsing

    /// Parses an IPv6 address into its 8 hextets.
    /// Supports "::" compression; embedded IPv4 notation is not supported.
    static func parseIPv6(_ text: String) throws -> [UInt16] {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !trimmed.contains(".") else {
            throw SubnetEngineError.invalidIPv6Address
        }

        let compressionMarkers = trimmed.components(separatedBy: "::")
        guard compressionMarkers.count <= 2 else {
            throw SubnetEngineError.invalidIPv6Address
        }

        func hextets(from part: String) throws -> [UInt16] {
            guard !part.isEmpty else { return [] }
            return try part.split(separator: ":", omittingEmptySubsequences: false).map {
                guard !$0.isEmpty, $0.count <= 4, let value = UInt16($0, radix: 16) else {
                    throw SubnetEngineError.invalidIPv6Address
                }
                return value
            }
        }

        if compressionMarkers.count == 2 {
            let head = try hextets(from: compressionMarkers[0])
            let tail = try hextets(from: compressionMarkers[1])
            let missing = 8 - head.count - tail.count
            // "::" must stand for at least one zero group.
            guard missing >= 1 else { throw SubnetEngineError.invalidIPv6Address }
            return head + Array(repeating: 0, count: missing) + tail
        }

        let groups = try hextets(from: trimmed)
        guard groups.count == 8 else { throw SubnetEngineError.invalidIPv6Address }
        return groups
    }

    /// Full 8-group, 4-digit form: "2001:0db8:0000:...".
    static func expanded(ipv6 groups: [UInt16]) -> String {
        groups.map { String(format: "%04x", $0) }.joined(separator: ":")
    }

    /// RFC 5952 canonical compressed form (longest zero run of 2+ collapsed).
    static func compressed(ipv6 groups: [UInt16]) -> String {
        var bestStart = -1
        var bestLength = 0
        var index = 0
        while index < groups.count {
            guard groups[index] == 0 else { index += 1; continue }
            var end = index
            while end < groups.count, groups[end] == 0 { end += 1 }
            if end - index > bestLength {
                bestStart = index
                bestLength = end - index
            }
            index = end
        }

        let hex = groups.map { String($0, radix: 16) }
        guard bestLength >= 2 else {
            return hex.joined(separator: ":")
        }
        let head = hex[..<bestStart].joined(separator: ":")
        let tail = hex[(bestStart + bestLength)...].joined(separator: ":")
        return head + "::" + tail
    }

    // MARK: - IPv6 calculation

    /// Basic IPv6 subnet info: canonical forms, network prefix and type.
    static func calculateIPv6(address: String, prefix prefixInput: String) throws -> IPv6SubnetResult {
        var addressText = address.trimmingCharacters(in: .whitespaces)
        var prefixText = prefixInput.trimmingCharacters(in: .whitespaces)

        if let slash = addressText.firstIndex(of: "/") {
            prefixText = String(addressText[addressText.index(after: slash)...])
            addressText = String(addressText[..<slash])
        }

        if prefixText.hasPrefix("/") { prefixText.removeFirst() }
        guard prefixText.allSatisfy(\.isNumber),
              let prefix = Int(prefixText),
              (0...128).contains(prefix)
        else { throw SubnetEngineError.invalidPrefix }

        let groups = try parseIPv6(addressText)
        let network = applyPrefix(prefix, to: groups)

        return IPv6SubnetResult(
            compressed: compressed(ipv6: groups),
            expanded: expanded(ipv6: groups),
            networkPrefix: compressed(ipv6: network),
            prefix: prefix,
            addressType: addressType(of: groups),
            hostBits: 128 - prefix
        )
    }

    /// Zeroes host bits beyond `prefix` across the 8 hextets.
    static func applyPrefix(_ prefix: Int, to groups: [UInt16]) -> [UInt16] {
        groups.enumerated().map { index, group in
            let bitsBefore = index * 16
            let keep = max(0, min(16, prefix - bitsBefore))
            guard keep > 0 else { return 0 }
            guard keep < 16 else { return group }
            let mask = UInt16.max << (16 - UInt16(keep))
            return group & mask
        }
    }

    static func addressType(of groups: [UInt16]) -> IPv6AddressType {
        if groups == [0, 0, 0, 0, 0, 0, 0, 1] { return .loopback }
        if groups.allSatisfy({ $0 == 0 }) { return .unspecified }
        let first = groups[0]
        if first & 0xFFC0 == 0xFE80 { return .linkLocal }
        if first & 0xFE00 == 0xFC00 { return .uniqueLocal }
        if first & 0xFF00 == 0xFF00 { return .multicast }
        if first == 0x2001, groups[1] == 0x0DB8 { return .documentation }
        if first & 0xE000 == 0x2000 { return .globalUnicast }
        return .globalUnicast
    }
}
