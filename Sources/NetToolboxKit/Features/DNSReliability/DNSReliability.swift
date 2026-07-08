import SwiftUI
import Observation

// MARK: - Model

/// One resolution attempt in a reliability run.
struct DNSProbe: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Double
    /// Round-trip in ms, or `nil` when the server did not respond (a drop).
    let latencyMs: Double?
    /// Resolved value on success, or the error on failure.
    let detail: String

    var ok: Bool { latencyMs != nil }
}

/// Aggregate reliability stats over a window of probes.
struct DNSReliabilitySummary: Equatable, Sendable {
    var total = 0
    var successes = 0
    var failures = 0
    var successRate = 0.0        // percent 0…100
    var minLatency: Double?
    var avgLatency: Double?
    var maxLatency: Double?
    var jitter: Double?          // mean |Δ| between consecutive successful latencies
    var dropEpisodes = 0         // number of separate failure runs
    var longestDropStreak = 0    // longest run of consecutive failures
    var slowCount = 0            // successful responses slower than the threshold
}

/// Pure statistics for the reliability monitor — unit-tested, no I/O.
enum DNSReliabilityEngine {
    static func summarize(_ probes: [DNSProbe], thresholdMs: Double? = nil) -> DNSReliabilitySummary {
        var summary = DNSReliabilitySummary()
        summary.total = probes.count
        guard summary.total > 0 else { return summary }

        let latencies = probes.compactMap(\.latencyMs)
        summary.successes = latencies.count
        summary.failures = summary.total - summary.successes
        summary.successRate = Double(summary.successes) / Double(summary.total) * 100

        if !latencies.isEmpty {
            summary.minLatency = latencies.min()
            summary.maxLatency = latencies.max()
            summary.avgLatency = latencies.reduce(0, +) / Double(latencies.count)
            if latencies.count > 1 {
                var deltaSum = 0.0
                for index in 1..<latencies.count {
                    deltaSum += abs(latencies[index] - latencies[index - 1])
                }
                summary.jitter = deltaSum / Double(latencies.count - 1)
            } else {
                summary.jitter = 0
            }
        }

        if let thresholdMs {
            summary.slowCount = latencies.filter { $0 > thresholdMs }.count
        }

        var episodes = 0, longest = 0, current = 0, inFailure = false
        for probe in probes {
            if probe.ok {
                inFailure = false
                current = 0
            } else {
                if !inFailure { episodes += 1; inFailure = true }
                current += 1
                longest = max(longest, current)
            }
        }
        summary.dropEpisodes = episodes
        summary.longestDropStreak = longest
        return summary
    }
}

private extension Duration {
    /// The duration in milliseconds.
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class DNSReliabilityViewModel {
    var host = ""
    var server = "1.1.1.1"
    var type: DNSRecordType = .a
    var intervalText = "1.0"
    /// Responses slower than this many ms count as "slow". Empty/0 disables it.
    var thresholdText = "200"

    private(set) var probes: [DNSProbe] = []
    private(set) var summary = DNSReliabilitySummary()
    private(set) var errorMessage: String?
    private(set) var isRunning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isRunning else { return }
            if isRunning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }

    var activity: ActivityCenter?
    var toolID = ""

    private let resolver: any DNSResolving
    private let maxProbes = 200

    init(resolver: any DNSResolving = UDPDNSResolver()) {
        self.resolver = resolver
    }

    /// Latency series for the sparkline; drops render as 0 (a dip to the floor).
    var latencySeries: [Double] { probes.map { $0.latencyMs ?? 0 } }

