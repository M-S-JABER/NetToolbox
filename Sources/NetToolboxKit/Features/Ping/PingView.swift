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
struct PingView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = PingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let summary = viewModel.summary {
                    summarySection(summary)
                }
                if !viewModel.attempts.isEmpty {
                    attemptsSection
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
        SectionCard(title: L10n("ping.input.title"), systemImage: "target") {
            TextField(L10nString("ping.input.host"), text: $viewModel.host)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)

            HStack(spacing: Spacing.md) {
                labeledField(L10n("ping.input.port"), text: $viewModel.portText)
                labeledField(L10n("ping.input.count"), text: $viewModel.countText)
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

    private func labeledField(_ label: LocalizedStringResource, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numberPad)
                .frame(maxWidth: 120)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func summarySection(_ summary: PingSummary) -> some View {
        SectionCard(title: L10n("ping.section.summary"), systemImage: "chart.bar") {
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
