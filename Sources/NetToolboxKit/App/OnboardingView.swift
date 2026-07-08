import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// First-run welcome: a short pitch, what the app can do, and a nudge to grant
/// the Local Network permission that the discovery tools depend on.
@MainActor
struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    /// Called when the user taps "Get started".
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text(L10n("app.title"))
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(theme.textPrimary)
                    Text(L10n("onboarding.tagline"))
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    feature("square.grid.2x2.fill", L10n("onboarding.f.tools.title"), L10n("onboarding.f.tools.detail"))
                    feature("wifi.router.fill", L10n("onboarding.f.local.title"), L10n("onboarding.f.local.detail"))
                    feature("lock.shield.fill", L10n("onboarding.f.privacy.title"), L10n("onboarding.f.privacy.detail"))
                }

                VStack(spacing: Spacing.sm) {
                    Text(L10n("onboarding.permissions"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    #if canImport(UIKit)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label(L10nString("settings.permissions.open"), systemImage: "arrow.up.forward.app")
                            .font(AppTypography.footnote)
                    }
                    .buttonStyle(.bordered)
                    #endif
                }

                Button {
                    onFinish()
                } label: {
                    Text(L10n("onboarding.start"))
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .interactiveDismissDisabled()
    }

    private func feature(_ symbol: String, _ title: LocalizedStringResource, _ detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