    /// Parsed slow-response threshold in ms, or nil when disabled.
    var threshold: Double? {
        let value = Double(thresholdText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }

    func run() async {
        guard !isRunning else { return }
        let name = host.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { errorMessage = L10nString("dnsrel.error.host"); return }

        let server = self.server.trimmingCharacters(in: .whitespaces)
        let interval = max(0.3, Double(intervalText.replacingOccurrences(of: ",", with: ".")) ?? 1.0)
        let type = self.type
        let resolver = self.resolver
        let threshold = self.threshold

        errorMessage = nil
        probes = []
        summary = DNSReliabilitySummary()
        isRunning = true

        let clock = ContinuousClock()
        while isRunning {
            let start = clock.now
            var latency: Double?
            var detail: String
            do {
                let records = try await resolver.resolve(name: name, type: type, server: server)
                latency = start.duration(to: clock.now).milliseconds
                detail = records.first?.value ?? L10nString("dnsrel.norecords")
            } catch {
                detail = error.localizedDescription
            }
            probes.append(DNSProbe(timestamp: Date().timeIntervalSince1970, latencyMs: latency, detail: detail))
            if probes.count > maxProbes { probes.removeFirst(probes.count - maxProbes) }
            summary = DNSReliabilityEngine.summarize(probes, thresholdMs: threshold)

            guard isRunning else { break }
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    func stop() { isRunning = false }

    func clear() {
        probes = []
        summary = DNSReliabilitySummary()
        errorMessage = nil
    }
}

// MARK: - Tool

struct DNSReliabilityTool: NetworkTool {
    let id = "dns-reliability"
    let titleKey = L10n("tool.dnsrel.title")
    let subtitleKey = L10n("tool.dnsrel.subtitle")
    let systemImage = "waveform.path.badge.minus"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(DNSReliabilityView()) }
}

// MARK: - View

@MainActor
struct DNSReliabilityView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    /// Retained across navigation so a running monitor keeps going.
    private var viewModel: DNSReliabilityViewModel {
        sessions.session("dns-reliability") {
            let model = DNSReliabilityViewModel()
            model.activity = activity
            model.toolID = "dns-reliability"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if viewModel.summary.total > 0 {
                    summarySection
                    if viewModel.probes.contains(where: { $0.latencyMs != nil }) {
                        chartSection
                    }
                    recentSection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.dnsrel.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("dnsrel.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("dnsrel.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }

            labeledField(L10n("dnsrel.opt.server"), text: $viewModel.server, wide: true)
            HStack(spacing: Spacing.sm) {
                labeledField(L10n("dnsrel.opt.interval"), text: $viewModel.intervalText, wide: false)
                labeledField(L10n("dnsrel.opt.threshold"), text: $viewModel.thresholdText, wide: false)
                Spacer()
            }

            Picker(L10nString("dnsrel.opt.type"), selection: $viewModel.type) {
                ForEach(DNSRecordType.allCases) { recordType in
                    Text(recordType.label).tag(recordType)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("dnsrel.action.start"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                    ProgressView()
                } else if viewModel.summary.total > 0 {
                    Button(L10nString("common.clear")) { viewModel.clear() }
                        .buttonStyle(.bordered)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func labeledField(_ label: LocalizedStringResource, text: Binding<String>, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(wide ? .URL : .decimalPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(maxWidth: wide ? .infinity : 90)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var summarySection: some View {
        let summary = viewModel.summary
        let hasDrops = summary.dropEpisodes > 0 || summary.successRate < 99
        let hasSlow = summary.slowCount > 0
        let kind: StatusBadge.Kind = hasDrops ? (summary.successRate >= 90 ? .warning : .danger)
            : (hasSlow ? .warning : .success)
        let statusKey = hasDrops ? "dnsrel.status.unstable" : (hasSlow ? "dnsrel.status.slow" : "dnsrel.status.stable")
        return SectionCard(title: L10n("dnsrel.section.summary"), systemImage: "chart.bar") {
            HStack {
                StatusBadge(kind: kind, text: L10n(statusKey))
                Spacer()
                Text(String(format: "%.1f%%", summary.successRate))
                    .font(AppTypography.monoLarge)
                    .foregroundStyle(kind == .success ? theme.success : (kind == .danger ? theme.danger : theme.warning))
                    .environment(\.layoutDirection, .leftToRight)
            }
            ResultRow(label: L10n("dnsrel.stat.samples"), value: "\(summary.successes)/\(summary.total)")
            ResultRow(label: L10n("dnsrel.stat.drops"), value: "\(summary.dropEpisodes)")
            ResultRow(label: L10n("dnsrel.stat.longest"), value: "\(summary.longestDropStreak)")
            if viewModel.threshold != nil {
                ResultRow(label: L10n("dnsrel.stat.slow"), value: "\(summary.slowCount)")
            }
            if let avg = summary.avgLatency {
                ResultRow(label: L10n("dnsrel.stat.latency"), value: latencyRange(summary))
                ResultRow(label: L10n("dnsrel.stat.avg"), value: String(format: "%.0f ms", avg))
            }
            if let jitter = summary.jitter {
                ResultRow(label: L10n("dnsrel.stat.jitter"), value: String(format: "%.0f ms", jitter))
            }
        }
    }

    private func latencyRange(_ summary: DNSReliabilitySummary) -> String {
        guard let lo = summary.minLatency, let hi = summary.maxLatency else { return "—" }
        return String(format: "%.0f–%.0f ms", lo, hi)
    }

    private var chartSection: some View {
        SectionCard(title: L10n("dnsrel.section.timeline"), systemImage: "waveform.path.ecg") {
            Sparkline(values: viewModel.latencySeries, height: 70)
            Text(L10n("dnsrel.timeline.note"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var recentSection: some View {
        SectionCard(title: L10n("dnsrel.section.recent"), systemImage: "list.bullet") {
            ForEach(viewModel.probes.suffix(12).reversed()) { probe in
                let isSlow = probe.ok && (viewModel.threshold.map { (probe.latencyMs ?? 0) > $0 } ?? false)
                HStack(spacing: Spacing.sm) {
                    Image(systemName: probe.ok ? (isSlow ? "clock.badge.exclamationmark" : "checkmark.circle.fill") : "xmark.octagon.fill")
                        .foregroundStyle(probe.ok ? (isSlow ? theme.warning : theme.success) : theme.danger)
                    Text(probe.detail)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.mono)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    Text(probe.latencyMs.map { String(format: "%.0f ms", $0) } ?? L10nString("dnsrel.drop"))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(probe.ok ? (isSlow ? theme.warning : theme.textSecondary) : theme.danger)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }

    private var noteSection: some View {
        Text(L10n("dnsrel.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
