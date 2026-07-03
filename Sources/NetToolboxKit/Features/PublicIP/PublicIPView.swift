import SwiftUI

/// Public IP + ISP details with the device's local interface addresses.
struct PublicIPView: View {
    @Environment(\.theme) private var theme

    @State private var viewModel = PublicIPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                publicSection
                localSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.publicip.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.state == .loading)
                .accessibilityLabel(Text(L10n("common.refresh")))
            }
        }
    }

    // MARK: Public IP

    @ViewBuilder
    private var publicSection: some View {
        SectionCard(title: L10n("publicip.section.public"), systemImage: "globe") {
            switch viewModel.state {
            case .idle, .loading:
                HStack(spacing: Spacing.md) {
                    ProgressView()
                    Text(L10n("common.loading"))
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Spacing.lg)

            case .failure(let message):
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        StatusBadge(kind: .danger, text: L10n("publicip.error.title"))
                        Text(message)
                            .font(AppTypography.body)
                            .foregroundStyle(theme.danger)
                    }
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label(L10nString("common.retry"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

            case .loaded(let info):
                HStack {
                    CopyableValue(value: info.ip, font: AppTypography.monoLarge)
                    Spacer()
                    StatusBadge(kind: .success, text: L10n("publicip.badge.online"))
                }
                Divider().overlay(theme.separator)
                VStack(spacing: Spacing.sm) {
                    if let country = info.country {
                        ResultRow(
                            label: L10n("publicip.result.country"),
                            value: info.countryCode.map { "\(country) (\($0))" } ?? country,
                            isMonospaced: false
                        )
                    }
                    if let city = info.city {
                        ResultRow(label: L10n("publicip.result.city"), value: city, isMonospaced: false)
                    }
                    if let isp = info.isp {
                        ResultRow(label: L10n("publicip.result.isp"), value: isp, isMonospaced: false)
                    }
                    if let org = info.organization {
                        ResultRow(label: L10n("publicip.result.org"), value: org, isMonospaced: false)
                    }
                    if let asn = info.asn {
                        ResultRow(label: L10n("publicip.result.asn"), value: "AS\(asn)")
                    }
                    if let timezone = info.timezone {
                        ResultRow(label: L10n("publicip.result.timezone"), value: timezone, isMonospaced: false)
                    }
                }
            }
        }
    }

    // MARK: Local addresses

    private var localSection: some View {
        SectionCard(title: L10n("publicip.section.local"), systemImage: "ipad.landscape") {
            if viewModel.localAddresses.isEmpty {
                Text(L10n("publicip.local.empty"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.localAddresses) { entry in
                        HStack {
                            Text(entry.interface)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                            StatusBadge(
                                kind: entry.isIPv6 ? .neutral : .info,
                                text: entry.isIPv6 ? "IPv6" : "IPv4"
                            )
                            Spacer()
                            CopyableValue(value: entry.address)
                        }
                    }
                }
            }
        }
    }
}
