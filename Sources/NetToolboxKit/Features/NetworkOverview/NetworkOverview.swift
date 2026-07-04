import SwiftUI
import Observation

@MainActor
@Observable
final class NetworkOverviewViewModel {
    enum PublicState: Equatable {
        case idle, loading
        case loaded(PublicIPInfo)
        case failure(String)
    }

    private(set) var localAddresses: [LocalInterfaceAddress] = []
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
        localAddresses = localProvider.addresses()
        publicState = .loading
        do {
            publicState = .loaded(try await publicService.fetch())
        } catch {
            publicState = .failure(error.localizedDescription)
        }
    }
}

struct NetworkOverviewTool: NetworkTool {
    let id = "network-overview"
    let titleKey = L10n("tool.overview.title")
    let subtitleKey = L10n("tool.overview.subtitle")
    let systemImage = "chart.bar.doc.horizontal"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(NetworkOverviewView()) }
}

struct NetworkOverviewView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @State private var viewModel = NetworkOverviewViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionCard
                publicCard
                localCard
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.overview.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { if case .idle = viewModel.publicState { await viewModel.refresh() } }
        .refreshable { await viewModel.refresh() }
    }

    private var connectionCard: some View {
        SectionCard(title: L10n("overview.section.connection"), systemImage: "wifi") {
            HStack(spacing: Spacing.md) {
                Image(systemName: status.connection.symbol)
                    .font(.title)
                    .foregroundStyle(status.connection.isOnline ? theme.success : theme.danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n(status.connection.labelKey))
                        .font(AppTypography.title)
                        .foregroundStyle(theme.textPrimary)
                    if status.isExpensive {
                        Text(L10n("status.metered"))
                            .font(AppTypography.caption)
                            .foregroundStyle(theme.warning)
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var publicCard: some View {
        SectionCard(title: L10n("overview.section.public"), systemImage: "globe") {
            switch viewModel.publicState {
            case .idle, .loading:
                HStack(spacing: Spacing.md) {
                    ProgressView()
                    Text(L10n("common.loading")).foregroundStyle(theme.textSecondary)
                }
            case .failure(let message):
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            case .loaded(let info):
                HStack {
                    CopyableValue(value: info.ip, font: AppTypography.monoLarge)
                    Spacer()
                }
                if let isp = info.isp {
                    ResultRow(label: L10n("publicip.result.isp"), value: isp, isMonospaced: false)
                }
                if let country = info.country {
                    ResultRow(
                        label: L10n("publicip.result.country"),
                        value: info.countryCode.map { "\(country) (\($0))" } ?? country,
                        isMonospaced: false
                    )
                }
            }
        }
    }

    private var localCard: some View {
        SectionCard(title: L10n("overview.section.local"), systemImage: "ipad.landscape") {
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
                            StatusBadge(kind: entry.isIPv6 ? .neutral : .info, text: entry.isIPv6 ? "IPv6" : "IPv4")
                            Spacer()
                            CopyableValue(value: entry.address)
                        }
                    }
                }
            }
        }
    }
}
