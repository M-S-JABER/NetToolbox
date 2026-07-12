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
    @Environment(HiddenToolsStore.self) private var hiddenTools
    @Environment(ActivityCenter.self) private var activity

    /// Sentinel selection that shows the dashboard instead of a tool.
    static let dashboardID = "__dashboard__"

    @Binding var themeSelection: String
    @State private var search = ""
    @State private var selectedToolID: String? = RootView.dashboardID
    @State private var showSettings = false
    @AppStorage("nettoolbox.showHidden") private var showHidden = false
    @AppStorage("nettoolbox.onboarded") private var onboarded = false
    @State private var showOnboarding = false
    /// Which category groups are expanded in the sidebar (persisted). Keeping
    /// them collapsed by default turns 45 tools into a short, scannable list.
    @State private var expandedCategories: Set<String> = RootView.loadExpandedCategories()

    private static let expandedKey = "nettoolbox.expandedCategories"

    private static func loadExpandedCategories() -> Set<String> {
        guard let raw = UserDefaults.standard.string(forKey: expandedKey) else {
            return [ToolCategory.diagnostics.rawValue]   // first launch: open the busiest group
        }
        return Set(raw.split(separator: ",").map(String.init))
    }

    private func isExpanded(_ category: ToolCategory) -> Bool {
        expandedCategories.contains(category.rawValue)
    }

    /// Toggles a category group open/closed and persists the choice. Driven by
    /// the section header button below — a plain button in a `List` section
    /// header reliably receives the tap, unlike a `DisclosureGroup` label whose
    /// tap the selectable list row swallows.
    private func toggleCategory(_ category: ToolCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCategories.contains(category.rawValue) {
                expandedCategories.remove(category.rawValue)
            } else {
                expandedCategories.insert(category.rawValue)
            }
        }
        UserDefaults.standard.set(
            expandedCategories.sorted().joined(separator: ","), forKey: Self.expandedKey
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedToolID) {
                if searchQuery.isEmpty {
                    Section { dashboardRow }
                    if !favoriteTools.isEmpty { favoritesSection }
                    ForEach(ToolRegistry.activeCategories) { category in
                        if !visibleTools(in: category).isEmpty {
                            categorySection(category)
                        }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedToolID = Self.dashboardID
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel(Text(L10n("dashboard.home")))
                }
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
            if let newValue, newValue != Self.dashboardID { recentTools.record(newValue) }
        }
        .task {
            if !onboarded { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView { onboarded = true; showOnboarding = false }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedToolID, id != Self.dashboardID, let tool = ToolRegistry.tool(withID: id) {
            tool.makeView()
                .background(theme.background)
        } else {
            DashboardView(onOpen: { selectedToolID = $0 })
        }
    }

    /// A pinned sidebar row that always returns to the dashboard.
    private var dashboardRow: some View {
        Label {
            Text(L10n("dashboard.home"))
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: "house")
                .foregroundStyle(theme.accent)
        }
        .tag(Self.dashboardID)
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

    private func visibleTools(in category: ToolCategory) -> [any NetworkTool] {
        ToolRegistry.tools(in: category).filter { showHidden || !hiddenTools.isHidden($0.id) }
    }

    /// A collapsible category group rendered as a `Section` with a tappable
    /// header. Tapping the header toggles the group; the tool rows only exist
    /// in the hierarchy while expanded, keeping the sidebar short.
    @ViewBuilder
    private func categorySection(_ category: ToolCategory) -> some View {
        let tools = visibleTools(in: category)
        let expanded = isExpanded(category)
        Section {
            if expanded {
                ForEach(tools, id: \.id) { row($0) }
            }
        } header: {
            Button {
                toggleCategory(category)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: category.systemImage)
                        .foregroundStyle(category.tint)
                        .frame(width: 22)
                    Text(category.titleKey)
                        .foregroundStyle(theme.textPrimary)
                        .textCase(nil)
                    Spacer()
                    Text("\(tools.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: hiddenTools.isHidden(tool.id) ? .none : .destructive) {
                hiddenTools.toggle(tool.id)
            } label: {
                Image(systemName: hiddenTools.isHidden(tool.id) ? "eye" : "eye.slash")
            }
        }
        .contextMenu {
            Button {
                favorites.toggle(tool.id)
            } label: {
                Label(
                    L10nString(favorites.isFavorite(tool.id) ? "home.unfavorite" : "home.favorite"),
                    systemImage: favorites.isFavorite(tool.id) ? "star.slash" : "star"
                )
            }
            Button(role: hiddenTools.isHidden(tool.id) ? .none : .destructive) {
                hiddenTools.toggle(tool.id)
            } label: {
                Label(
                    L10nString(hiddenTools.isHidden(tool.id) ? "home.unhide" : "home.hide"),
                    systemImage: hiddenTools.isHidden(tool.id) ? "eye" : "eye.slash"
                )
            }
        }
    }
}
