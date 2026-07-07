import SwiftUI
import Observation
#if canImport(Darwin)
import Darwin
#endif

/// A host found alive during a range scan.
struct HostResult: Identifiable, Equatable, Sendable {
    let ip: String
    let rttMs: Double
    var id: String { ip }
}

enum IPRangeError: LocalizedError, Equatable {
    case invalidRange
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRange: String(localized: "error.range.invalid", bundle: .module)
        case .tooLarge(let max): String(localized: "error.range.tooLarge", bundle: .module) + " (\(max))"
        }
    }
}

/// Enumerates the hosts of a CIDR and pings each over ICMP to find live
/// hosts. Uses the unprivileged `SOCK_DGRAM`/`IPPROTO_ICMP` socket, so no
/// entitlement is needed — but scanning the local subnet still triggers
/// the iOS Local Network permission.
enum IPRangeScanner {
    static let maxHosts = 1024

    /// Expands a CIDR into its list of host addresses (dotted quads).
    static func hosts(cidr: String) throws -> [String] {
        let result = try SubnetEngine.calculateIPv4(
            address: cidr, mask: cidr.contains("/") ? "" : "24"
        )
        let network = try SubnetEngine.parseIPv4(result.networkAddress)
        let total = result.totalAddressCount
        guard total <= UInt64(maxHosts) else { throw IPRangeError.tooLarge(maxHosts) }

        let start: UInt64
        let end: UInt64
        switch result.prefix {
        case 32:
            start = UInt64(network); end = UInt64(network)
        case 31:
            start = UInt64(network); end = UInt64(network) + 1
        default:
            start = UInt64(network) + 1
            end = UInt64(network) + total - 2   // exclude network & broadcast
        }
        guard start <= end else { throw IPRangeError.invalidRange }
        return (start...end).map { SubnetEngine.format(ipv4: UInt32($0)) }
    }
}

/// Pings a single IPv4 host over ICMP.
enum ICMPHostPinger {
    static func probe(ip: String, timeout: Double) async -> Double? {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(blockingPing(ip: ip, timeout: timeout))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingPing(ip: String, timeout: Double) -> Double? {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        guard ip.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else { return nil }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let packet = ICMP.echoRequest(identifier: UInt16(getpid() & 0xFFFF), sequence: 1)
        let clock = ContinuousClock()
        let start = clock.now

        let sent = packet.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(fd, buffer.baseAddress, buffer.count, 0,
                           sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }

        var responseBuffer = [UInt8](repeating: 0, count: 512)
        let received = recvfrom(fd, &responseBuffer, responseBuffer.count, 0, nil, nil)
        guard received > 0, (responseBuffer.first ?? 0xFF) == ICMP.echoReplyType else { return nil }

        let elapsed = start.duration(to: clock.now)
        return Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
    }
    #else
    private static func blockingPing(ip: String, timeout: Double) -> Double? { nil }
    #endif
}

@MainActor
@Observable
final class IPRangeScannerViewModel {
    var cidr = "192.168.1.0/24"
    private(set) var results: [HostResult] = []
    private(set) var scanned = 0
    private(set) var total = 0
    private(set) var isScanning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isScanning else { return }
            if isScanning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var errorMessage: String?
    private(set) var history: [String] = []
    var activity: ActivityCenter?
    var toolID = ""

    func scan() async {
        errorMessage = nil
        let hosts: [String]
        do {
            hosts = try IPRangeScanner.hosts(cidr: cidr)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        results = []
        scanned = 0
        total = hosts.count
        isScanning = true

        await withTaskGroup(of: HostResult?.self) { group in
            let limiter = ConcurrencyLimiter(limit: 24)
            for ip in hosts {
                group.addTask {
                    await limiter.acquire()
                    defer { Task { await limiter.release() } }
                    if let rtt = await ICMPHostPinger.probe(ip: ip, timeout: 1) {
                        return HostResult(ip: ip, rttMs: rtt)
                    }
                    return nil
                }
            }
            for await result in group {
                scanned += 1
                if let result {
                    results.append(result)
                    results.sort { Self.value($0.ip) < Self.value($1.ip) }
                }
                if !isScanning { break }
            }
        }
        isScanning = false
        history.insert("\(cidr) — \(results.count) up / \(total)", at: 0)
        if history.count > 10 { history.removeLast() }
    }

    func stop() { isScanning = false }

    private static func value(_ ip: String) -> UInt32 {
        (try? SubnetEngine.parseIPv4(ip)) ?? 0
    }
}

struct IPRangeScannerTool: NetworkTool {
    let id = "ip-range-scanner"
    let titleKey = L10n("tool.range.title")
    let subtitleKey = L10n("tool.range.subtitle")
    let systemImage = "list.bullet.below.rectangle"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(IPRangeScannerView()) }
}

@MainActor
struct IPRangeScannerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: IPRangeScannerViewModel {
        sessions.session("ip-range-scanner") {
            let model = IPRangeScannerViewModel()
            model.activity = activity
            model.toolID = "ip-range-scanner"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if viewModel.isScanning || viewModel.total > 0 {
                    progressSection
                }
                if !viewModel.results.isEmpty {
                    resultsSection
                }
                if !viewModel.history.isEmpty {
                    ToolHistorySection(entries: viewModel.history)
                }
                Text(L10n("range.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.range.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("range.input.title"), systemImage: "number") {
            TextField("192.168.1.0/24", text: $viewModel.cidr)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            HStack {
                Button {
                    Task { await viewModel.scan() }
                } label: {
                    Label(L10nString("range.action.scan"), systemImage: "dot.radiowaves.left.and.right")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)

                if viewModel.isScanning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var progressSection: some View {
        SectionCard(title: L10n("range.section.progress"), systemImage: "gauge") {
            HStack {
                if viewModel.isScanning { ProgressView() }
                Text("\(viewModel.scanned) / \(viewModel.total)")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                StatusBadge(
                    kind: .success,
                    text: LocalizedStringResource(stringLiteral: "\(viewModel.results.count) up")
                )
            }
            ProgressView(
                value: Double(viewModel.scanned),
                total: Double(max(viewModel.total, 1))
            )
            .tint(theme.accent)
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("range.section.hosts"), systemImage: "checkmark.circle") {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.results) { host in
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(theme.success)
                            .frame(width: 24)
                        CopyableValue(value: host.ip)
                        Spacer()
                        Text(String(format: "%.0f ms", host.rttMs))
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }
}
