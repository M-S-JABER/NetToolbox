import SwiftUI
import Observation

/// One DNS blacklist zone result.
struct RBLResult: Identifiable, Equatable, Sendable {
    let zone: String
    let listed: Bool
    var id: String { zone }
}

/// DNS-based blacklist (DNSBL/RBL) checks. The query builder is pure and
/// unit-tested; lookups reuse the UDP DNS resolver.
enum RBL {
    /// The well-known public blacklist zones queried by the tool.
    static let zones = [
        "zen.spamhaus.org",
        "bl.spamcop.net",
        "b.barracudacentral.org",
        "dnsbl.sorbs.net",
        "cbl.abuseat.org",
        "dnsbl-1.uceprotect.net",
    ]

    /// Builds the DNSBL query name: reversed IP + "." + zone.
    static func query(ip: String, zone: String) -> String? {
        let parts = ip.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        return parts.reversed().joined(separator: ".") + "." + zone
    }
}

@MainActor
@Observable
final class RBLCheckViewModel {
    var ip = ""
    private(set) var results: [RBLResult] = []
    private(set) var isChecking = false
    private(set) var errorMessage: String?

    private let resolver: any DNSResolving

    init(resolver: any DNSResolving = UDPDNSResolver()) {
        self.resolver = resolver
    }

    var listedCount: Int { results.filter(\.listed).count }

    func check() async {
        let target = ip.trimmingCharacters(in: .whitespaces)
        guard RBL.query(ip: target, zone: RBL.zones[0]) != nil else {
            errorMessage = String(localized: "error.probe.invalidHost", bundle: .module)
            return
        }
        errorMessage = nil
        isChecking = true
        results = []

        for zone in RBL.zones {
            guard isChecking, let query = RBL.query(ip: target, zone: zone) else { continue }
            let records = (try? await resolver.resolve(name: query, type: .a, server: "1.1.1.1")) ?? []
            results.append(RBLResult(zone: zone, listed: !records.isEmpty))
        }
        isChecking = false
    }
}

struct RBLCheckTool: NetworkTool {
    let id = "rbl-check"
    let titleKey = L10n("tool.rbl.title")
    let subtitleKey = L10n("tool.rbl.subtitle")
    let systemImage = "hand.raised.slash"
    let category: ToolCategory = .security

    func makeView() -> AnyView { AnyView(RBLCheckView()) }
}

@MainActor
struct RBLCheckView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = RBLCheckViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.results.isEmpty || viewModel.isChecking {
                    resultsSection
                }
                Text(L10n("rbl.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.rbl.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("rbl.input.title"), systemImage: "hand.raised.slash") {
            HStack(spacing: Spacing.sm) {
                TextField("8.8.8.8", text: $viewModel.ip)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.check() } }
                SavedHostMenu(host: $viewModel.ip)
            }

            Button {
                Task { await viewModel.check() }
            } label: {
                Label(L10nString("rbl.action.check"), systemImage: "magnifyingglass.circle.fill")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isChecking)

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("rbl.section.result"), systemImage: "list.bullet.rectangle") {
            HStack {
                StatusBadge(
                    kind: viewModel.listedCount == 0 ? .success : .danger,
                    text: viewModel.listedCount == 0 ? L10n("rbl.clean") : L10n("rbl.listed")
                )
                Spacer()
                if viewModel.isChecking { ProgressView() }
            }
            Divider().overlay(theme.separator)
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.results) { result in
                    HStack {
                        Image(systemName: result.listed ? "xmark.octagon.fill" : "checkmark.circle")
                            .foregroundStyle(result.listed ? theme.danger : theme.success)
                        Text(result.zone)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        Text(result.listed ? L10nString("rbl.listedShort") : L10nString("rbl.cleanShort"))
                            .font(AppTypography.caption)
                            .foregroundStyle(result.listed ? theme.danger : theme.textSecondary)
                    }
                }
            }
        }
    }
}
