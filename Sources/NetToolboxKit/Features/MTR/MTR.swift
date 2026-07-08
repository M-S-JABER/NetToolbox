import SwiftUI
import Observation

// MARK: - Model

/// Running per-hop statistics accumulated across MTR rounds.
struct MTRHop: Identifiable, Equatable, Sendable {
    let ttl: Int
    var address: String?
    var asn: String?
    var sent = 0
    var received = 0
    var last: Double?
    var best: Double?
    var worst: Double?
    var total = 0.0        // sum of received RTTs, for the average
    var reached = false

    var id: Int { ttl }
    var lossPercent: Double { sent == 0 ? 0 : Double(sent - received) / Double(sent) * 100 }
    var avg: Double? { received == 0 ? nil : total / Double(received) }
}

/// Pure aggregation of one probe into a hop's running stats — unit-tested.
enum MTREngine {
    static func record(_ hop: inout MTRHop, address: String?, rttMs: Double?, reached: Bool) {
        hop.sent += 1
        if let address { hop.address = address }
        if reached { hop.reached = true }
        if let rtt = rttMs {
            hop.received += 1
            hop.last = rtt
            hop.best = Swift.min(hop.best ?? rtt, rtt)
            hop.worst = Swift.max(hop.worst ?? rtt, rtt)
            hop.total += rtt
        } else {
            hop.last = nil
        }
    }

    /// Reverses an IPv4 address for a Team Cymru origin-ASN DNS query, or nil
    /// when the string is not a dotted-quad IPv4 address.
    static func cymruQuery(for address: String) -> String? {
        let octets = address.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets.allSatisfy({ UInt8($0) != nil }) else { return nil }
        return octets.reversed().joined(separator: ".") + ".origin.asn.cymru.com"
    }

