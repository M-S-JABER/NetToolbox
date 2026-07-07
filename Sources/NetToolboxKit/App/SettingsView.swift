import SwiftUI

/// Settings sheet: pick an accent theme and see app info.
@MainActor
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Binding var themeSelection: String

    private let swatchColumns = [GridItem(.adaptive(minimum: 96), spacing: Spacing.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    themeCard
                    aboutCard
                }
                .padding(Spacing.xl)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(theme.background)
            .navigationTitle(Text(L10n("settings.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10nString("common.done")) { dismiss() }
                }
            }
        }
    }

    private var themeCard: some View {
        SectionCard(title: L10n("settings.theme"), systemImage: "paintpalette") {
            LazyVGrid(columns: swatchColumns, spacing: Spacing.md) {
                ForEach(ThemeOption.allCases) { option in
                    swatch(option)
                }
            }
        }
    }

    private func swatch(_ option: ThemeOption) -> some View {
        let isSelected = themeSelection == option.rawValue
        return Button {
            withAnimation(.snappy) { themeSelection = option.rawValue }
        } label: {
            VStack(spacing: Spacing.sm) {
                Circle()
                    .fill(option.swatch)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .overlay(
                        Circle().strokeBorder(theme.textPrimary.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                    )
                Text(L10n(option.nameKey))
                    .font(AppTypography.caption)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        SectionCard(title: L10n("settings.about"), systemImage: "info.circle") {
            ResultRow(label: L10n("settings.tools"), value: "\(ToolRegistry.all.count)")
            ResultRow(label: L10n("settings.version"), value: "1.4.0")
            Text(L10n("settings.tagline"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
