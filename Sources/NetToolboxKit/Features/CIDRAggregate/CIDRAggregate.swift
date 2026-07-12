import SwiftUI
import Observation

/// Merges a list of IPv4 addresses / CIDRs into the minimal set of CIDR blocks
/// that covers exactly the same addresses. Pure logic (UInt64 math to avoid
/// 32-bit overflow at the extremes).
enum CIDRAggregate {
    static func aggregate(_ input: String) -> [String] {
        var ranges: [(UInt64, UInt64)] = []
        for token in input.split(whereSeparator: { $0.isNewline || $0 == "," || $0 == " " || $0 == "\t" }) {
            let line = token.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, let range = parse(line) else { continue }
            ranges.append(range)
        }
        guard !ranges.isEmpty else { return [] }
        ranges.sort { $0.0 < $1.0 }

        var merged: [(UInt64, UInt64)] = []
        for range in ranges {
            if let last = merged.last, range.0 <= last.1 + 1 {
                merged[merged.count - 1].1 = max(last.1, range.1)
            } else {
                merged.append(range)
            }
        }

        return merged.flatMap { rangeToCIDRs($0.0, $0.1) }
    }

    static func parse(_ line: String) -> (UInt64, UInt64)? {
        let parts = line.split(separator: "/")
        guard let first = parts.first, let ip = try? SubnetEngine.parseIPv4(String(first)) else { return nil }
        // A garbage prefix ("10.0.0.0/xyz") is a malformed line, not a /32 —
        // reject it instead of silently widening to a host route.
        let prefix: Int
        if parts.count > 1 {
            guard let parsed = Int(parts[1]) else { return nil }
            prefix = parsed
        } else {
            prefix = 32
        }
        guard (0...32).contains(prefix) else { return nil }
        let mask: UInt64 = prefix == 0 ? 0 : (~UInt64(0) << (32 - prefix)) & 0xFFFF_FFFF
        let network = UInt64(ip) & mask
        let size = UInt64(1) << (32 - prefix)
        return (network, network + size - 1)
    }

    static func rangeToCIDRs(_ start: UInt64, _ end: UInt64) -> [String] {
        var out: [String] = []
        var s = start
        while s <= end {
            let alignPrefix = 32 - min(s == 0 ? 32 : s.trailingZeroBitCount, 32)
            let remaining = end - s + 1
            let fitPrefix = 32 - (63 - remaining.leadingZeroBitCount)
            let prefix = max(alignPrefix, fitPrefix)
            out.append("\(ipString(UInt32(truncatingIfNeeded: s)))/\(prefix)")
            s += UInt64(1) << (32 - prefix)
        }
        return out
    }

    static func ipString(_ value: UInt32) -> String {
        "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
    }
}

@MainActor
@Observable
final class CIDRAggregateViewModel {
    var input = ""
    var result: [String] { CIDRAggregate.aggregate(input) }
}

struct CIDRAggregateTool: NetworkTool {
    let id = "cidr-aggregate"
    let titleKey = L10n("tool.cidragg.title")
    let subtitleKey = L10n("tool.cidragg.subtitle")
    let systemImage = "arrow.triangle.merge"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(CIDRAggregateView()) }
}

@MainActor
struct CIDRAggregateView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = CIDRAggregateViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("cidragg.input.title"), systemImage: "list.bullet") {
                    TextField(L10nString("cidragg.input.list"), text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                        .lineLimit(3...10)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                }
                if !viewModel.result.isEmpty {
                    SectionCard(title: L10n("cidragg.section.result"), systemImage: "arrow.triangle.merge") {
                        ForEach(viewModel.result, id: \.self) { cidr in
                            CopyableValue(value: cidr)
                        }
                        CopyButton(value: viewModel.result.joined(separator: "\n"))
                    }
                }
                Text(L10n("cidragg.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.cidragg.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
