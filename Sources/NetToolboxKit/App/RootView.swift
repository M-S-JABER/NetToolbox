import SwiftUI

/// Home screen in the native iOS idiom: an inset-grouped list of tools by
/// category, a system search bar, a Favorites section, and a live
/// network-status row — all generated from `ToolRegistry`, so it reads like
/// the Settings app rather than a bespoke dashboard.
struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @Environment(FavoritesStore.self) private var favorites

    @Binding var themeSelection: String
    @State private var search = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                if searchQuery.isEmpty {
                    statusSection
                    if !favoriteTools.isEmpty { favoritesSection }
                    ForEach(ToolRegistry.activeCategories) { category in
                        categorySection(category)
                    }
                } else {
                    if let suggestion = smartSuggestion { smartSection(suggestion) }
                    if !searchMatches.isEmpty { searchSection }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(Text(L10n("app.title")))
            .searchable(text: $search, prompt: Text(L10n("home.search")))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .overlay {
                if !searchQuery.isEmpty && searchMatches.isEmpty && smartSuggestion == nil {
                    ContentUnavailableView {
                        Label(L10nString("home.noResults"), systemImage: "magnifyingglass")
                    } description: {
                        Text(L10n("home.noResults.caption"))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text(L10n("settings.title")))
                }
            }
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

    /// Detects when the query looks like an IP / MAC / URL / domain and
    /// suggests the most relevant tool.
    private var smartSuggestion: (kind: InputClassifier.Kind, tool: any NetworkTool)? {
        let kind = InputClassifier.classify(search)
        guard let id = kind.suggestedToolID, let tool = ToolRegistry.tool(withID: id) else {
            return nil
        }
        return (kind, tool)
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                Image(systemName: status.connection.symbol)
                    .foregroundStyle(status.connection.isOnline ? theme.success : theme.danger)
                Text(L10n(status.connection.labelKey))
                    .foregroundStyle(theme.textPrimary)
                if status.isExpensive {
                    Text(L10n("status.metered"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.warning)
                }
                Spacer()
                Text("\(ToolRegistry.all.count) \(L10nString("home.toolsCount"))")
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var favoritesSection: some View {
        Section {
            ForEach(favoriteTools, id: \.id) { toolRow($0) }
        } header: {
            Label(L10nString("home.favorites"), systemImage: "star.fill")
        }
    }

    private func categorySection(_ category: ToolCategory) -> some View {
        Section {
            ForEach(ToolRegistry.tools(in: category), id: \.id) { toolRow($0) }
        } header: {
            Text(category.titleKey)
        } footer: {
            Text(category.captionKey)
        }
    }

    private var searchSection: some View {
        Section {
            ForEach(searchMatches, id: \.id) { toolRow($0) }
        } header: {
            Text("\(searchMatches.count) \(L10nString("home.toolsCount"))")
        }
    }

    private func smartSection(_ suggestion: (kind: InputClassifier.Kind, tool: any NetworkTool)) -> some View {
        Section {
            NavigationLink(value: AppRoute.tool(id: suggestion.tool.id)) {
                HStack(spacing: Spacing.md) {
                    iconTile(systemImage: "sparkles", category: suggestion.tool.category)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n(suggestion.kind.messageKey ?? ""))
                            .font(AppTypography.caption)
                            .foregroundStyle(theme.textSecondary)
                        Text(suggestion.tool.titleKey)
                            .font(AppTypography.headline)
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        } header: {
            Text(L10n("home.smart.title"))
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func toolRow(_ tool: any NetworkTool) -> some View {
        if tool.isAvailable {
            NavigationLink(value: AppRoute.tool(id: tool.id)) {
                rowContent(tool)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    favorites.toggle(tool.id)
                } label: {
                    Label(
                        L10nString(favorites.isFavorite(tool.id) ? "home.unfavorite" : "home.favorite"),
                        systemImage: favorites.isFavorite(tool.id) ? "star.slash.fill" : "star.fill"
                    )
                }
                .tint(theme.warning)
            }
        } else {
            rowContent(tool)
                .opacity(0.5)
        }
    }

    private func rowContent(_ tool: any NetworkTool) -> some View {
        HStack(spacing: Spacing.md) {
            iconTile(systemImage: tool.systemImage, category: tool.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    Text(tool.titleKey)
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textPrimary)
                    if favorites.isFavorite(tool.id) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.warning)
                    }
                    if !tool.isAvailable {
                        StatusBadge(kind: .neutral, text: L10n("common.soon"))
                    }
                }
                Text(tool.subtitleKey)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func iconTile(systemImage: String, category: ToolCategory) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(category.gradient)
            )
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
