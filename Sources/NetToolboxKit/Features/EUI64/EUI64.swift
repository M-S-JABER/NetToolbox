import SwiftUI
import Observation

/// Builds a modified EUI-64 interface identifier from a MAC address and the
/// resulting SLAAC IPv6 address under a given prefix. Pure logic (reuses the
/// tested `SubnetEngine` IPv6 codec).
enum EUI64 {
    /// The four 16-bit groups of the modified EUI-64 interface identifier.
    static func interfaceGroups(fromMAC mac: String) -> [UInt16]? {
        let hex = mac.filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex, let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) {
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        guard bytes.count == 6 else { return nil }
        bytes[0] ^= 0x02 // flip the universal/local bit
        let eui: [UInt8] = [bytes[0], bytes[1], bytes[2], 0xFF, 0xFE, bytes[3], bytes[4], bytes[5]]
        return stride(from: 0, to: 8, by: 2).map { UInt16(eui[$0]) << 8 | UInt16(eui[$0 + 1]) }
    }

    static func interfaceID(fromMAC mac: String) -> String? {
        interfaceGroups(fromMAC: mac).map { $0.map { String(format: "%04x", $0) }.joined(separator: ":") }
    }

    static func slaac(prefix: String, mac: String) -> String? {
        guard let iface = interfaceGroups(fromMAC: mac) else { return nil }
        let cleaned = prefix.split(separator: "/").first.map(String.init) ?? prefix
        let base = cleaned.trimmingCharacters(in: .whitespaces)
        guard let groups = try? SubnetEngine.parseIPv6(base.isEmpty ? "::" : base) else { return nil }
        let full = Array(groups.prefix(4)) + iface
        return SubnetEngine.compressed(ipv6: full)
    }
}

@MainActor
@Observable
final class EUI64ViewModel {
    var mac = ""
    var prefix = "fe80::/64"

    var interfaceID: String? { EUI64.interfaceID(fromMAC: mac) }
    var address: String? { EUI64.slaac(prefix: prefix, mac: mac) }
}

struct EUI64Tool: NetworkTool {
    let id = "eui64"
    let titleKey = L10n("tool.eui64.title")
    let subtitleKey = L10n("tool.eui64.subtitle")
    let systemImage = "number.square"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(EUI64View()) }
}

@MainActor
struct EUI64View: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = EUI64ViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("eui64.input.title"), systemImage: "number.square") {
                    TextField(L10nString("eui64.input.mac"), text: $viewModel.mac)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField(L10nString("eui64.input.prefix"), text: $viewModel.prefix)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                }
                if let interfaceID = viewModel.interfaceID {
                    SectionCard(title: L10n("eui64.section.result"), systemImage: "checkmark.seal") {
                        labeled(L10n("eui64.interfaceID"), interfaceID)
                        if let address = viewModel.address {
                            Divider().overlay(theme.separator)
                            labeled(L10n("eui64.address"), address)
                        }
                    }
                } else if !viewModel.mac.isEmpty {
                    Text(L10n("eui64.invalid")).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                Text(L10n("eui64.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.eui64.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private func labeled(_ label: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            CopyableValue(value: value)
        }
    }
}
