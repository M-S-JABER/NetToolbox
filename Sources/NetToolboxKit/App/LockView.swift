import SwiftUI

/// Full-screen gate shown while `AppLock` is locked. Prompts for Face ID /
/// Touch ID / passcode on appear and offers a retry button.
@MainActor
struct LockView: View {
    @Environment(\.theme) private var theme
    let lock: AppLock

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Image(systemName: lock.symbolName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(L10n("applock.title"))
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
                Text(L10n("applock.subtitle"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label(L10nString("applock.unlock"), systemImage: lock.symbolName)
                        .font(AppTypography.headline)
                        .padding(.horizontal, Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.xl)
        }
        .task { await lock.unlock() }
    }
}