    /// Extracts the AS number from a Team Cymru TXT answer
    /// (e.g. `"13335 | 104.16.0.0/12 | US | arin | ..."` → `"AS13335"`).
    static func parseASN(_ txt: String) -> String? {
        let first = txt.split(separator: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
        // The first field may hold multiple ASNs ("1234 5678"); take the first.
        guard let asn = first.split(separator: " ").first, !asn.isEmpty, asn.allSatisfy(\.isNumber) else { return nil }
        return "AS\(asn)"
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class MTRViewModel {
    var host = ""
    var maxHopsText = "20"
    var timeoutText = "1.5"
    var lookupASN = true

    private(set) var hops: [MTRHop] = []
    private(set) var rounds = 0
    private(set) var errorMessage: String?
    private(set) var isRunning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isRunning else { return }
            if isRunning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }

    var activity: ActivityCenter?
    var toolID = ""

    private let prober: any TracerouteProbing
    private let resolver: any DNSResolving
    private var asnByAddress: [String: String] = [:]

    init(prober: any TracerouteProbing = ICMPTraceroute(), resolver: any DNSResolving = UDPDNSResolver()) {
        self.prober = prober
        self.resolver = resolver
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { errorMessage = L10nString("mtr.error.host"); return }
        let maxHops = max(1, min(64, Int(maxHopsText) ?? 20))
        let timeout = max(0.3, Double(timeoutText.replacingOccurrences(of: ",", with: ".")) ?? 1.5)
        let prober = self.prober

        errorMessage = nil
        rounds = 0
        asnByAddress = [:]
        var stats: [Int: MTRHop] = [:]
        for ttl in 1...maxHops { stats[ttl] = MTRHop(ttl: ttl) }
        var lastHop = maxHops
        isRunning = true

        while isRunning {
            rounds += 1
            let results = await withTaskGroup(of: (Int, TracerouteHop).self) { group in
                for ttl in 1...lastHop {
                    group.addTask { (ttl, await prober.probe(host: target, ttl: ttl, timeout: timeout)) }
                }
                var out: [(Int, TracerouteHop)] = []
                for await result in group { out.append(result) }
                return out
            }
            guard isRunning else { break }

            for (ttl, hop) in results {
                MTREngine.record(&stats[ttl]!, address: hop.address, rttMs: hop.rttMs, reached: hop.reached)
            }
            if let reachedTTL = stats.values.filter(\.reached).map(\.ttl).min() {
                lastHop = reachedTTL
            }
            hops = (1...lastHop).map { ttl in
                var hop = stats[ttl]!
                if let address = hop.address { hop.asn = asnByAddress[address] }
                return hop
            }
            requestMissingASNs()

            try? await Task.sleep(for: .seconds(1))
        }
        isRunning = false
    }

    func stop() { isRunning = false }

    // MARK: - ASN enrichment

    private func requestMissingASNs() {
        guard lookupASN else { return }
        for hop in hops {
            guard let address = hop.address,
                  asnByAddress[address] == nil,
                  let query = MTREngine.cymruQuery(for: address) else { continue }
            asnByAddress[address] = ""   // mark in-flight so we ask once
            let resolver = self.resolver
            Task { [weak self] in
                let records = try? await resolver.resolve(name: query, type: .txt, server: "1.1.1.1")
                let asn = records?.first.map(\.value).flatMap(MTREngine.parseASN) ?? "—"
                self?.applyASN(asn, to: address)
            }
        }
    }

    private func applyASN(_ asn: String, to address: String) {
        asnByAddress[address] = asn
        for index in hops.indices where hops[index].address == address {
            hops[index].asn = asn
        }
    }
}

// MARK: - Tool

struct MTRTool: NetworkTool {
    let id = "mtr"
    let titleKey = L10n("tool.mtr.title")
    let subtitleKey = L10n("tool.mtr.subtitle")
    let systemImage = "point.topleft.down.to.point.bottomright.curvepath"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(MTRView()) }
}

// MARK: - View

@MainActor
struct MTRView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: MTRViewModel {
        sessions.session("mtr") {
            let model = MTRViewModel()
            model.activity = activity
            model.toolID = "mtr"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.hops.isEmpty {
                    hopsSection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.mtr.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("mtr.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("mtr.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.sm) {
                labeledField(L10n("mtr.opt.maxhops"), text: $viewModel.maxHopsText)
                labeledField(L10n("mtr.opt.timeout"), text: $viewModel.timeoutText)
                Spacer()
            }
            Toggle(isOn: $viewModel.lookupASN) {
                Label(L10nString("mtr.opt.asn"), systemImage: "number")
                    .font(AppTypography.body)
            }

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("mtr.action.start"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                    ProgressView()
                }
                Spacer()
                if viewModel.rounds > 0 {
                    Text(String(format: L10nString("mtr.rounds"), viewModel.rounds))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func labeledField(_ label: LocalizedStringResource, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 90)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var hopsSection: some View {
        SectionCard(title: L10n("mtr.section.hops"), systemImage: "list.number") {
            ForEach(viewModel.hops) { hop in
                hopRow(hop)
                if hop.id != viewModel.hops.last?.id {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }

    private func hopRow(_ hop: MTRHop) -> some View {
        let lossColor = hop.lossPercent == 0 ? theme.textSecondary
            : (hop.lossPercent < 50 ? theme.warning : theme.danger)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.sm) {
                Text("\(hop.ttl)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(minWidth: 22, alignment: .trailing)
                Text(hop.address ?? "* * *")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(hop.address == nil ? theme.textSecondary : theme.mono)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .environment(\.layoutDirection, .leftToRight)
                if hop.reached {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(theme.success).font(.caption)
                }
                Spacer()
                if let asn = hop.asn, !asn.isEmpty, asn != "—" {
                    Text(asn)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.accent)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            HStack(spacing: Spacing.md) {
                Text(String(format: L10nString("mtr.cell.loss"), hop.lossPercent))
                    .foregroundStyle(lossColor)
                metric(L10n("mtr.cell.last"), hop.last)
                metric(L10n("mtr.cell.avg"), hop.avg)
                metric(L10n("mtr.cell.best"), hop.best)
                metric(L10n("mtr.cell.worst"), hop.worst)
            }
            .font(AppTypography.monoCaption)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.vertical, 2)
    }

    private func metric(_ label: LocalizedStringResource, _ value: Double?) -> some View {
        HStack(spacing: 2) {
            Text(label).foregroundStyle(theme.textSecondary)
            Text(value.map { String(format: "%.0f", $0) } ?? "—").foregroundStyle(theme.textPrimary)
        }
    }

    private var noteSection: some View {
        Text(L10n("mtr.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
