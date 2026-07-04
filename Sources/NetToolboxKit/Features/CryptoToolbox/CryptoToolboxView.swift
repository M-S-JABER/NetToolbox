import SwiftUI
import Observation

@MainActor
@Observable
final class CryptoToolboxViewModel {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case hash
        case jwt

        var id: String { rawValue }
        var labelKey: String { "crypto.mode.\(rawValue)" }
    }

    var mode: Mode = .hash
    var input = ""

    var hashes: CryptoTools.Hashes {
        CryptoTools.hashes(of: input)
    }

    var jwt: CryptoTools.JWT? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : CryptoTools.decodeJWT(input)
    }
}

struct CryptoToolboxTool: NetworkTool {
    let id = "crypto-tools"
    let titleKey = L10n("tool.crypto.title")
    let subtitleKey = L10n("tool.crypto.subtitle")
    let systemImage = "lock.doc"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(CryptoToolboxView()) }
}

struct CryptoToolboxView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = CryptoToolboxViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                switch viewModel.mode {
                case .hash:
                    if !viewModel.input.isEmpty { hashSection }
                case .jwt:
                    jwtSection
                }
                Text(L10n("crypto.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.crypto.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("crypto.input.title"), systemImage: "text.cursor") {
            Picker(L10nString("crypto.mode.title"), selection: $viewModel.mode) {
                ForEach(CryptoToolboxViewModel.Mode.allCases) { mode in
                    Text(L10n(mode.labelKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField(
                L10nString(viewModel.mode == .jwt ? "crypto.input.jwt" : "crypto.input.text"),
                text: $viewModel.input,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(AppTypography.monoCaption)
            .lineLimit(2...6)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var hashSection: some View {
        SectionCard(title: L10n("crypto.section.hashes"), systemImage: "number") {
            hashRow("MD5", viewModel.hashes.md5)
            Divider().overlay(theme.separator)
            hashRow("SHA-1", viewModel.hashes.sha1)
            Divider().overlay(theme.separator)
            hashRow("SHA-256", viewModel.hashes.sha256)
            Divider().overlay(theme.separator)
            hashRow("SHA-384", viewModel.hashes.sha384)
            Divider().overlay(theme.separator)
            hashRow("SHA-512", viewModel.hashes.sha512)
        }
    }

    private func hashRow(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(name)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            CopyableValue(value: value, font: AppTypography.monoCaption)
        }
    }

    @ViewBuilder
    private var jwtSection: some View {
        if let jwt = viewModel.jwt {
            SectionCard(title: L10n("crypto.section.jwt"), systemImage: "signature") {
                HStack(spacing: Spacing.sm) {
                    StatusBadge(kind: .info, text: L10n("crypto.jwt.algorithm"))
                    Text(jwt.algorithm)
                        .font(AppTypography.monoBody)
                        .foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    if !jwt.expiry.isEmpty {
                        StatusBadge(kind: jwt.isExpired ? .danger : .success, text: jwt.isExpired ? L10n("crypto.jwt.expired") : L10n("crypto.jwt.valid"))
                    }
                }
                if !jwt.expiry.isEmpty {
                    Text("\(L10nString("crypto.jwt.expires")): \(jwt.expiry)")
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                jsonBlock(L10n("crypto.jwt.header"), jwt.header)
                jsonBlock(L10n("crypto.jwt.payload"), jwt.payload)
            }
        } else if !viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty {
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle") {
                Text(L10n("crypto.jwt.invalid"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.danger)
            }
        }
    }

    private func jsonBlock(_ title: LocalizedStringResource, _ json: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
            Text(json)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
