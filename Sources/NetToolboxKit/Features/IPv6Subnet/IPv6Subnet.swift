import SwiftUI
import Observation

// MARK: - Engine

struct IPv6SubnetResult: Equatable, Sendable {
    let networkCompressed: String
    let networkExpanded: String
    let prefixLength: Int
    let firstAddress: String
    let lastAddress: String
    let addressCount: String
    let kind: String
}

/// Pure IPv6 prefix math (parse, mask, expand/compress) — unit-tested.
enum IPv6Engine {
    /// Parses "2001:db8::1/64" into 16 bytes + prefix length.
    static func parse(_ input: String) -> (bytes: [UInt8], prefix: Int)? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var addressPart = trimmed
        var prefix = 128
        if let slash = trimmed.firstIndex(of: "/") {
            addressPart = String(trimmed[..<slash])
            guard let value = Int(trimmed[trimmed.index(after: slash)...]), (0...128).contains(value) else { return nil }
            prefix = value
        }
        guard let bytes = parseAddress(addressPart) else { return nil }
        return (bytes, prefix)
    }

    static func parseAddress(_ string: String) -> [UInt8]? {
        guard !string.isEmpty else { return nil }
        let doubleColonParts = string.components(separatedBy: "::")
        guard doubleColonParts.count <= 2 else { return nil }
        let hasDouble = doubleColonParts.count == 2

        func hextets(_ part: String) -> [UInt16]? {
            guard !part.isEmpty else { return [] }
            var out: [UInt16] = []
            for token in part.split(separator: ":", omittingEmptySubsequences: false) {
                guard !token.isEmpty, token.count <= 4, let value = UInt16(token, radix: 16) else { return nil }
                out.append(value)
            }
            return out
        }

        var groups: [UInt16]
        if hasDouble {
            guard let left = hextets(doubleColonParts[0]), let right = hextets(doubleColonParts[1]) else { return nil }
            let missing = 8 - left.count - right.count
            guard missing >= 1 else { return nil }
            groups = left + Array(repeating: 0, count: missing) + right
        } else {
            guard let all = hextets(string), all.count == 8 else { return nil }
            groups = all
        }
        guard groups.count == 8 else { return nil }
        return groups.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    }

    /// Applies the prefix mask. `fill` is what host bits become (0 or 0xFF).
    static func applyMask(_ bytes: [UInt8], prefix: Int, fill: UInt8) -> [UInt8] {
        var out = bytes
        for index in 0..<16 {
            let bitStart = index * 8
            if bitStart >= prefix {
                out[index] = fill
            } else if bitStart + 8 > prefix {
                let bitsInPrefix = prefix - bitStart          // 1…7
                let mask = UInt8((0xFF << (8 - bitsInPrefix)) & 0xFF)
                out[index] = fill == 0 ? (bytes[index] & mask) : (bytes[index] | ~mask)
            }
        }
        return out
    }

    static func expand(_ bytes: [UInt8]) -> String {
        stride(from: 0, to: 16, by: 2)
            .map { String(format: "%04x", (UInt16(bytes[$0]) << 8) | UInt16(bytes[$0 + 1])) }
            .joined(separator: ":")
    }

    /// RFC 5952 compression: longest zero run → "::", lowercase, no leading zeros.
    static func compress(_ bytes: [UInt8]) -> String {
        let groups = stride(from: 0, to: 16, by: 2).map { (UInt16(bytes[$0]) << 8) | UInt16(bytes[$0 + 1]) }
        var bestStart = -1, bestLen = 0
        var runStart = -1, runLen = 0
        for (index, value) in groups.enumerated() {
            if value == 0 {
                if runStart == -1 { runStart = index; runLen = 1 } else { runLen += 1 }
                if runLen > bestLen { bestLen = runLen; bestStart = runStart }
            } else {
                runStart = -1; runLen = 0
            }
        }
        if bestLen < 2 { return groups.map { String($0, radix: 16) }.joined(separator: ":") }
        let head = groups[0..<bestStart].map { String($0, radix: 16) }.joined(separator: ":")
        let tail = groups[(bestStart + bestLen)...].map { String($0, radix: 16) }.joined(separator: ":")
        return "\(head)::\(tail)"
    }

    static func classify(_ bytes: [UInt8]) -> String {
        if bytes.allSatisfy({ $0 == 0 }) { return "Unspecified" }
        if bytes[0..<15].allSatisfy({ $0 == 0 }), bytes[15] == 1 { return "Loopback" }
        let b0 = bytes[0]
        if b0 == 0xFF { return "Multicast" }
        if b0 == 0xFE, (bytes[1] & 0xC0) == 0x80 { return "Link-Local" }
        if (b0 & 0xFE) == 0xFC { return "Unique Local (ULA)" }
        if (b0 & 0xE0) == 0x20 { return "Global Unicast" }
        return "Reserved / Other"
    }

    static func calculate(_ input: String) -> IPv6SubnetResult? {
        guard let (bytes, prefix) = parse(input) else { return nil }
        let network = applyMask(bytes, prefix: prefix, fill: 0)
        let last = applyMask(network, prefix: prefix, fill: 0xFF)
        let exponent = 128 - prefix
        let count: String = exponent == 0 ? "1" : (exponent <= 20 ? String(1 << exponent) : "2^\(exponent)")
        return IPv6SubnetResult(
            networkCompressed: compress(network),
            networkExpanded: expand(network),
            prefixLength: prefix,
            firstAddress: compress(network),
            lastAddress: compress(last),
            addressCount: count,
            kind: classify(network)
        )
    }
}

// MARK: - Tool

struct IPv6SubnetTool: NetworkTool {
    let id = "ipv6-subnet"
    let titleKey = L10n("tool.ipv6.title")
    let subtitleKey = L10n("tool.ipv6.subtitle")
    let systemImage = "6.circle"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(IPv6SubnetView()) }
}

// MARK: - View

@MainActor
struct IPv6SubnetView: View {
    @Environment(\.theme) private var theme
    @State private var input = "2001:db8::1/64"

    private var result: IPv6SubnetResult? { IPv6Engine.calculate(input) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let result {
                    resultSection(result)
                } else if !input.trimmingCharacters(in: .whitespaces).isEmpty {
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(L10n("ipv6.error")).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ipv6.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ipv6.input.title"), systemImage: "number") {
            TextField(L10nString("ipv6.input.placeholder"), text: $input)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func resultSection(_ result: IPv6SubnetResult) -> some View {
        SectionCard(title: L10n("ipv6.section.result"), systemImage: "checkmark.seal") {
            HStack {
                StatusBadge(kind: .info, text: L10n("ipv6.kind"))
                Text(result.kind).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("/\(result.prefixLength)")
                    .font(AppTypography.monoBody).foregroundStyle(theme.accent)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Divider().overlay(theme.separator)
            labeledCopy(L10n("ipv6.network"), result.networkCompressed)
            labeledCopy(L10n("ipv6.expanded"), result.networkExpanded)
            labeledCopy(L10n("ipv6.first"), result.firstAddress)
            labeledCopy(L10n("ipv6.last"), result.lastAddress)
            ResultRow(label: L10n("ipv6.count"), value: result.addressCount)
        }
    }

    private func labeledCopy(_ label: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            CopyableValue(value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteSection: some View {
        Text(L10n("ipv6.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
