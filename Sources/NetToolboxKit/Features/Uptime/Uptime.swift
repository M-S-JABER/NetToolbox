import SwiftUI
import Observation

struct UptimeRow: Identifiable, Sendable {
    let id: String
    let url: String
    let status: Int?
    let ms: Double?
    var up: Bool { (status.map { (200..<400).contains($0) }) ?? false }
}

/// Batch reachability/latency check of a list of URLs — a mini uptime monitor.
struct UptimeService: Sendable {
    func check(_ url: String) async -> UptimeRow {
        var text = url.trimmingCharacters(in: .whitespaces)
        if !text.lowercased().hasPrefix("http") { text = "https://\(text)" }
        guard let parsed = URL(string: text) else {
            return UptimeRow(id: url, url: url, status: nil, ms: nil)
        }
        var request = URLRequest(url: parsed)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            let elapsed = clock.now - start
            let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
            let status = (response as? HTTPURLResponse)?.statusCode
            return UptimeRow(id: url, url: text, status: status, ms: ms)
        } catch {
            return UptimeRow(id: url, url: text, status: nil, ms: nil)
        }
    }
}

@MainActor
@Observable
final class UptimeViewModel {
    var input = ""
    private(set) var rows: [UptimeRow] = []
    private(set) var isRunning = false

    private let service = UptimeService()

    func run() async {
        let urls = input
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !urls.isEmpty else { return }
        isRunning = true
        rows = []
        var collected: [UptimeRow] = []
        await withTaskGroup(of: UptimeRow.self) { group in
            for url in urls { group.addTask { await service.check(url) } }
            for await row in group { collected.append(row) }
        }
        let order = urls
        collected.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        rows = collected
        isRunning = false
    }
}

struct UptimeTool: NetworkTool {
    let id = "uptime"
    let titleKey = L10n("tool.uptime.title")
    let subtitleKey = L10n("tool.uptime.subtitle")
    let systemImage = "checkmark.circle"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(UptimeView()) }
}

struct UptimeView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = UptimeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("uptime.input.title"), systemImage: "list.bullet") {
                    TextField(L10nString("uptime.input.list"), text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                        .lineLimit(3...10)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        Task { await viewModel.run() }
                    } label: {
                        Label(L10nString("uptime.action.check"), systemImage: "arrow.clockwise").font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
                    if viewModel.isRunning { ProgressView() }
                }
                if !viewModel.rows.isEmpty {
                    SectionCard(title: L10n("uptime.section.result"), systemImage: "checkmark.circle") {
                        ForEach(viewModel.rows) { row in
                            HStack(spacing: Spacing.sm) {
                                Circle().fill(row.up ? theme.success : theme.danger).frame(width: 10, height: 10)
                                Text(row.url).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                                    .lineLimit(1).environment(\.layoutDirection, .leftToRight)
                                Spacer()
                                Text(statusText(row)).font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                    }
                }
                Text(L10n("uptime.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.uptime.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private func statusText(_ row: UptimeRow) -> String {
        guard let status = row.status else { return L10nString("uptime.down") }
        let latency = row.ms.map { String(format: "%.0f ms", $0) } ?? ""
        return "\(status) · \(latency)"
    }
}
