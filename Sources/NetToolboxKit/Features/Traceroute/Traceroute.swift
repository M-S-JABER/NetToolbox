import SwiftUI
import Observation
#if canImport(Darwin)
import Darwin
#endif

/// One traceroute hop.
struct TracerouteHop: Identifiable, Equatable, Sendable {
    let ttl: Int
    /// Responding router address, or nil on timeout.
    let address: String?
    let rttMs: Double?
    /// True when this hop is the final destination (echo reply).
    let reached: Bool

    var id: Int { ttl }
}

/// Probes a single TTL and reports the responding hop.
protocol TracerouteProbing: Sendable {
    func probe(host: String, ttl: Int, timeout: Double) async -> TracerouteHop
}

/// Traceroute over an unprivileged `SOCK_DGRAM`/`IPPROTO_ICMP` socket — the
/// same socket type Apple's SimplePing uses, so no entitlement is needed.
/// Intermediate routers answer with ICMP Time Exceeded; the destination
/// answers with an Echo Reply.
struct ICMPTraceroute: TracerouteProbing {
    func probe(host: String, ttl: Int, timeout: Double) async -> TracerouteHop {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(Self.blockingProbe(host: host, ttl: ttl, timeout: timeout))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingProbe(host: String, ttl: Int, timeout: Double) -> TracerouteHop {
        func fail() -> TracerouteHop {
            TracerouteHop(ttl: ttl, address: nil, rttMs: nil, reached: false)
        }

        // Resolve the target to an IPv4 address.
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_DGRAM,
            ai_protocol: IPPROTO_ICMP, ai_addrlen: 0,
            ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var infoPointer: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &infoPointer) == 0,
              let info = infoPointer,
              let addr = info.pointee.ai_addr else {
            if infoPointer != nil { freeaddrinfo(infoPointer) }
            return fail()
        }
        var target = sockaddr_in()
        memcpy(&target, addr, Int(MemoryLayout<sockaddr_in>.size))
        freeaddrinfo(infoPointer)

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else { return fail() }
        defer { close(fd) }

        var ttlValue = Int32(ttl)
        _ = setsockopt(fd, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let packet = ICMP.echoRequest(identifier: UInt16(getpid() & 0xFFFF), sequence: UInt16(ttl))
        let clock = ContinuousClock()
        let start = clock.now

        let sent = packet.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &target) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(fd, buffer.baseAddress, buffer.count, 0,
                           sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return fail() }

        var responseBuffer = [UInt8](repeating: 0, count: 512)
        var source = sockaddr_in()
        var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let received = withUnsafeMutablePointer(to: &source) { sourcePointer -> Int in
            sourcePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                recvfrom(fd, &responseBuffer, responseBuffer.count, 0, sockaddrPointer, &sourceLength)
            }
        }
        guard received > 0 else { return fail() }

        let elapsed = start.duration(to: clock.now)
        let ms = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000

        var addressBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &source.sin_addr, &addressBuffer, socklen_t(INET_ADDRSTRLEN))
        let address = String(cBuffer: addressBuffer)

        // On a DGRAM ICMP socket echo replies arrive with the IP header
        // stripped, but Time Exceeded errors are sometimes delivered *with*
        // the 20-byte IPv4 header still attached. Detect that (first nibble
        // == 4) and skip past it so we read the real ICMP type either way.
        var icmpOffset = 0
        if let first = responseBuffer.first, (first >> 4) == 4 {
            icmpOffset = Int(first & 0x0F) * 4
        }
        let type = received > icmpOffset ? responseBuffer[icmpOffset] : 0xFF
        // Reaching the destination = an echo reply; a router en route sends
        // Time Exceeded (or, on the last hop of some hosts, Dest Unreachable).
        let reached = type == ICMP.echoReplyType
        return TracerouteHop(ttl: ttl, address: address, rttMs: ms, reached: reached)
    }
    #else
    private static func blockingProbe(host: String, ttl: Int, timeout: Double) -> TracerouteHop {
        TracerouteHop(ttl: ttl, address: nil, rttMs: nil, reached: false)
    }
    #endif
}

@MainActor
@Observable
final class TracerouteViewModel {
    var host = ""
    var maxHopsText = "20"
    var timeoutText = "2"    // per-hop timeout (s)
    var retryText = "1"      // probes per hop
    private(set) var hops: [TracerouteHop] = []
    private(set) var isRunning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isRunning else { return }
            if isRunning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var errorMessage: String?
    /// Set when ICMP found nothing but a TCP probe still reached the host —
    /// gives a real hop-distance + RTT when routers can't be named.
    private(set) var tcpSummary: TCPTraceProbe.Result?
    private(set) var history: [String] = []
    var activity: ActivityCenter?
    var toolID = ""

    private let prober: any TracerouteProbing

