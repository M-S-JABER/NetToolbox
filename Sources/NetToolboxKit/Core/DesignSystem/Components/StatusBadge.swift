import SwiftUI

/// Small capsule badge for statuses: success / warning / danger / info / neutral.
@MainActor
struct StatusBadge: View {
    enum Kind {
        case success, warning, danger, info, neutral
    }

    @Environment(\.theme) private var theme

    let kind: Kind
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    private var color: Color {
        switch kind {
        case .success: theme.success
        case .warning: theme.warning
        case .danger: theme.danger
        case .info: theme.accent
        case .neutral: theme.textSecondary
        }
    }
}
