import SwiftUI
import Observation
import Network
#if canImport(Darwin)
import Darwin
#endif

/// A Bonjour service discovered on the local network.
struct DiscoveredService: Identifiable, Equatable, Sendable {
    let name: String
    let type: String
    let domain: String
    var txt: [String: String] = [:]
    var host: String? = nil
    var port: UInt16? = nil

    var id: String { "\(name)|\(type)" }

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

/// A device on the local network, unified from every signal iOS allows: a
/// ping/TCP sweep of the subnet, Bonjour/mDNS advertisements, and reverse DNS.
struct LANDevice: Identifiable, Equatable, Sendable {
    let ip: String
    var name: String?
    var rttMs: Double?
    var services: [String] = []

    var id: String { ip }

    /// A stable icon: pick one from the services, else a generic host.
    var symbol: String {
        if services.contains("SSH") { return "terminal" }
        if services.contains("Printer") { return "printer" }
        if services.contains("AirPlay") || services.contains("Chromecast") { return "tv" }
        if services.contains(where: { $0.contains("web") || $0.contains("Web") }) { return "globe" }
        return "desktopcomputer"
    }
}

/// Merges the three discovery signals into one device list, keyed by IPv4.
/// Pure and unit-tested — the networking lives in the view model.
enum LANMerge {
    struct BonjourHit: Equatable, Sendable {
        let ip: String
        let name: String
        let serviceLabel: String
    }

    static func devices(
        swept: [HostResult],
        bonjour: [BonjourHit],
        reverseDNS: [String: String]
    ) -> [LANDevice] {
        var map: [String: LANDevice] = [:]
        func device(_ ip: String) -> LANDevice { map[ip] ?? LANDevice(ip: ip) }

        for host in swept {
            var entry = device(host.ip)
            entry.rttMs = host.rttMs
            map[host.ip] = entry
        }
        for hit in bonjour {
            var entry = device(hit.ip)
            if !hit.serviceLabel.isEmpty, !entry.services.contains(hit.serviceLabel) {
                entry.services.append(hit.serviceLabel)
            }
            if entry.name == nil, !hit.name.isEmpty { entry.name = hit.name }
            map[hit.ip] = entry
        }
        for (ip, host) in reverseDNS {
            var entry = device(ip)
            if entry.name == nil { entry.name = host }
            map[ip] = entry
        }
        return map.values.sorted { ipValue($0.ip) < ipValue($1.ip) }
    }

    static func ipValue(_ ip: String) -> UInt32 { (try? SubnetEngine.parseIPv4(ip)) ?? 0 }
}

/// Blocking DNS helpers (reverse PTR and forward A) used off the main actor.
enum LANDNS {
    #if canImport(Darwin)
    static func isIPv4(_ text: String) -> Bool {
        var addr = in_addr()
        return text.withCString { inet_pton(AF_INET, $0, &addr) } == 1
    }

    /// Reverse-DNS a dotted-quad to a hostname (nil when there's no PTR record).
    static func reverseName(ip: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        guard ip.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getnameinfo(sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size),
                            &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
            }
        }
        guard status == 0 else { return nil }
        let name = String(cString: host)
        return (name.isEmpty || name == ip) ? nil : name
    }

    /// Resolve a hostname (e.g. a Bonjour `.local` name) to its first IPv4.
    static func resolveIPv4(host: String) -> String? {
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM,
            ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0, let first = info else { return nil }
        defer { freeaddrinfo(info) }
        guard let addr = first.pointee.ai_addr else { return nil }
        var sin = sockaddr_in()
        memcpy(&sin, addr, Int(MemoryLayout<sockaddr_in>.size))
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &sin.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }
    #else
    static func isIPv4(_ text: String) -> Bool { false }
    static func reverseName(ip: String) -> String? { nil }
    static func resolveIPv4(host: String) -> String? { nil }
    #endif
}

