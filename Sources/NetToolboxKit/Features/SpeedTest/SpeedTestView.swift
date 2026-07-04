import SwiftUI
import Observation

@MainActor
@Observable
final class SpeedTestViewModel {
    private(set) var phase: SpeedPhase = .idle
    private(set) var liveMbps: Double = 0
    private(set) var download: Double = 0
    private(set) var upload: Double = 0
    private(set) var latency: Double = 0
    private(set) var jitter: Double = 0
    private(set) var server: SpeedServerInfo?
    private(set) var errorMessage: String?

    var activity: ActivityCenter?
    var toolID = ""
    var history: SpeedHistoryStore?

    private let engine = CloudflareSpeedEngine()

    var isRunning: Bool {
        switch phase {
        case .latency, .download, .upload: return true
        default: return false
        }
    }

    var hasResults: Bool {
        download > 0 || upload > 0 || latency > 0
    }

    func run() async {
        reset()
        phase = .latency
        activity?.start(toolID)
        do {
            for try await update in engine.stream() {
                apply(update)
            }
        } catch {
            if case .failed = phase {} else {
                phase = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
        if phase == .finished, download > 0 || upload > 0 {
            history?.add(download: download, upload: upload, latency: latency, jitter: jitter)
        }
        activity?.stop(toolID)
    }

    private func apply(_ update: SpeedUpdate) {
        switch update {
        case .phase(let phase):
            self.phase = phase
            if case .failed(let message) = phase { errorMessage = message }
            if phase == .download || phase == .upload { liveMbps = 0 }
        case .server(let info):
            server = info
        case .latency(let ms, let jitterValue):
            latency = ms
            jitter = jitterValue
        case .liveDownload(let mbps), .liveUpload(let mbps):
            liveMbps = max(0, mbps)
        case .finalDownload(let mbps):
            download = mbps
            liveMbps = mbps
        case .finalUpload(let mbps):
            upload = mbps
            liveMbps = mbps
        }
    }

    private func reset() {
        liveMbps = 0
        download = 0
        upload = 0
        latency = 0
        jitter = 0
        errorMessage = nil
    }
}

struct SpeedTestTool: NetworkTool {
    let id = "speed-test"
    let titleKey = L10n("tool.speed.title")
    let subtitleKey = L10n("tool.speed.subtitle")
    let systemImage = "speedometer"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(SpeedTestView()) }
}

struct SpeedTestView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity
    @Environment(SpeedHistoryStore.self) private var history

    private var viewModel: SpeedTestViewModel {
        sessions.session("speed-test") {
            let model = SpeedTestViewModel()
            model.activity = activity
            model.toolID = "speed-test"
            model.history = history
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                gaugeCard
                metricsCard
                if let server = viewModel.server, !server.isp.isEmpty || !server.ip.isEmpty {
                    serverCard(server)
                }
                if !history.records.isEmpty {
                    historyCard
                }
                Text(L10n("speed.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.speed.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Gauge

    private var gaugeCard: some View {
        SectionCard(title: gaugeTitle, systemImage: gaugeIcon) {
            VStack(spacing: Spacing.md) {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                    Text(displayValue)
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.isRunning ? theme.accent : theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayValue)
                    Text(L10n("speed.unit.mbps"))
                        .font(AppTypography.title)
                        .foregroundStyle(theme.textSecondary)
                }

                phaseLabel

                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(
                        L10nString(viewModel.hasResults ? "speed.action.restart" : "speed.action.start"),
                        systemImage: viewModel.isRunning ? "hourglass" : "play.fill"
                    )
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var displayValue: String {
        let value = viewModel.isRunning ? viewModel.liveMbps : max(viewModel.download, viewModel.liveMbps)
        if !viewModel.isRunning, !viewModel.hasResults { return "—" }
        return String(format: "%.1f", value)
    }

    private var gaugeTitle: LocalizedStringResource {
        switch viewModel.phase {
        case .upload: return L10n("speed.metric.upload")
        default: return L10n("speed.metric.download")
        }
    }

    private var gaugeIcon: String {
        viewModel.phase == .upload ? "arrow.up.circle" : "arrow.down.circle"
    }

    @ViewBuilder
    private var phaseLabel: some View {
        switch viewModel.phase {
        case .latency:
            phaseText(L10n("speed.phase.latency"), showSpinner: true)
        case .download:
            phaseText(L10n("speed.phase.download"), showSpinner: true)
        case .upload:
            phaseText(L10n("speed.phase.upload"), showSpinner: true)
        case .failed:
            Text(viewModel.errorMessage ?? L10nString("common.error"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.danger)
                .multilineTextAlignment(.center)
        case .finished:
            Text(L10n("speed.phase.finished"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.success)
        case .idle:
            EmptyView()
        }
    }

    private func phaseText(_ text: LocalizedStringResource, showSpinner: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            if showSpinner { ProgressView() }
            Text(text)
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        SectionCard(title: L10n("speed.section.results"), systemImage: "chart.bar") {
            HStack(spacing: Spacing.md) {
                metricTile(L10n("speed.metric.download"), value: viewModel.download, unit: L10n("speed.unit.mbps"), icon: "arrow.down", tint: theme.accent)
                metricTile(L10n("speed.metric.upload"), value: viewModel.upload, unit: L10n("speed.unit.mbps"), icon: "arrow.up", tint: theme.mono)
            }
            HStack(spacing: Spacing.md) {
                metricTile(L10n("speed.metric.ping"), value: viewModel.latency, unit: L10n("speed.unit.ms"), icon: "timer", tint: theme.success)
                metricTile(L10n("speed.metric.jitter"), value: viewModel.jitter, unit: L10n("speed.unit.ms"), icon: "waveform.path", tint: theme.warning)
            }
        }
    }

    private func metricTile(_ label: LocalizedStringResource, value: Double, unit: LocalizedStringResource, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon).font(.caption).foregroundStyle(tint)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value > 0 ? String(format: "%.1f", value) : "—")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Text(unit)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - History

    private var historyCard: some View {
        SectionCard(title: L10n("speed.history.title"), systemImage: "clock.arrow.circlepath") {
            let chronological = history.records.reversed().map { $0.download }
            if chronological.count > 1 {
                Sparkline(values: Array(chronological), height: 56)
                    .environment(\.layoutDirection, .leftToRight)
            }
            ForEach(history.records.prefix(8)) { record in
                HStack(spacing: Spacing.md) {
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    historyValue("arrow.down", record.download, theme.accent)
                    historyValue("arrow.up", record.upload, theme.mono)
                    historyValue("timer", record.latency, theme.success)
                }
                if record.id != history.records.prefix(8).last?.id {
                    Divider().overlay(theme.separator)
                }
            }
            Button(role: .destructive) {
                history.clear()
            } label: {
                Label(L10nString("speed.history.clear"), systemImage: "trash")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)
        }
    }

    private func historyValue(_ icon: String, _ value: Double, _ tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(tint)
            Text(String(format: "%.0f", value))
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    // MARK: - Server

    private func serverCard(_ server: SpeedServerInfo) -> some View {
        SectionCard(title: L10n("speed.server.title"), systemImage: "server.rack") {
            if !server.isp.isEmpty { serverRow(L10n("speed.server.isp"), server.isp) }
            if !server.location.isEmpty { serverRow(L10n("speed.server.location"), server.location) }
            if !server.colo.isEmpty { serverRow(L10n("speed.server.node"), server.colo) }
            if !server.ip.isEmpty { serverRow(L10n("speed.server.ip"), server.ip) }
        }
    }

    private func serverRow(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
