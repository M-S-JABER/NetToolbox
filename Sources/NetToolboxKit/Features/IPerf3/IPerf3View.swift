import SwiftUI
import Observation

@MainActor
@Observable
final class IPerf3ViewModel {
    enum Direction: String, CaseIterable, Identifiable {
        case download, upload
        var id: String { rawValue }
        var reverse: Bool { self == .download }
        var labelKey: String { "iperf3.dir.\(rawValue)" }
    }

    enum Phase: Equatable {
        case idle, connecting
        case running(mbps: Double, seconds: Double)
        case finished(mbps: Double, bytes: Int, seconds: Double)
        case failed(String)
    }

    var host = ""
    var portText = "5201"
    var secondsText = "10"
    var direction: Direction = .download
    var parallelText = "1"
    private(set) var phase: Phase = .idle

    private var client: IPerf3Client?

    var isRunning: Bool {
        switch phase { case .connecting, .running: return true; default: return false }
    }

    func run() {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { phase = .failed(L10nString("iperf3.error.host")); return }
        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? 5201
        let seconds = max(1, min(60, Int(secondsText.trimmingCharacters(in: .whitespaces)) ?? 10))
        let parallel = max(1, min(16, Int(parallelText.trimmingCharacters(in: .whitespaces)) ?? 1))

        let config = IPerf3Client.Config(
            host: target, port: port, seconds: seconds,
            reverse: direction.reverse, parallel: parallel
        )
        let client = IPerf3Client(config: config)
        self.client = client
        phase = .connecting
        client.onEvent = { [weak self] event in
            Task { @MainActor in self?.apply(event) }
        }
        client.start()
    }

    func stop() {
        client?.cancel()
        client = nil
        if isRunning { phase = .idle }
    }

    private func apply(_ event: IPerf3Client.Event) {
        switch event {
        case .connecting: phase = .connecting
        case .running(let mbps, let seconds): phase = .running(mbps: mbps, seconds: seconds)
        case .finished(let mbps, let bytes, let seconds):
            phase = .finished(mbps: mbps, bytes: bytes, seconds: seconds)
            client = nil
        case .failed(let message):
            phase = .failed(message)
            client = nil
        }
    }
}

struct IPerf3Tool: NetworkTool {
    let id = "iperf3"
    let titleKey = L10n("tool.iperf3.title")
    let subtitleKey = L10n("tool.iperf3.subtitle")
    let systemImage = "speedometer"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(IPerf3View()) }
}

@MainActor
struct IPerf3View: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = IPerf3ViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                resultSection
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.iperf3.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("iperf3.input.title"), systemImage: "speedometer") {
            HStack(spacing: Spacing.sm) {
                Text(L10n("iperf3.v3.beta"))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(theme.background)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(theme.accent, in: Capsule())
                Text(L10n("iperf3.tcpOnly"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: Spacing.md) {
                TextField(L10nString("iperf3.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
                TextField("5201", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 74)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Picker(L10nString("iperf3.dir.title"), selection: $viewModel.direction) {
                ForEach(IPerf3ViewModel.Direction.allCases) { direction in
                    Text(L10n(direction.labelKey)).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n("iperf3.input.seconds"))
                        .font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                    TextField("10", text: $viewModel.secondsText)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numberPad)
                        .environment(\.layoutDirection, .leftToRight)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n("iperf3.input.parallel"))
                        .font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                    TextField("1", text: $viewModel.parallelText)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numberPad)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            if viewModel.isRunning {
                Button(role: .destructive) {
                    viewModel.stop()
                } label: {
                    Label(L10nString("iperf3.action.stop"), systemImage: "stop.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    viewModel.run()
                } label: {
                    Label(L10nString("iperf3.action.run"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.phase {
        case .idle:
            EmptyView()
        case .connecting:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("iperf3.connecting")).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .running(let mbps, let seconds):
            SectionCard(title: L10n("iperf3.section.live"), systemImage: "waveform.path.ecg") {
                throughputReadout(mbps: mbps)
                ProgressView(value: min(1, seconds / Double(max(1, Int(viewModel.secondsText) ?? 10))))
                    .tint(theme.accent)
                Text("\(seconds, specifier: "%.0f")s")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        case .finished(let mbps, let bytes, let seconds):
            SectionCard(title: L10n("iperf3.section.result"), systemImage: "checkmark.circle") {
                throughputReadout(mbps: mbps)
                ResultRow(label: L10n("iperf3.result.transferred"),
                          value: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary))
                ResultRow(label: L10n("iperf3.result.duration"),
                          value: String(format: "%.1f s", seconds))
                ResultRow(label: L10n("iperf3.result.direction"),
                          value: L10nString(viewModel.direction.labelKey))
            }
        case .failed(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        }
    }

    private func throughputReadout(mbps: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(String(format: "%.1f", mbps))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .environment(\.layoutDirection, .leftToRight)
            Text("Mbit/s")
                .font(AppTypography.headline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteSection: some View {
        Text(L10n("iperf3.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
