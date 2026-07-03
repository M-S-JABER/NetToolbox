import SwiftUI

/// A single label/value result line.
/// Technical values are rendered monospaced and pinned to left-to-right
/// layout even when the UI language is Arabic (RTL).
struct ResultRow: View {
    @Environment(\.theme) private var theme

    let label: LocalizedStringResource
    let value: String
    var isMonospaced: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label)
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.lg)
            Text(value)
                .font(isMonospaced ? AppTypography.monoBody : AppTypography.body)
                .foregroundStyle(isMonospaced ? theme.mono : theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                // Technical data (IP/MAC/hex) must stay LTR in RTL locales.
                .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement(children: .combine)
    }
}
