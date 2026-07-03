import SwiftUI

/// Home screen, designed for iPad: a category sidebar plus a tool grid,
/// both generated automatically from `ToolRegistry`.
struct RootView: View {
    @Environment(\.theme) private var theme

    /// `nil` selection means "All tools".
    @State private var selectedCategory: ToolCategory?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            // Explicit stack so value-based NavigationLinks inside the
            // detail column push onto it.
            NavigationStack {
                detailGrid
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            Section {
                ForEach(ToolRegistry.activeCategories) { category in
                    Label {
                        Text(category.titleKey)
                    } icon: {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(theme.accent)
                    }
                    .tag(category)
                }
            } header: {
                Text(L10n("root.categories"))
            }
        }
        .navigationTitle(Text(L10n("app.title")))
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }

    // MARK: Tool grid

    private var visibleCategories: [ToolCategory] {
        if let selectedCategory { [selectedCategory] } else { ToolRegistry.activeCategories }
    }

    private var detailGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ForEach(visibleCategories) { category in
                    categorySection(category)
                }
            }
            .padding(Spacing.xl)
        }
        .background(theme.background)
        .navigationTitle(selectedCategory.map { Text($0.titleKey) } ?? Text(L10n("root.allTools")))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AppRoute.self) { route in
            destination(for: route)
        }
    }

    private func categorySection(_ category: ToolCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if selectedCategory == nil {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: category.systemImage)
                        .foregroundStyle(theme.accent)
                    Text(category.titleKey)
                        .font(AppTypography.title)
                        .foregroundStyle(theme.textPrimary)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280), spacing: Spacing.lg)],
                spacing: Spacing.lg
            ) {
                ForEach(ToolRegistry.tools(in: category), id: \.id) { tool in
                    if tool.isAvailable {
                        NavigationLink(value: AppRoute.tool(id: tool.id)) {
                            ToolCard(
                                title: tool.titleKey,
                                subtitle: tool.subtitleKey,
                                systemImage: tool.systemImage,
                                isAvailable: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ToolCard(
                            title: tool.titleKey,
                            subtitle: tool.subtitleKey,
                            systemImage: tool.systemImage,
                            isAvailable: false
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .tool(let id):
            if let tool = ToolRegistry.tool(withID: id) {
                tool.makeView()
                    .background(theme.background)
            } else {
                ContentUnavailableView {
                    Label(L10nString("root.toolNotFound"), systemImage: "questionmark.circle")
                }
            }
        }
    }
}