    init(prober: any TracerouteProbing = ICMPTraceroute()) {
        self.prober = prober
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        let maxHops = max(1, min(64, Int(maxHopsText) ?? 20))
        let timeout = max(0.3, Double(timeoutText) ?? 2)
        let retries = max(1, min(5, Int(retryText) ?? 1))
        let prober = self.prober

        isRunning = true
        errorMessage = nil
        tcpSummary = nil
        hops = []

        // Probe every TTL at once instead of walking them one-by-one: a
        // sequential walk stalls the whole trace on each silent router (up
        // to `timeout` per hop). Fanning out keeps the total time close to a
        // single hop's timeout, and results stream in as routers answer.
        // Each hop is retried up to `retries` times until a router answers.
        var collected: [Int: TracerouteHop] = [:]
        await withTaskGroup(of: TracerouteHop.self) { group in
            for ttl in 1...maxHops {
                group.addTask {
                    var last = TracerouteHop(ttl: ttl, address: nil, rttMs: nil, reached: false)
                    for _ in 0..<retries {
                        last = await prober.probe(host: target, ttl: ttl, timeout: timeout)
                        if last.address != nil { break }
                    }
                    return last
                }
            }
            for await hop in group {
                collected[hop.ttl] = hop
                publish(collected, maxHops: maxHops)
                if !isRunning { group.cancelAll() }
            }
        }

        let reached = hops.contains { $0.reached }
        // On iOS the unprivileged ICMP datagram socket never receives the
        // intermediate routers' "Time Exceeded" messages, so a normal trace can
        // only ever name the destination itself — every router in between shows
        // as `*`. Whenever no intermediate router was named (the common case),
        // fall back to a TCP reach test so the user still gets a real result:
        // hop-distance + RTT to the host. (Previously this was gated behind
        // `!reached`, so a host that answered ping produced only a column of
        // `*` and no summary at all — which read as "traceroute doesn't work".)
        let namedRouter = hops.contains { $0.address != nil && !$0.reached }
        if isRunning, !namedRouter {
            tcpSummary = await TCPTraceProbe.trace(host: target, maxHops: maxHops, timeout: timeout)
            if tcpSummary == nil, !reached {
                errorMessage = L10nString("traceroute.error.noResponse")
            }
        }

        isRunning = false
        history.insert("\(target) — \(hops.count) hops\(reached ? " ✓" : "")", at: 0)
        if history.count > 10 { history.removeLast() }
    }

    /// Rebuilds the ordered hop list from whatever has come back so far,
    /// filling gaps with timeouts and trimming everything past the hop that
    /// reached the destination.
    private func publish(_ collected: [Int: TracerouteHop], maxHops: Int) {
        let reachedTTL = collected.values.filter(\.reached).map(\.ttl).min()
        let limit = reachedTTL ?? maxHops
        hops = (1...limit).map { ttl in
            collected[ttl] ?? TracerouteHop(ttl: ttl, address: nil, rttMs: nil, reached: false)
        }
    }

    func stop() { isRunning = false }
}

struct TracerouteTool: NetworkTool {
    let id = "traceroute"
    let titleKey = L10n("tool.traceroute.title")
    let subtitleKey = L10n("tool.traceroute.subtitle")
    let systemImage = "arrow.triangle.turn.up.right.diamond"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(TracerouteView()) }
}

@MainActor
struct TracerouteView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: TracerouteViewModel {
        sessions.session("traceroute") {
            let model = TracerouteViewModel()
            model.activity = activity
            model.toolID = "traceroute"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                optionsSection
                if let tcp = viewModel.tcpSummary {
                    tcpSummarySection(tcp)
                }
                if !viewModel.hops.isEmpty {
                    hopsSection
                }
                if !viewModel.history.isEmpty {
                    ToolHistorySection(entries: viewModel.history)
                }
                Text(L10n("traceroute.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.traceroute.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("traceroute.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("traceroute.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("traceroute.action.start"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                    ProgressView()
                }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func tcpSummarySection(_ result: TCPTraceProbe.Result) -> some View {
        SectionCard(title: L10n("traceroute.tcp.title"), systemImage: "checkmark.seal") {
            HStack(spacing: Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n("traceroute.tcp.reachable"))
                        .font(AppTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text("TCP :\(String(result.port))")
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
            }
            Divider().overlay(theme.separator)
            ResultRow(label: L10n("traceroute.tcp.hops"), value: "\(result.hops)")
            ResultRow(label: L10n("traceroute.tcp.rtt"), value: String(format: "%.0f ms", result.rttMs))
            Text(L10n("traceroute.tcp.note"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var optionsSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("ping.section.options"), systemImage: "slider.horizontal.3") {
            optionRow(L10n("traceroute.opt.timeout"), text: $viewModel.timeoutText)
            optionRow(L10n("traceroute.opt.retry"), text: $viewModel.retryText)
            optionRow(L10n("traceroute.opt.maxHops"), text: $viewModel.maxHopsText)
        }
    }

    private func optionRow(_ label: LocalizedStringResource, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .environment(\.layoutDirection, .leftToRight)
                .disabled(viewModel.isRunning)
        }
    }

    private var hopsSection: some View {
        SectionCard(title: L10n("traceroute.section.hops"), systemImage: "list.number") {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.hops) { hop in
                    HStack(spacing: Spacing.md) {
                        Text(String(format: "%2d", hop.ttl))
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        if let address = hop.address {
                            Text(address)
                                .font(AppTypography.monoBody)
                                .foregroundStyle(hop.reached ? theme.success : theme.mono)
                                .environment(\.layoutDirection, .leftToRight)
                        } else {
                            Text("*")
                                .font(AppTypography.monoBody)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        if let ms = hop.rttMs {
                            Text(String(format: "%.1f ms", ms))
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        if hop.reached {
                            StatusBadge(kind: .success, text: L10n("traceroute.reached"))
                        }
                    }
                }
            }
        }
    }
}
