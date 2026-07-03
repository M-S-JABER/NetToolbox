import SwiftUI

/// Registry entry for the on-device engine test runner.
/// Lets the developer verify all engine logic from Swift Playgrounds
/// on iPad, where XCTest cannot run.
struct SelfTestTool: NetworkTool {
    let id = "self-test"
    let titleKey: LocalizedStringResource = "tool.selftest.title"
    let subtitleKey: LocalizedStringResource = "tool.selftest.subtitle"
    let systemImage = "checkmark.seal"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView {
        AnyView(SelfTestView())
    }
}

/// Runs `EngineTestSuite` and lists each case with its result.
struct SelfTestView: View {
    @Environment(\.theme) private var theme

    @State private var outcomes: [EngineTestSuite.Outcome] = []

    private var failures: Int { outcomes.filter { !$0.passed }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: "selftest.section.summary", systemImage: "checkmark.seal") {
                    HStack {
                        if outcomes.isEmpty {
                            Text("selftest.prompt")
                                .font(AppTypography.body)
                                .foregroundStyle(theme.textSecondary)
                        } else {
                            Text("\(outcomes.count - failures) / \(outcomes.count)")
                                .font(AppTypography.monoLarge)
                                .foregroundStyle(failures == 0 ? theme.success : theme.danger)
                                .environment(\.layoutDirection, .leftToRight)
                            StatusBadge(
                                kind: failures == 0 ? .success : .danger,
                                text: failures == 0 ? "selftest.allPassed" : "selftest.failures"
                            )
                        }
                        Spacer()
                        Button {
                            outcomes = EngineTestSuite.runAll()
                        } label: {
                            Label("selftest.run", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !outcomes.isEmpty {
                    SectionCard(title: "selftest.section.cases", systemImage: "list.bullet") {
                        VStack(spacing: Spacing.sm) {
                            ForEach(outcomes) { outcome in
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    HStack {
                                        Image(
                                            systemName: outcome.passed
                                                ? "checkmark.circle.fill"
                                                : "xmark.circle.fill"
                                        )
                                        .foregroundStyle(outcome.passed ? theme.success : theme.danger)
                                        Text(outcome.name)
                                            .font(AppTypography.body)
                                            .foregroundStyle(theme.textPrimary)
                                        Spacer()
                                    }
                                    if let message = outcome.failureMessage {
                                        Text(message)
                                            .font(AppTypography.monoCaption)
                                            .foregroundStyle(theme.danger)
                                            .environment(\.layoutDirection, .leftToRight)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text("tool.selftest.title"))
        .navigationBarTitleDisplayMode(.large)
    }
}
