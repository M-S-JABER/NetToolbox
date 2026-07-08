import SwiftUI

/// The home detail pane before a tool is chosen: a live overview (connection,
/// public IP + ISP) plus one-tap access to favourite and recent tools.
@MainActor
struct DashboardView: View {
    @Environment(\.theme) private var theme
    @Environment(NetworkStatusMonitor.self) private var status
    @Environment(FavoritesStore.self) private var favorites
    @Environment(RecentToolsStore.self) private var recentTools

    /// Opens a tool by ID in the split-view detail pane.
    let onOpen: (String) -> Void

    @State private var ipInfo: PublicIPInfo?
    @State private var isLoadingIP = false

    private var favoriteTools: [any NetworkTool] {
        ToolRegistry.all.filter { favorites.isFavorite($0.id) }
    }
    private var recentTools_: [any NetworkTool] {
        recentTools.ids.compactMap { ToolRegistry.tool(withID: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                connectionCard
                if !favoriteTools.isEmpty { quickSection(L10n("home.favorites"), favoriteTools) }
                if !recentTools_.isEmpty { quickSection(L10n("dashboard.recent"), recentTools_) }
                statsCard
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("app.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { await loadIP() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n("app.title"))
                    .font(AppTypography.title)
                    .foregroundStyle(theme.textPrimary)
                Text(L10n("dashboard.tagline"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: Connection + public IP

    private var connectionCard: some View {
        SectionCard(title: L10n("dashboard.connection"), systemImage: "dot.radiowaves.up.forward") {
            HStack(spacing: Spacing.md) {
                Image(systemName: status.connection.symbol)
                    .font(.title2)
                    .foregroundStyle(status.connection.isOnline ? theme.success : theme.danger)
                Text(L10n(status.connection.labelKey))
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if isLoadingIP { ProgressView() }
                Button {
                    Task { await loadIP() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n("common.refresh")))
            }

            if let ipInfo {
                Divider().overlay(theme.separator)
                dashboardRow(L10n("dashboard.publicIP"), ipInfo.ip, mono: true)
                if let isp = ipInfo.isp, !isp.isEmpty { dashboardRow(L10n("dashboard.isp"), isp) }
                let place = [ipInfo.city, ipInfo.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                if !place.isEmpty { dashboardRow(L10n("dashboard.location"), place) }
                if let asn = ipInfo.asn { dashboardRow(L10n("dashboard.asn"), "AS\(asn)", mono: true) }
            } else if !isLoadingIP {
                Divider().overlay(theme.separator)
                Text(L10n("dashboard.ipUnavailable"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dashboardRow(_ label: LocalizedStringResource, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? AppTypography.monoBody : AppTypography.body)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    // MARK: Quick-launch tools

    private func quickSection(_ title: LocalizedStringResource, _ tools: [any NetworkTool]) -> some View {
        SectionCard(title: title, systemImage: "bolt.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(tools, id: \.id) { tool in toolChip(tool) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func toolChip(_ tool: any NetworkTool) -> some View {
        Button {
            onOpen(tool.id)
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: tool.systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(tool.category.gradient)
                    )
                Text(tool.titleKey)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 84)
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats

    private var statsCard: some View {
        SectionCard(title: L10n("dashboard.overview"), systemImage: "square.grid.2x2") {
            ForEach(ToolRegistry.activeCategories) { category in
                Button {
                    if let first = ToolRegistry.tools(in: category).first { onOpen(first.id) }
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(category.tint)
                            .frame(width: 26)
                        Text(category.titleKey)
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(ToolRegistry.tools(in: category).count)")
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if category != ToolRegistry.activeCategories.last {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }

    private func loadIP() async {
        guard !isLoadingIP else { return }
        isLoadingIP = true
        ipInfo = try? await IpwhoisService().fetch()
        isLoadingIP = false
    }
}
