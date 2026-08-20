import SwiftUI
import Observation

/// The exact name the user should give their Wi-Fi shortcut so the in-app
/// button can launch it via the `shortcuts://` URL scheme.
let wifiShortcutName = "NetToolbox WiFi"

/// The custom URL scheme the app registers (see `App/Info.plist`
/// `CFBundleURLTypes`). A Shortcut ends with an "Open URL" action targeting
/// `nettoolbox://wifi?ssid=…&bssid=…&ip=…`, which is how Wi-Fi details the app
/// itself cannot read (SSID/BSSID need the Access-WiFi-Information entitlement)
/// flow back in without any entitlement.
enum AppURLScheme {
    static let scheme = "nettoolbox"
    static let wifiHost = "wifi"
}

/// Holds the Wi-Fi details handed back by the Shortcut via the app's URL
/// scheme. Injected into the environment by `NetToolboxRootView` and filled by
/// its `onOpenURL` handler; `WiFiInfoView` reads it.
@MainActor
@Observable
final class WiFiShortcutInbox {
    private(set) var ssid: String?
    private(set) var bssid: String?
    private(set) var ip: String?
    private(set) var receivedAt: Date?

    var hasData: Bool { ssid != nil || bssid != nil || ip != nil }

    /// Parses `nettoolbox://wifi?ssid=…&bssid=…&ip=…`. Returns true when the URL
    /// was a Wi-Fi callback this inbox handled (so the caller can navigate to
    /// the Wi-Fi tool).
    @discardableResult
    func apply(_ url: URL) -> Bool {
        guard url.scheme == AppURLScheme.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == AppURLScheme.wifiHost else { return false }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            guard let raw = items.first(where: { $0.name == name })?.value else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        ssid = value("ssid") ?? ssid
        bssid = value("bssid") ?? bssid
        ip = value("ip") ?? ip
        receivedAt = Date()
        return true
    }

    func clear() {
        ssid = nil; bssid = nil; ip = nil; receivedAt = nil
    }
}

@MainActor
@Observable
final class WiFiInfoViewModel {
    enum PublicState: Equatable {
        case idle, loading
        case loaded(PublicIPInfo)
        case failure
    }

    private(set) var wifiAddresses: [LocalInterfaceAddress] = []
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
        // The Wi-Fi interface on iOS is en0; show its IPv4 *and* IPv6
        // addresses, falling back to every non-loopback interface if en0 is
        // absent (e.g. on cellular).
        let all = localProvider.addresses()
        let enZero = all.filter { $0.interface == "en0" }
        wifiAddresses = enZero.isEmpty ? all : enZero

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

@MainActor
struct WiFiInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(NetworkStatusMonitor.self) private var status
    @Environment(WiFiShortcutInbox.self) private var inbox
    @State private var viewModel = WiFiInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                availableCard
                if inbox.hasData { shortcutResultCard }
                shortcutCard
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
                ResultRow(
                    label: address.isIPv6 ? L10n("wifiinfo.deviceIPv6") : L10n("wifiinfo.deviceIP"),
                    value: address.address
                )
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

    /// Shows the Wi-Fi details a Shortcut handed back through the app's URL
    /// scheme — SSID/BSSID that the app itself cannot read without the
    /// Access-WiFi-Information entitlement.
    private var shortcutResultCard: some View {
        SectionCard(title: L10n("wifiinfo.section.fromShortcut"), systemImage: "checkmark.seal.fill") {
            if let ssid = inbox.ssid { ResultRow(label: L10n("wifiinfo.metric.ssid"), value: ssid, isMonospaced: false) }
            if let bssid = inbox.bssid { ResultRow(label: L10n("wifiinfo.metric.bssid"), value: bssid) }
            if let ip = inbox.ip { ResultRow(label: L10n("wifiinfo.deviceIP"), value: ip) }
            Button(role: .destructive) {
                inbox.clear()
            } label: {
                Label(L10nString("common.clear"), systemImage: "xmark.circle")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)
        }
    }

    private var shortcutCard: some View {
        SectionCard(title: L10n("wifiinfo.section.shortcut"), systemImage: "wand.and.stars") {
            Text(L10n("wifiinfo.shortcutHint"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.md) {
                Button {
                    runShortcut()
                } label: {
                    Label(L10nString("wifiinfo.runShortcut"), systemImage: "play.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openShortcutEditor()
                } label: {
                    Label(L10nString("wifiinfo.createShortcut"), systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
            }

            Text(verbatim: "\"\(wifiShortcutName)\"")
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.mono)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func runShortcut() {
        let encoded = wifiShortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? wifiShortcutName
        if let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") {
            openURL(url)
        }
    }

    private func openShortcutEditor() {
        if let url = URL(string: "shortcuts://create-shortcut") {
            openURL(url)
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
                unavailableRow("wifiinfo.gateway")
                unavailableRow("wifiinfo.routerVendor")
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
