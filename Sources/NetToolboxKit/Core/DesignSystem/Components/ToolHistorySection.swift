import SwiftUI

/// A tool's own "Recent" log, shown inside the tool. Each tool keeps its own
/// list of recent runs in its (persistent) view-model and passes it here.
struct ToolHistorySection: View {
    @Environment(\.theme) private var theme
    let entries: [String]

    var body: some View {
        SectionCard(title: L10n("history.recent"), systemImage: "clock.arrow.circlepath") {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}
