import SwiftUI
import Observation

/// A public DoH resolver to query in the comparison.
struct DNSResolverEndpoint: Identifiable, Sendable {
    let id: String
    let name: String
    let host: String
}

/// One resolver's answer for the queried name/type.
struct DNSCompareRow: Identifiable, Sendable {
    let id: String
    let resolver: String
    let values: [String]
    let error: String?
}

/// Queries several public DNS-over-HTTPS resolvers for the same record and
/// compares their answers — useful to spot propagation lag or divergent
/// (poisoned / filtered) responses. Reuses the shared `DoHResolver`.
@MainActor
@Observable
final class DNSCompareViewModel {
    static let resolvers: [DNSResolverEndpoint] = [
        DNSResolverEndpoint(id: "cloudflare", name: "Cloudflare", host: "cloudflare-dns.com"),
        DNSResolverEndpoint(id: "google", name: "Google", host: "dns.google"),
        DNSResolverEndpoint(id: "quad9", name: "Quad9", host: "dns.quad9.net"),
        DNSResolverEndpoint(id: "adguard", name: "AdGuard", host: "dns.adguard-dns.com"),
    ]

    var name = ""
    var type: DNSRecordType = .a
    private(set) var rows: [DNSCompareRow] = []
    private(set) var agreement: Bool?
    private(set) var isRunning = false

    func run() async {
        let target = name.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        let recordType = type
        let resolver = DoHResolver()

        isRunning = true
        rows = []
        agreement = nil

        var collected: [DNSCompareRow] = []
        await withTaskGroup(of: DNSCompareRow.self) { group in
            for endpoint in Self.resolvers {
                group.addTask {
                    do {
                        let records = try await resolver.resolve(name: target, type: recordType, server: endpoint.host)
                        let values = records.filter { $0.type == recordType }.map { $0.value }.sorted()
                        return DNSCompareRow(id: endpoint.id, resolver: endpoint.name, values: values, error: nil)
                    } catch {
                        return DNSCompareRow(id: endpoint.id, resolver: endpoint.name, values: [], error: error.localizedDescription)
                    }
                }
            }
            for await row in group { collected.append(row) }
        }

        let order = Self.resolvers.map(\.id)
        collected.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        rows = collected

        let answered = collected.filter { $0.error == nil && !$0.values.isEmpty }.map(\.values)
        if answered.count > 1 {
            agreement = answered.dropFirst().allSatisfy { $0 == answered.first }
        }
        isRunning = false
    }
}

struct DNSCompareTool: NetworkTool {
    let id = "dns-compare"
    let titleKey = L10n("tool.dnscompare.title")
    let subtitleKey = L10n("tool.dnscompare.subtitle")
    let systemImage = "arrow.left.arrow.right"
    let category: ToolCategory = .dns

    func makeView() -> AnyView { AnyView(DNSCompareView()) }
}

@MainActor
struct DNSCompareView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = DNSCompareViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.rows.isEmpty {
                    if let agreement = viewModel.agreement {
                        agreementBadge(agreement)
                    }
                    resultsSection
                }
                Text(L10n("dnscompare.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.dnscompare.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("dnscompare.input.title"), systemImage: "arrow.left.arrow.right") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("dns.input.name"), text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.name)
            }

            Picker(L10nString("dns.input.type"), selection: $viewModel.type) {
                ForEach(DNSRecordType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("dnscompare.action.run"), systemImage: "arrow.left.arrow.right")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
                if viewModel.isRunning { ProgressView() }
            }
        }
    }

    private func agreementBadge(_ agree: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: agree ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(agree ? theme.success : theme.warning)
            Text(agree ? L10n("dnscompare.agree") : L10n("dnscompare.disagree"))
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill((agree ? theme.success : theme.warning).opacity(0.12))
        )
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("dnscompare.section.results"), systemImage: "list.bullet.rectangle") {
            ForEach(viewModel.rows) { row in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(row.resolver)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .environment(\.layoutDirection, .leftToRight)
                    if let error = row.error {
                        Text(error).font(AppTypography.footnote).foregroundStyle(theme.danger)
                    } else if row.values.isEmpty {
                        Text(L10n("dnscompare.empty")).font(AppTypography.footnote).foregroundStyle(theme.textSecondary)
                    } else {
                        ForEach(row.values, id: \.self) { value in
                            Text(value)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textPrimary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if row.id != viewModel.rows.last?.id {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }
}
