import SwiftUI
import UniformTypeIdentifiers

struct HistoryTool: NetworkTool {
    let id = "history"
    let titleKey = L10n("tool.history.title")
    let subtitleKey = L10n("tool.history.subtitle")
    let systemImage = "clock.arrow.circlepath"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(HistoryView()) }
}

@MainActor
struct HistoryView: View {
    @Environment(\.theme) private var theme
    @Environment(HistoryStore.self) private var history
    @State private var showImporter = false

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if history.entries.isEmpty {
                    ContentUnavailableView {
                        Label(L10nString("history.empty.title"), systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text(L10n("history.empty.description"))
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    actionsBar
                    SectionCard(title: L10n("history.section.recent"), systemImage: "list.bullet") {
                        VStack(spacing: Spacing.sm) {
                            ForEach(history.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.history.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var actionsBar: some View {
        HStack(spacing: Spacing.sm) {
            ShareLink(item: history.exportJSONString()) {
                Label(L10nString("history.export"), systemImage: "square.and.arrow.up")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)

            Button {
                showImporter = true
            } label: {
                Label(L10nString("history.import"), systemImage: "square.and.arrow.down")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive) {
                withAnimation { history.clear() }
            } label: {
                Label(L10nString("history.clear"), systemImage: "trash")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                history.importJSON(data)
            }
        }
    }

    private func entryRow(_ entry: HistoryStore.Entry) -> some View {
        let tool = ToolRegistry.tool(withID: entry.toolID)
        return HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: tool?.systemImage ?? "clock")
                .foregroundStyle(theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                if let tool {
                    Text(tool.titleKey)
                        .font(AppTypography.footnote.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                Text(entry.input)
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.mono)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(Self.formatter.string(from: entry.date))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    withAnimation { history.remove(entry) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