/// Discovers everything reachable on the local network: it runs an ICMP+TCP
/// sweep of the device's subnet, browses Bonjour/mDNS, and reverse-DNS-names
/// the results, then merges them into one device list. Requires the host app's
/// Local Network usage description (Bonjour needs it; without permission the
/// sweep also returns nothing).
@MainActor
@Observable
final class LANScannerViewModel {
    private(set) var devices: [LANDevice] = []
    private(set) var isScanning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isScanning else { return }
            if isScanning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var showPermissionHint = false
    private(set) var history: [String] = []
    var activity: ActivityCenter?
    var toolID = ""

    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "net.lan.browse")
    private var bonjourRaw: [DiscoveredService] = []
    private var scanTask: Task<Void, Never>?

    private let serviceTypes = [
        "_http._tcp", "_https._tcp", "_ssh._tcp", "_smb._tcp", "_afpovertcp._tcp",
        "_airplay._tcp", "_raop._tcp", "_ipp._tcp", "_printer._tcp", "_pdl-datastream._tcp",
        "_googlecast._tcp", "_rfb._tcp", "_device-info._tcp", "_homekit._tcp", "_hap._tcp",
        "_workstation._tcp", "_companion-link._tcp", "_spotify-connect._tcp", "_scanner._tcp",
    ]

    func start() {
        stop()
        devices = []
        bonjourRaw = []
        showPermissionHint = false
        isScanning = true
        startBonjour()
        scanTask = Task { await runScan() }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        stopBrowsers()
        if isScanning {
            history.insert("\(devices.count) devices", at: 0)
            if history.count > 10 { history.removeLast() }
        }
        isScanning = false
    }

    private func stopBrowsers() {
        browsers.forEach { $0.cancel() }
        browsers = []
    }

    private func runScan() async {
        // 1. Sweep the device's own /24 (or whatever the interface reports).
        let cidr = LocalNetworkInfo.primaryIPv4CIDR() ?? "192.168.1.0/24"
        let hosts = (try? IPRangeScanner.hosts(cidr: cidr)) ?? []
        let swept = await Self.sweep(hosts)
        if Task.isCancelled { return }

        // 2. Give Bonjour a moment to finish resolving what it found in parallel.
        try? await Task.sleep(for: .seconds(2))
        if Task.isCancelled { return }

        // 3. Resolve Bonjour services to IPs and reverse-DNS every address.
        let bonjour = await Self.resolveBonjour(bonjourRaw)
        let addresses = swept.map(\.ip) + bonjour.map(\.ip)
        let reverse = await Self.reverseDNS(addresses)
        if Task.isCancelled { return }

        // 4. Merge and publish.
        devices = LANMerge.devices(swept: swept, bonjour: bonjour, reverseDNS: reverse)
        showPermissionHint = devices.isEmpty
        stopBrowsers()
        history.insert("\(devices.count) devices", at: 0)
        if history.count > 10 { history.removeLast() }
        isScanning = false
    }

    // MARK: - Bonjour collection

    private func startBonjour() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        for type in serviceTypes {
            let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                let found = results.compactMap { Self.service(from: $0) }
                Task { @MainActor [weak self] in self?.mergeBonjour(found) }
            }
            browser.start(queue: queue)
            browsers.append(browser)
        }
    }

    private func mergeBonjour(_ found: [DiscoveredService]) {
        for service in found where !bonjourRaw.contains(where: { $0.id == service.id }) {
            bonjourRaw.append(service)
            resolveBonjourHost(service)
        }
    }

    private func resolveBonjourHost(_ service: DiscoveredService) {
        let name = service.name, type = service.type, domain = service.domain
        Task { [weak self] in
            guard let resolved = await Self.resolveEndpoint(name: name, type: type, domain: domain) else { return }
            await MainActor.run {
                guard let self, let index = self.bonjourRaw.firstIndex(where: { $0.id == "\(name)|\(type)" }) else { return }
                self.bonjourRaw[index].host = resolved.host
                self.bonjourRaw[index].port = resolved.port
            }
        }
    }

    // MARK: - Off-actor discovery

    /// ICMP + TCP-connect sweep of the given hosts, concurrency-limited.
    private nonisolated static func sweep(_ hosts: [String]) async -> [HostResult] {
        var results: [HostResult] = []
        await withTaskGroup(of: HostResult?.self) { group in
            let limiter = ConcurrencyLimiter(limit: 24)
            for ip in hosts {
                group.addTask {
                    if Task.isCancelled { return nil }
                    await limiter.acquire()
                    defer { Task { await limiter.release() } }
                    async let icmp = ICMPHostPinger.probe(ip: ip, timeout: 0.9)
                    async let tcp = TCPHostProbe.probe(ip: ip, timeout: 0.9)
                    let (viaICMP, viaTCP) = await (icmp, tcp)
                    if let rtt = viaICMP ?? viaTCP { return HostResult(ip: ip, rttMs: rtt) }
                    return nil
                }
            }
            for await result in group { if let result { results.append(result) } }
        }
        return results
    }

    private nonisolated static func resolveBonjour(_ services: [DiscoveredService]) async -> [LANMerge.BonjourHit] {
        var hits: [LANMerge.BonjourHit] = []
        for service in services {
            guard let host = service.host else { continue }
            let ip = LANDNS.isIPv4(host) ? host : LANDNS.resolveIPv4(host: host)
            if let ip {
                hits.append(LANMerge.BonjourHit(ip: ip, name: service.name, serviceLabel: service.friendly.label))
            }
        }
        return hits
    }

    private nonisolated static func reverseDNS(_ ips: [String]) async -> [String: String] {
        let unique = Array(Set(ips))
        var map: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            for ip in unique { group.addTask { (ip, LANDNS.reverseName(ip: ip)) } }
            for await (ip, name) in group { if let name { map[ip] = name } }
        }
        return map
    }

    // MARK: - Bonjour endpoint resolution

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
        case .ipv4(let address): return "\(address)".components(separatedBy: "%").first ?? "\(address)"
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

@MainActor
struct LANScannerView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: LANScannerViewModel {
        sessions.session("lan-scanner") {
            let model = LANScannerViewModel()
            model.activity = activity
            model.toolID = "lan-scanner"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                controlSection
                if !viewModel.devices.isEmpty {
                    resultsSection
                } else if viewModel.showPermissionHint {
                    emptyHint
                }
                if !viewModel.history.isEmpty {
                    ToolHistorySection(entries: viewModel.history)
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
                    if !viewModel.devices.isEmpty {
                        Text("\(viewModel.devices.count)")
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("lan.section.devices"), systemImage: "list.bullet") {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.devices) { device in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: device.symbol)
                            .foregroundStyle(theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name ?? device.ip)
                                .font(AppTypography.body)
                                .foregroundStyle(theme.textPrimary)
                            if device.name != nil {
                                Text(device.ip)
                                    .font(AppTypography.monoCaption)
                                    .foregroundStyle(theme.mono)
                                    .textSelection(.enabled)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                            if !device.services.isEmpty {
                                Text(device.services.joined(separator: " · "))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if let rtt = device.rttMs {
                            Text(String(format: "%.0f ms", rtt))
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        Button {
                            savedHosts.add(name: device.name ?? device.ip, address: device.ip, notes: device.services.joined(separator: ", "))
                        } label: {
                            Image(systemName: "bookmark")
                                .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(L10n("hosts.saveCurrent")))
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
