import SwiftUI

/// A titled card that groups related rows of content.
struct SectionCard<Content: View>: View {
    @Environment(\.theme) private var theme

    let title: LocalizedStringResource
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote)
                        .foregroundStyle(theme.accent)
                }
                Text(title)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
            }

            content
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(theme.surface)
        )
    }
}
