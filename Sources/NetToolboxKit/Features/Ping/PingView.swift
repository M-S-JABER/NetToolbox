import SwiftUI

struct PingTool: NetworkTool {
    let id = "ping"
    let titleKey = L10n("tool.ping.title")
    let subtitleKey = L10n("tool.ping.subtitle")
    let systemImage = "dot.radiowaves.left.and.right"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView {
        AnyView(PingView())
    }
}

/// TCP-ping screen: repeated handshake latency measurements to a host/port.
@MainActor
struct PingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    /// Retained across navigation so a running ping keeps going when you
    /// switch tools; its history lives here too.
    private var viewModel: PingViewModel {
        sessions.session("ping") {
            let model = PingViewModel()
            model.activity = activity
            model.toolID = "ping"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                optionsSection
                if let summary = viewModel.summary {
                    summarySection(summary)
                }
                if !viewModel.attempts.isEmpty {
                    attemptsSection
                }
                if !viewModel.history.isEmpty {
                    historySection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ping.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("ping.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("ping.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }

            if let ip = viewModel.resolvedIP {
                Text(ip)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("ping.action.start"), systemImage: "play.fill")
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
                Text(message)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.danger)
            }
        }
    }

    private var optionsSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("ping.section.options"), systemImage: "slider.horizontal.3") {
            Toggle(L10nString("ping.opt.continuous"), isOn: $viewModel.continuous)
                .disabled(viewModel.isRunning)
            optionRow(L10n("ping.opt.count"), text: $viewModel.countText, disabled: viewModel.continuous)
            optionRow(L10n("ping.opt.period"), text: $viewModel.intervalText)
            optionRow(L10n("ping.opt.timeout"), text: $viewModel.timeoutText)
            optionRow(L10n("ping.opt.payload"), text: $viewModel.payloadText)
            optionRow(L10n("ping.opt.ttl"), text: $viewModel.ttlText)
            Toggle(L10nString("ping.opt.ipv6"), isOn: $viewModel.preferIPv6)
                .disabled(viewModel.isRunning)
            optionRow(L10n("ping.opt.fallbackPort"), text: $viewModel.fallbackPortText)
        }
    }

    private func optionRow(_ label: LocalizedStringResource, text: Binding<String>, disabled: Bool = false) -> some View {
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
                .disabled(disabled || viewModel.isRunning)
        }
        .opacity(disabled ? 0.5 : 1)
    }

    private func summarySection(_ summary: PingSummary) -> some View {
        SectionCard(title: L10n("ping.section.summary"), systemImage: "chart.bar") {
            if viewModel.usingTCPFallback {
                Label(L10n("ping.mode.tcp"), systemImage: "bolt.horizontal.circle")
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                StatusBadge(
                    kind: summary.lossPercent == 0 ? .success : (summary.lossPercent < 100 ? .warning : .danger),
                    text: L10n("ping.badge.loss")
                )
                Text("\(summary.lossPercent)%")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                Text("\(summary.received)/\(summary.sent)")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Divider().overlay(theme.separator)
            ResultRow(label: L10n("ping.result.min"), value: format(summary.minMs))
            ResultRow(label: L10n("ping.result.avg"), value: format(summary.avgMs))
            ResultRow(label: L10n("ping.result.max"), value: format(summary.maxMs))
            ResultRow(label: L10n("ping.result.mdev"), value: format(summary.mdevMs))

            let series = viewModel.attempts.compactMap(\.milliseconds)
            if series.count > 1 {
                Sparkline(values: series)
                    .padding(.top, Spacing.sm)
            }
        }
    }

    private var attemptsSection: some View {
        SectionCard(title: L10n("ping.section.attempts"), systemImage: "list.number") {
            VStack(spacing: Spacing.xs) {
                ForEach(viewModel.attempts) { attempt in
                    HStack {
                        Text("#\(attempt.sequence)")
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        if let ms = attempt.milliseconds {
                            Text(String(format: "%.1f ms", ms))
                                .font(AppTypography.monoBody)
                                .foregroundStyle(theme.success)
                                .environment(\.layoutDirection, .leftToRight)
                        } else {
                            Text(L10n("ping.timeout"))
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.danger)
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        SectionCard(title: L10n("history.recent"), systemImage: "clock.arrow.circlepath") {
            ForEach(Array(viewModel.history.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    private var noteSection: some View {
        Text(L10n("ping.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f ms", value)
    }
}
