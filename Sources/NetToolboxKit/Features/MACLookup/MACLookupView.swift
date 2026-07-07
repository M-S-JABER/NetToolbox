import SwiftUI

/// MAC / OUI lookup screen: normalize any MAC format and identify
/// the vendor from the bundled offline OUI database.
@MainActor
struct MACLookupView: View {
    @Environment(\.theme) private var theme

    @State private var viewModel = MACLookupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection

                switch viewModel.output {
                case .idle:
                    ContentUnavailableView {
                        Label(L10nString("mac.empty.title"), systemImage: "barcode.viewfinder")
                    } description: {
                        Text(L10n("mac.empty.description"))
                    }
                    .frame(maxWidth: .infinity)
                case .failure(let message):
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        HStack(spacing: Spacing.sm) {
                            StatusBadge(kind: .danger, text: L10n("common.invalidInput"))
                            Text(message)
                                .font(AppTypography.body)
                                .foregroundStyle(theme.danger)
                        }
                    }
                case .success(let result):
                    resultSection(result)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.mac.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("mac.input.title"), systemImage: "keyboard") {
            TextField(L10nString("mac.input.placeholder"), text: $viewModel.input)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { viewModel.lookup() }

            HStack {
                Button {
                    viewModel.lookup()
                } label: {
                    Label(L10nString("common.search"), systemImage: "magnifyingglass.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)

                Button(L10nString("common.clear"), role: .destructive) {
                    viewModel.clear()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func resultSection(_ result: MACLookupViewModel.LookupResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionCard(title: L10n("mac.section.vendor"), systemImage: "building.2") {
                if let vendor = result.vendor {
                    HStack {
                        Text(vendor)
                            .font(AppTypography.title)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        StatusBadge(kind: .success, text: L10n("mac.badge.identified"))
                    }
                } else {
                    HStack {
                        Text(L10n("mac.notFound"))
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        StatusBadge(
                            kind: result.isLocallyAdministered ? .info : .warning,
                            text: result.isLocallyAdministered
                                ? L10n("mac.badge.randomized")
                                : L10n("mac.badge.unknown")
                        )
                    }
                }
            }

            SectionCard(title: L10n("mac.section.details"), systemImage: "list.bullet.rectangle") {
                HStack {
                    Text(L10n("mac.result.normalized"))
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    CopyableValue(value: result.normalized)
                }
                HStack {
                    Text(L10n("mac.result.cisco"))
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    CopyableValue(value: result.ciscoNotation)
                }
                ResultRow(label: L10n("mac.result.oui"), value: result.oui)
                Divider().overlay(theme.separator)
                HStack(spacing: Spacing.sm) {
                    StatusBadge(
                        kind: .info,
                        text: result.isMulticast ? L10n("mac.type.multicast") : L10n("mac.type.unicast")
                    )
                    StatusBadge(
                        kind: result.isLocallyAdministered ? .warning : .neutral,
                        text: result.isLocallyAdministered ? L10n("mac.admin.local") : L10n("mac.admin.universal")
                    )
                }
            }
        }
    }
}
