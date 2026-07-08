import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Settings sheet: appearance, permissions, security and app info.
@MainActor
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppLock.self) private var appLock
    @Environment(CloudSync.self) private var cloudSync
    @Environment(HiddenToolsStore.self) private var hiddenTools
    @AppStorage("nettoolbox.showHidden") private var showHidden = false

    @Binding var themeSelection: String
    @AppStorage("nettoolbox.appearance") private var appearanceSelection = AppearanceOption.system.rawValue

    private let swatchColumns = [GridItem(.adaptive(minimum: 96), spacing: Spacing.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    appearanceCard
                    themeCard
                    permissionsCard
                    generalCard
                    securityCard
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

    private var appearanceCard: some View {
        SectionCard(title: L10n("settings.appearance"), systemImage: "circle.lefthalf.filled") {
            Picker(L10nString("settings.appearance"), selection: $appearanceSelection) {
                ForEach(AppearanceOption.allCases) { option in
                    Label {
                        Text(option.labelKey)
                    } icon: {
                        Image(systemName: option.symbol)
                    }
                    .tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
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

    private var permissionsCard: some View {
        SectionCard(title: L10n("settings.permissions"), systemImage: "hand.raised") {
            Text(L10n("settings.permissions.hint"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            permissionRow("network", L10n("perm.localNetwork.title"), L10n("perm.localNetwork.detail"))
            permissionRow("camera", L10n("perm.camera.title"), L10n("perm.camera.detail"))
            permissionRow("photo", L10n("perm.photos.title"), L10n("perm.photos.detail"))
            permissionRow("faceid", L10n("perm.faceid.title"), L10n("perm.faceid.detail"))
            permissionRow("location", L10n("perm.location.title"), L10n("perm.location.detail"))

            #if canImport(UIKit)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label(L10nString("settings.permissions.open"), systemImage: "arrow.up.forward.app")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.xs)
            #endif
        }
    }

    private func permissionRow(_ symbol: String, _ title: LocalizedStringResource, _ detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var generalCard: some View {
        SectionCard(title: L10n("settings.general"), systemImage: "slider.horizontal.3") {
            Toggle(isOn: $showHidden) {
                Label(L10nString("settings.showHidden"), systemImage: "eye")
                    .font(AppTypography.body)
            }
            if hiddenTools.hasHidden {
                Button(role: .destructive) {
                    hiddenTools.showAll()
                } label: {
                    Label(L10nString("settings.unhideAll"), systemImage: "eye.circle")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var securityCard: some View {
        SectionCard(title: L10n("settings.security"), systemImage: "lock.shield") {
            Toggle(isOn: Binding(
                get: { appLock.isEnabled },
                set: { newValue in Task { await appLock.setEnabled(newValue) } }
            )) {
                Label(L10nString("settings.applock"), systemImage: appLock.symbolName)
                    .font(AppTypography.body)
            }
            .disabled(!appLock.isAvailable)

            Text(L10n(appLock.isAvailable ? "settings.applock.hint" : "settings.applock.unavailable"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(theme.separator)

            Toggle(isOn: Binding(
                get: { cloudSync.isEnabled },
                set: { cloudSync.setEnabled($0) }
            )) {
                Label(L10nString("settings.icloud"), systemImage: "icloud")
                    .font(AppTypography.body)
            }
            Text(L10n("settings.icloud.hint"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutCard: some View {
        SectionCard(title: L10n("settings.about"), systemImage: "info.circle") {
            ResultRow(label: L10n("settings.tools"), value: "\(ToolRegistry.all.count)")
            ResultRow(label: L10n("settings.version"), value: appVersion)
            Text(L10n("settings.tagline"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Reads the app's marketing version from the bundle so it never drifts
    /// from the release the user actually installed.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.0"
    }
}
