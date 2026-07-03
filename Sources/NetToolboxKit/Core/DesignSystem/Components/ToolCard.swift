import SwiftUI

/// Card used on the home grid for every registered tool.
/// A colour-coded gradient icon chip gives each category its own identity;
/// a favourite star and a "soon" state round out the interactions.
struct ToolCard: View {
    @Environment(\.theme) private var theme

    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String
    let category: ToolCategory
    var isAvailable: Bool = true
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                iconChip
                Spacer()
                if !isAvailable {
                    StatusBadge(kind: .neutral, text: L10n("common.soon"))
                } else if let onToggleFavorite {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundStyle(isFavorite ? theme.warning : theme.textSecondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n("home.favorite")))
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
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [category.tint.opacity(isAvailable ? 0.35 : 0.12), theme.separator],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .opacity(isAvailable ? 1 : 0.55)
    }

    private var iconChip: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isAvailable ? AnyShapeStyle(category.gradient) : AnyShapeStyle(theme.textSecondary))
            )
            .shadow(color: category.tint.opacity(isAvailable ? 0.35 : 0), radius: 8, y: 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            .fill(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [category.tint.opacity(0.10), .clear],
                            startPoint: .topLeading, endPoint: .bottom
                        )
                    )
            )
    }
}
