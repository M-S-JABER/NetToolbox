import SwiftUI
import Observation

/// Pure IPv4 membership / range helpers built on `SubnetEngine`. Tested.
enum IPTools {
    /// Whether `ip` falls inside `cidr` (e.g. "10.0.0.5" in "10.0.0.0/24").
    static func contains(ip: String, cidr: String) -> Bool? {
        guard let value = try? SubnetEngine.parseIPv4(ip),
              let result = try? SubnetEngine.calculateIPv4(
                address: cidr, mask: cidr.contains("/") ? "" : "24"
              ),
              let network = try? SubnetEngine.parseIPv4(result.networkAddress) else {
            return nil
        }
        let mask = SubnetEngine.maskValue(forPrefix: result.prefix)
        return (value & mask) == (network & mask)
    }
}

@MainActor
@Observable
final class SubnetMembershipViewModel {
    enum Output: Equatable {
        case idle
        case result(inside: Bool, network: String, first: String, last: String, broadcast: String)
        case failure(String)
    }

    var ip = "192.168.1.50"
    var cidr = "192.168.1.0/24"
    private(set) var output: Output = .idle

    func check() {
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let trimmedCIDR = cidr.trimmingCharacters(in: .whitespaces)
        guard !trimmedIP.isEmpty, !trimmedCIDR.isEmpty else { output = .idle; return }

        do {
            let subnet = try SubnetEngine.calculateIPv4(
                address: trimmedCIDR, mask: trimmedCIDR.contains("/") ? "" : "24"
            )
            guard let inside = IPTools.contains(ip: trimmedIP, cidr: trimmedCIDR) else {
                output = .failure(String(localized: "error.subnet.invalidIPv4", bundle: .module))
                return
            }
            output = .result(
                inside: inside,
                network: subnet.cidrNotation,
                first: subnet.firstUsableHost,
                last: subnet.lastUsableHost,
                broadcast: subnet.broadcastAddress
            )
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct SubnetMembershipTool: NetworkTool {
    let id = "subnet-membership"
    let titleKey = L10n("tool.membership.title")
    let subtitleKey = L10n("tool.membership.subtitle")
    let systemImage = "arrow.down.right.and.arrow.up.left"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(SubnetMembershipView()) }
}

@MainActor
struct SubnetMembershipView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SubnetMembershipViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("membership.input.title"), systemImage: "arrow.down.right.and.arrow.up.left") {
                    TextField(L10nString("membership.ip"), text: $viewModel.ip)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField(L10nString("membership.cidr"), text: $viewModel.cidr)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        viewModel.check()
                    } label: {
                        Label(L10nString("common.calculate"), systemImage: "equal.circle.fill")
                            .font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }

                switch viewModel.output {
                case .idle:
                    EmptyView()
                case .failure(let message):
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                case .result(let inside, let network, let first, let last, let broadcast):
                    SectionCard(title: L10n("membership.section.result"), systemImage: "checkmark.circle") {
                        HStack {
                            StatusBadge(kind: inside ? .success : .danger,
                                        text: inside ? L10n("membership.inside") : L10n("membership.outside"))
                            Spacer()
                        }
                        Divider().overlay(theme.separator)
                        ResultRow(label: L10n("membership.network"), value: network)
                        ResultRow(label: L10n("subnet.result.firstHost"), value: first)
                        ResultRow(label: L10n("subnet.result.lastHost"), value: last)
                        ResultRow(label: L10n("subnet.result.broadcast"), value: broadcast)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.membership.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
