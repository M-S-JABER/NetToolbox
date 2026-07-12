import SwiftUI

/// A sheet that explains one tool — overview, how it works, a worked example,
/// and notes/limitations — in the app's current language. Presented from the
/// "?" button that `RootView` adds to every tool's navigation bar.
@MainActor
struct ToolHelpView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let toolID: String

    private var tool: (any NetworkTool)? { ToolRegistry.tool(withID: toolID) }
    private var content: ToolHelpContent? { ToolHelp.entry(for: toolID) }
    private var arabic: Bool { ToolHelp.isArabic }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let content {
                        header
                        section("info.circle", L10n("help.section.overview"),
                                content.overview.value(arabic: arabic))
                        section("gearshape.2", L10n("help.section.howItWorks"),
                                content.howItWorks.value(arabic: arabic))
                        section("play.circle", L10n("help.section.example"),
                                content.example.value(arabic: arabic))
                        section("exclamationmark.triangle", L10n("help.section.notes"),
                                content.notes.value(arabic: arabic))
                    } else {
                        ContentUnavailableView {
                            Label(L10nString("help.none"), systemImage: "questionmark.circle")
                        }
                    }
                }
                .padding(Spacing.xl)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(theme.background)
            .navigationTitle(Text(L10n("help.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10nString("common.done")) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            if let tool {
                Image(systemName: tool.systemImage)
                    .font(.title2)
                    .foregroundStyle(tool.category.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(tool.category.tint.opacity(0.15))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.titleKey)
                        .font(AppTypography.title)
                        .foregroundStyle(theme.textPrimary)
                    Text(tool.category.titleKey)
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func section(_ icon: String, _ title: LocalizedStringResource, _ body: String) -> some View {
        SectionCard(title: title, systemImage: icon) {
            Text(body)
                .font(AppTypography.body)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
