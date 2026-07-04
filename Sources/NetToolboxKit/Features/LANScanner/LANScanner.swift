import SwiftUI
import Observation
import Network

/// A Bonjour service discovered on the local network.
struct DiscoveredService: Identifiable, Equatable, Sendable {
    let name: String
    let type: String
    let domain: String
    var txt: [String: String] = [:]
    var host: String? = nil
    var port: UInt16? = nil

    var id: String { "\(name)|\(type)" }

    /// Resolved "host:port", once background resolution completes.
    var address: String? {
        guard let host, let port else { return nil }
        return "\(host):\(port)"
    }

    /// Friendly label + SF Symbol for a Bonjour service type.
    var friendly: (label: String, symbol: String) {
        switch type {
        case "_http._tcp": ("Web service", "globe")
        case "_https._tcp": ("Secure web", "lock.globe")
        case "_ssh._tcp": ("SSH", "terminal")
        case "_smb._tcp": ("File sharing", "folder")
        case "_afpovertcp._tcp": ("Apple file share", "folder")
        case "_airplay._tcp", "_raop._tcp": ("AirPlay", "airplayvideo")
        case "_ipp._tcp", "_printer._tcp", "_pdl-datastream._tcp": ("Printer", "printer")
        case "_googlecast._tcp": ("Chromecast", "tv")
        case "_rfb._tcp": ("Screen sharing", "display")
        case "_device-info._tcp": ("Device", "desktopcomputer")
        case "_homekit._tcp", "_hap._tcp": ("HomeKit", "homekit")
        default: (type, "dot.radiowaves.right")
        }
    }
}

/// Discovers Bonjour services with `NWBrowser`. Requires the host app to
/// declare the Local Network usage description and the browsed Bonjour
/// service types; without them iOS simply returns no results.
@MainActor
@Observable
final class LANScannerViewModel {
    private(set) var services: [DiscoveredService] = []
    private(set) var isScanning = false

    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "net.lan.browse")

    private let serviceTypes = [
        "_http._tcp", "_https._tcp", "_ssh._tcp", "_smb._tcp",
        "_airplay._tcp", "_raop._tcp", "_ipp._tcp", "_printer._tcp",
        "_googlecast._tcp", "_rfb._tcp", "_device-info._tcp", "_homekit._tcp",
    ]

    func start() {
        stop()
        services = []
        isScanning = true

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        for type in serviceTypes {
            let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                let found = results.compactMap { Self.service(from: $0) }
                Task { @MainActor in self?.merge(found) }
            }
            browser.start(queue: queue)
            browsers.append(browser)
        }

        // Auto-stop after a short discovery window.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            if isScanning { stop() }
        }
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        isScanning = false
    }

    private func merge(_ found: [DiscoveredService]) {
        // Dedupe by id (name+type): a re-reported service must not duplicate
        // one we have already resolved (whose host/port now differ).
        for service in found where !services.contains(where: { $0.id == service.id }) {
            services.append(service)
            resolve(service)
        }
        services.sort { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Resolves a discovered service to a concrete host + port in the
    /// background, then fills it into the matching row.
    private func resolve(_ service: DiscoveredService) {
        let name = service.name, type = service.type, domain = service.domain
        Task { [weak self] in
            guard let resolved = await Self.resolveEndpoint(name: name, type: type, domain: domain) else { return }
            await MainActor.run {
                guard let self, let index = self.services.firstIndex(where: { $0.id == "\(name)|\(type)" }) else { return }
                self.services[index].host = resolved.host
                self.services[index].port = resolved.port
            }
        }
    }

    private nonisolated static func resolveEndpoint(
        name: String, type: String, domain: String
    ) async -> (host: String, port: UInt16)? {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
            let connection = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "net.lan.resolve")
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let remote = connection.currentPath?.remoteEndpoint,
                       case let .hostPort(host, port) = remote {
                        connection.cancel()
                        shot.resume((hostString(host), port.rawValue))
                    } else {
                        connection.cancel()
                        shot.resume(nil)
                    }
                case .failed, .cancelled:
                    connection.cancel()
                    shot.resume(nil)
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 4) {
                connection.cancel()
                shot.resume(nil)
            }
        }
    }

    private nonisolated static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address): return "\(address)"
        case .ipv6(let address): return "\(address)"
        case .name(let name, _): return name
        @unknown default: return "?"
        }
    }

    private nonisolated static func service(from result: NWBrowser.Result) -> DiscoveredService? {
        guard case let .service(name, type, domain, _) = result.endpoint else { return nil }
        var txt: [String: String] = [:]
        if case let .bonjour(record) = result.metadata {
            txt = record.dictionary
        }
        return DiscoveredService(name: name, type: type, domain: domain, txt: txt)
    }
}

struct LANScannerTool: NetworkTool {
    let id = "lan-scanner"
    let titleKey = L10n("tool.lan.title")
    let subtitleKey = L10n("tool.lan.subtitle")
    let systemImage = "rectangle.connected.to.line.below"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(LANScannerView()) }
}

struct LANScannerView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = LANScannerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                controlSection
                if !viewModel.services.isEmpty {
                    resultsSection
                } else if !viewModel.isScanning {
                    emptyHint
                }
                Text(L10n("lan.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.lan.title")))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { viewModel.stop() }
    }

    private var controlSection: some View {
        SectionCard(title: L10n("lan.section.discover"), systemImage: "rectangle.connected.to.line.below") {
            HStack {
                if viewModel.isScanning {
                    ProgressView()
                    Text(L10n("lan.scanning"))
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                } else {
                    Button {
                        viewModel.start()
                    } label: {
                        Label(L10nString("lan.action.scan"), systemImage: "dot.radiowaves.left.and.right")
                            .font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if !viewModel.services.isEmpty {
                        Text("\(viewModel.services.count)")
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("lan.section.found"), systemImage: "list.bullet") {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.services) { service in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: service.friendly.symbol)
                            .foregroundStyle(theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(service.name)
                                .font(AppTypography.body)
                                .foregroundStyle(theme.textPrimary)
                            Text(service.friendly.label)
                                .font(AppTypography.caption)
                                .foregroundStyle(theme.textSecondary)
                            if let address = service.address {
                                Text(address)
                                    .font(AppTypography.monoCaption)
                                    .foregroundStyle(theme.mono)
                                    .textSelection(.enabled)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        Spacer()
                        if let host = service.host {
                            Button {
                                savedHosts.add(name: service.name, address: host, notes: service.type)
                            } label: {
                                Image(systemName: "bookmark")
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(L10n("hosts.saveCurrent")))
                        } else {
                            Text(service.type)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    if !service.txt.isEmpty {
                        ForEach(service.txt.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack(spacing: Spacing.xs) {
                                Text("\(key)=\(value)")
                                    .font(AppTypography.monoCaption)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                                    .environment(\.layoutDirection, .leftToRight)
                                Spacer()
                            }
                            .padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    private var emptyHint: some View {
        SectionCard(title: L10n("lan.section.permission"), systemImage: "lock.shield") {
            Text(L10n("lan.permission"))
                .font(AppTypography.body)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
