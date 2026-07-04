import SwiftUI
import Observation

@MainActor
@Observable
final class WiFiInfoViewModel {
    enum PublicState: Equatable {
        case idle, loading
        case loaded(PublicIPInfo)
        case failure
    }

    private(set) var wifiAddresses: [LocalInterfaceAddress] = []
    private(set) var gateway: String?
    private(set) var publicState: PublicState = .idle

    private let localProvider: any LocalIPProviding
    private let publicService: any PublicIPProviding

    init(
        localProvider: any LocalIPProviding = SystemLocalIPProvider(),
        publicService: any PublicIPProviding = IpwhoisService()
    ) {
        self.localProvider = localProvider
        self.publicService = publicService
    }

    func refresh() async {
        // The Wi-Fi interface on iOS is en0; fall back to all IPv4 if absent.
        let all = localProvider.addresses()
        let enZero = all.filter { $0.interface == "en0" && !$0.isIPv6 }
        wifiAddresses = enZero.isEmpty ? all.filter { !$0.isIPv6 } : enZero
        gateway = RouteInfo.defaultGatewayIPv4()

        publicState = .loading
        do {
            publicState = .loaded(try await publicService.fetch())
        } catch {
            publicState = .failure
        }
    }
}

struct WiFiInfoTool: NetworkTool {
    let id = "wifi-info"
    let titleKey = L10n("tool.wifiinfo.title")
    let subtitleKey = L10n("tool.wifiinfo.subtitle")
    let systemImage = "wifi"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(WiFiInfoView()) }
}

struct WiFiInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @State private var viewModel = WiFiInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                availableCard
                limitationsCard
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.wifiinfo.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { if case .idle = viewModel.publicState { await viewModel.refresh() } }
        .refreshable { await viewModel.refresh() }
    }

    private var availableCard: some View {
        SectionCard(title: L10n("wifiinfo.section.available"), systemImage: "checkmark.seal") {
            HStack(spacing: Spacing.md) {
                Image(systemName: status.connection.symbol)
                    .font(.title2)
                    .foregroundStyle(status.connection.isOnline ? theme.success : theme.danger)
                Text(L10n(status.connection.labelKey))
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            Divider().overlay(theme.separator)

            ForEach(viewModel.wifiAddresses) { address in
                ResultRow(label: L10n("wifiinfo.deviceIP"), value: address.address)
            }
            if let gateway = viewModel.gateway {
                ResultRow(label: L10n("wifiinfo.gateway"), value: gateway)
            } else {
                ResultRow(label: L10n("wifiinfo.gateway"), value: "—")
            }

            switch viewModel.publicState {
            case .idle, .loading:
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(L10n("common.loading")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                }
            case .failure:
                EmptyView()
            case .loaded(let info):
                ResultRow(label: L10n("wifiinfo.publicIP"), value: info.ip)
                if let isp = info.isp {
                    ResultRow(label: L10n("publicip.result.isp"), value: isp, isMonospaced: false)
                }
            }
        }
    }

    private var limitationsCard: some View {
        SectionCard(title: L10n("wifiinfo.section.unavailable"), systemImage: "lock.slash") {
            Text(L10n("wifiinfo.unavailable.intro"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Spacing.sm) {
                unavailableRow("wifiinfo.metric.signal")
                unavailableRow("wifiinfo.metric.channel")
                unavailableRow("wifiinfo.metric.band")
                unavailableRow("wifiinfo.metric.generation")
                unavailableRow("wifiinfo.metric.linkSpeed")
                unavailableRow("wifiinfo.metric.ssid")
            }
        }
    }

    private func unavailableRow(_ key: String) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Text(L10n(key))
                .font(AppTypography.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(L10n("wifiinfo.notAvailable"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.warning)
        }
    }
}
