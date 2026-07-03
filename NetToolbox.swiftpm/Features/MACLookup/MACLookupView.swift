import SwiftUI

/// MAC / OUI lookup screen: normalize any MAC format and identify
/// the vendor from the bundled offline OUI database.
struct MACLookupView: View {
    @Environment(\.theme) private var theme

    @State private var viewModel = MACLookupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection

                switch viewModel.output {
                case .idle:
                    ContentUnavailableView(
                        "mac.empty.title",
                        systemImage: "barcode.viewfinder",
                        description: Text("mac.empty.description")
                    )
                    .frame(maxWidth: .infinity)
                case .failure(let message):
                    SectionCard(title: "common.error", systemImage: "exclamationmark.triangle.fill") {
                        HStack(spacing: Spacing.sm) {
                            StatusBadge(kind: .danger, text: "common.invalidInput")
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
        .navigationTitle(Text("tool.mac.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: "mac.input.title", systemImage: "keyboard") {
            TextField("mac.input.placeholder", text: $viewModel.input)
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
                    Label("common.search", systemImage: "magnifyingglass.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)

                Button("common.clear", role: .destructive) {
                    viewModel.clear()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func resultSection(_ result: MACLookupViewModel.LookupResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionCard(title: "mac.section.vendor", systemImage: "building.2") {
                if let vendor = result.vendor {
                    HStack {
                        Text(vendor)
                            .font(AppTypography.title)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        StatusBadge(kind: .success, text: "mac.badge.identified")
                    }
                } else {
                    HStack {
                        Text("mac.notFound")
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        StatusBadge(
                            kind: result.isLocallyAdministered ? .info : .warning,
                            text: result.isLocallyAdministered
                                ? "mac.badge.randomized"
                                : "mac.badge.unknown"
                        )
                    }
                }
            }

            SectionCard(title: "mac.section.details", systemImage: "list.bullet.rectangle") {
                HStack {
                    Text("mac.result.normalized")
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    CopyableValue(value: result.normalized)
                }
                HStack {
                    Text("mac.result.cisco")
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    CopyableValue(value: result.ciscoNotation)
                }
                ResultRow(label: "mac.result.oui", value: result.oui)
                Divider().overlay(theme.separator)
                HStack(spacing: Spacing.sm) {
                    StatusBadge(
                        kind: .info,
                        text: result.isMulticast ? "mac.type.multicast" : "mac.type.unicast"
                    )
                    StatusBadge(
                        kind: result.isLocallyAdministered ? .warning : .neutral,
                        text: result.isLocallyAdministered ? "mac.admin.local" : "mac.admin.universal"
                    )
                }
            }
        }
    }
}
