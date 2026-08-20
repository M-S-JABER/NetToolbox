import SwiftUI

/// The in-app user guide. Reached from **Settings → Help** (it is not a
/// network probe, so it no longer lives in the tool list).
///
/// The per-tool catalogue is *generated* from `ToolRegistry` × `ToolHelp`, so
/// it always documents exactly the tools that ship — adding a tool documents it
/// here automatically, with no separate copy to keep in sync. A short set of
/// app-level topics (that belong to no single tool) is kept hand-written above
/// the catalogue.
@MainActor
struct GuideView: View {
    @Environment(\.theme) private var theme

    private var arabic: Bool { ToolHelp.isArabic }

    /// App-wide topics that have no single tool `id`.
    private struct Topic: Identifiable {
        let icon: String
        let title: String
        let body: String
        var id: String { title }
    }

    private let topics: [Topic] = [
        Topic(icon: "sparkles", title: "guide.intro.title", body: "guide.intro.body"),
        Topic(icon: "house", title: "guide.home.title", body: "guide.home.body"),
        Topic(icon: "wifi", title: "guide.wifi.title", body: "guide.wifi.body"),
        Topic(icon: "lock.shield", title: "guide.permissions.title", body: "guide.permissions.body"),
        Topic(icon: "exclamationmark.triangle", title: "guide.limits.title", body: "guide.limits.body"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(topics) { topic in
                    SectionCard(title: L10n(topic.title), systemImage: topic.icon) {
                        Text(L10n(topic.body))
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(ToolRegistry.activeCategories) { category in
                    categorySection(category)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.guide.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Per-category catalogue

    private func categorySection(_ category: ToolCategory) -> some View {
        let tools = ToolRegistry.tools(in: category)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            categoryHeader(category, count: tools.count)
            ForEach(tools, id: \.id) { tool in
                toolCard(tool)
            }
        }
    }

    private func categoryHeader(_ category: ToolCategory, count: Int) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(category.tint)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(category.tint.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(category.titleKey)
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
                Text(category.captionKey)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Text(verbatim: "\(count)")
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.textSecondary)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.top, Spacing.sm)
    }

    private func toolCard(_ tool: any NetworkTool) -> some View {
        SectionCard(title: tool.titleKey, systemImage: tool.systemImage) {
            if let help = ToolHelp.entry(for: tool.id) {
                helpBlock(L10n("help.section.overview"), help.overview.value(arabic: arabic))
                helpBlock(L10n("help.section.howItWorks"), help.howItWorks.value(arabic: arabic))
                helpBlock(L10n("help.section.example"), help.example.value(arabic: arabic))
                helpBlock(L10n("help.section.notes"), help.notes.value(arabic: arabic))
            } else {
                Text(tool.subtitleKey)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func helpBlock(_ label: LocalizedStringResource, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Text(body)
                .font(AppTypography.body)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
