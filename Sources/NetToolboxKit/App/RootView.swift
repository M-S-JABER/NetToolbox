import SwiftUI

/// Home screen as a persistent sidebar + detail (`NavigationSplitView`):
/// the tool list stays open on the left while a tool fills the detail pane,
/// and it collapses to a phone-style push on iPhone. Sidebar rows are plain —
/// a hollow SF Symbol and the tool's short name, nothing else.
@MainActor
struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @Environment(FavoritesStore.self) private var favorites
    @Environment(RecentToolsStore.self) private var recentTools
    @Environment(ActivityCenter.self) private var activity

    @Binding var themeSelection: String
    @State private var search = ""
    @State private var selectedToolID: String?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedToolID) {
                if searchQuery.isEmpty {
                    if !favoriteTools.isEmpty { favoritesSection }
                    ForEach(ToolRegistry.activeCategories) { category in
                        categorySection(category)
                    }
                } else {
                    if let suggestion = smartSuggestion { row(suggestion.tool) }
                    ForEach(searchMatches, id: \.id) { row($0) }
                }
            }
            .listStyle(.sidebar)
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
            .sheet(isPresented: $showSettings) {
                SettingsView(themeSelection: $themeSelection)
            }
        } detail: {
            NavigationStack {
                detailView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedToolID) { _, newValue in
            if let newValue { recentTools.record(newValue) }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedToolID, let tool = ToolRegistry.tool(withID: id) {
            tool.makeView()
                .background(theme.background)
        } else {
            DashboardView(onOpen: { selectedToolID = $0 })
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

    private var smartSuggestion: (kind: InputClassifier.Kind, tool: any NetworkTool)? {
        let kind = InputClassifier.classify(search)
        guard let id = kind.suggestedToolID, let tool = ToolRegistry.tool(withID: id) else {
            return nil
        }
        return (kind, tool)
    }

    // MARK: Sidebar

    private var favoritesSection: some View {
        Section {
            ForEach(favoriteTools, id: \.id) { row($0) }
        } header: {
            Text(L10n("home.favorites"))
        }
    }

    private func categorySection(_ category: ToolCategory) -> some View {
        Section {
            ForEach(ToolRegistry.tools(in: category), id: \.id) { row($0) }
        } header: {
            Text(category.titleKey)
        }
    }

    /// One plain sidebar row: a hollow symbol + the tool's short name, plus a
    /// live-activity dot when the tool has a running operation.
    @ViewBuilder
    private func row(_ tool: any NetworkTool) -> some View {
        HStack {
            Label {
                Text(tool.titleKey)
                    .foregroundStyle(theme.textPrimary)
            } icon: {
                Image(systemName: tool.systemImage)
                    .foregroundStyle(tool.category.tint)
            }
            if activity.running.contains(tool.id) {
                Spacer()
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.success)
                    .symbolEffect(.pulse, options: .repeating, isActive: true)
                    .accessibilityLabel(Text(L10n("activity.running")))
            }
        }
        .tag(tool.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                favorites.toggle(tool.id)
            } label: {
                Image(systemName: favorites.isFavorite(tool.id) ? "star.slash" : "star")
            }
            .tint(theme.warning)
        }
    }
}
