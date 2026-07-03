import SwiftUI

/// Home dashboard: a hero header with a live network-status pill, global
/// search, a favourites strip, and colour-coded category sections — all
/// generated from `ToolRegistry`.
struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @Environment(FavoritesStore.self) private var favorites

    @Binding var themeSelection: String
    @State private var search = ""
    @State private var showSettings = false

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: Spacing.lg)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    hero
                    if searchQuery.isEmpty {
                        if !favoriteTools.isEmpty { favoritesSection }
                        ForEach(ToolRegistry.activeCategories) { category in
                            categorySection(category)
                        }
                    } else {
                        searchResults
                    }
                }
                .padding(Spacing.xl)
            }
            .background(theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { destination(for: $0) }
            .sheet(isPresented: $showSettings) {
                SettingsView(themeSelection: $themeSelection)
            }
        }
    }

    // MARK: Data

    private var searchQuery: String {
        search.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var favoriteTools: [any NetworkTool] {
        ToolRegistry.all.filter { favorites.isFavorite($0.id) }
    }

    private func matches(_ tool: any NetworkTool) -> Bool {
        let title = String(localized: tool.titleKey).lowercased()
        let subtitle = String(localized: tool.subtitleKey).lowercased()
        return title.contains(searchQuery)
            || subtitle.contains(searchQuery)
            || tool.id.contains(searchQuery)
    }

    private var searchMatches: [any NetworkTool] {
        ToolRegistry.all.filter(matches)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("app.title"))
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(theme.textPrimary)
                    Text(L10n("home.subtitle"))
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(theme.surface))
                        .overlay(Circle().strokeBorder(theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n("settings.title")))
            }

            statusPill
            searchField
        }
    }

    private var statusPill: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: status.connection.symbol)
                .foregroundStyle(status.connection.isOnline ? theme.success : theme.danger)
            Text(L10n(status.connection.labelKey))
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            if status.isExpensive {
                Text(L10n("status.metered"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.warning)
            }
            Spacer()
            Text("\(ToolRegistry.all.count) \(L10nString("home.toolsCount"))")
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            Capsule().fill(theme.surface)
        )
        .overlay(Capsule().strokeBorder(theme.separator, lineWidth: 1))
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)
            TextField(L10nString("home.search"), text: $search)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(theme.textPrimary)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(theme.separator, lineWidth: 1)
        )
    }

    // MARK: Sections

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(
                systemImage: "star.fill",
                title: L10n("home.favorites"),
                caption: L10n("home.favorites.caption"),
                tint: theme.warning
            )
            LazyVGrid(columns: columns, spacing: Spacing.lg) {
                ForEach(favoriteTools, id: \.id) { toolTile($0) }
            }
        }
    }

    private func categorySection(_ category: ToolCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(
                systemImage: category.systemImage,
                title: category.titleKey,
                caption: category.captionKey,
                tint: category.tint,
                gradient: category.gradient
            )
            LazyVGrid(columns: columns, spacing: Spacing.lg) {
                ForEach(ToolRegistry.tools(in: category), id: \.id) { toolTile($0) }
            }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if searchMatches.isEmpty {
                ContentUnavailableView {
                    Label(L10nString("home.noResults"), systemImage: "magnifyingglass")
                } description: {
                    Text(L10n("home.noResults.caption"))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.lg) {
                    ForEach(searchMatches, id: \.id) { toolTile($0) }
                }
            }
        }
    }

    private func sectionHeader(
        systemImage: String,
        title: LocalizedStringResource,
        caption: LocalizedStringResource,
        tint: Color,
        gradient: LinearGradient? = nil
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(gradient.map { AnyShapeStyle($0) } ?? AnyShapeStyle(tint))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
                Text(caption)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: Tool tile

    @ViewBuilder
    private func toolTile(_ tool: any NetworkTool) -> some View {
        if tool.isAvailable {
            NavigationLink(value: AppRoute.tool(id: tool.id)) {
                ToolCard(
                    title: tool.titleKey,
                    subtitle: tool.subtitleKey,
                    systemImage: tool.systemImage,
                    category: tool.category,
                    isAvailable: true
                )
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.snappy) { favorites.toggle(tool.id) }
                } label: {
                    Image(systemName: favorites.isFavorite(tool.id) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(favorites.isFavorite(tool.id) ? theme.warning : theme.textSecondary)
                        .padding(Spacing.lg)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else {
            ToolCard(
                title: tool.titleKey,
                subtitle: tool.subtitleKey,
                systemImage: tool.systemImage,
                category: tool.category,
                isAvailable: false
            )
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
