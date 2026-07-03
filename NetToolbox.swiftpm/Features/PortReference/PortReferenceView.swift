import SwiftUI

/// Searchable, filterable reference of common TCP/UDP ports.
struct PortReferenceView: View {
    @Environment(\.theme) private var theme

    @State private var viewModel = PortReferenceViewModel()

    var body: some View {
        List {
            Section {
                Picker("ports.filter.title", selection: $viewModel.filter) {
                    ForEach(PortReferenceViewModel.ProtocolFilter.allCases) { filter in
                        Text(LocalizedStringResource(stringLiteral: filter.titleKey))
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "ports.empty.title",
                        systemImage: "magnifyingglass",
                        description: Text("ports.empty.description")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.results) { entry in
                        portRow(entry)
                            .listRowBackground(theme.surface)
                    }
                }
            } footer: {
                Text("ports.footer")
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .searchable(text: $viewModel.query, prompt: Text("ports.search.placeholder"))
        .navigationTitle(Text("tool.ports.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func portRow(_ entry: PortEntry) -> some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            Text(String(entry.port))
                .font(AppTypography.monoLarge)
                .foregroundStyle(theme.mono)
                .frame(minWidth: 76, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(entry.service)
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(entry.summary)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                ForEach(entry.protocols) { proto in
                    Text(proto.rawValue)
                        .font(AppTypography.monoCaption.weight(.semibold))
                        .foregroundStyle(proto == .tcp ? theme.accent : theme.warning)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule().fill(
                                (proto == .tcp ? theme.accent : theme.warning).opacity(0.14)
                            )
                        )
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
