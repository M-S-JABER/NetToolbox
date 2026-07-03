import SwiftUI

/// Card used on the home grid for every registered tool.
/// Sized for iPad grids; supports Dynamic Type, light/dark and a
/// disabled state for tools that are not available yet.
struct ToolCard: View {
    @Environment(\.theme) private var theme

    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String
    var isAvailable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isAvailable ? theme.accent : theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(theme.accent.opacity(isAvailable ? 0.12 : 0.05))
                    )
                Spacer()
                if !isAvailable {
                    StatusBadge(kind: .neutral, text: "common.soon")
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(theme.separator, lineWidth: 1)
        )
        .opacity(isAvailable ? 1 : 0.55)
    }
}
