import SwiftUI
import Observation

struct HTTPTimingPhase: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let ms: Double
}

/// Collects `URLSessionTaskMetrics` to break a request into DNS / connect / TLS
/// / request / wait / download phases — a mini timing waterfall.
final class TimingCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    var metrics: URLSessionTaskMetrics?
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }
}

struct HTTPTimingService: Sendable {
    func measure(urlString: String) async throws -> (phases: [HTTPTimingPhase], status: Int, total: Double) {
        var text = urlString.trimmingCharacters(in: .whitespaces)
        if !text.lowercased().hasPrefix("http") { text = "https://\(text)" }
        guard let url = URL(string: text) else { throw NetworkServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let collector = TimingCollector()
        let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request, delegate: collector)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let tx = collector.metrics?.transactionMetrics.last else { throw NetworkServiceError.decoding }

        func ms(_ start: Date?, _ end: Date?) -> Double? {
            guard let start, let end else { return nil }
            let value = end.timeIntervalSince(start) * 1000
            return value >= 0 ? value : nil
        }

        var phases: [HTTPTimingPhase] = []
        func add(_ name: String, _ value: Double?) { if let value { phases.append(HTTPTimingPhase(name: name, ms: value)) } }
        add("DNS", ms(tx.domainLookupStartDate, tx.domainLookupEndDate))
        add("Connect", ms(tx.connectStartDate, tx.connectEndDate))
        add("TLS", ms(tx.secureConnectionStartDate, tx.secureConnectionEndDate))
        add("Request", ms(tx.requestStartDate, tx.requestEndDate))
        add("Wait (TTFB)", ms(tx.requestEndDate, tx.responseStartDate))
        add("Download", ms(tx.responseStartDate, tx.responseEndDate))
        let total = ms(tx.fetchStartDate, tx.responseEndDate) ?? phases.reduce(0) { $0 + $1.ms }
        return (phases, status, total)
    }
}

@MainActor
@Observable
final class HTTPTimingViewModel {
    var url = ""
    private(set) var phases: [HTTPTimingPhase] = []
    private(set) var status = 0
    private(set) var total: Double = 0
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private let service = HTTPTimingService()

    func run() async {
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isRunning = true
        errorMessage = nil
        phases = []
        do {
            let result = try await service.measure(urlString: url)
            phases = result.phases
            status = result.status
            total = result.total
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

struct HTTPTimingTool: NetworkTool {
    let id = "http-timing"
    let titleKey = L10n("tool.httptiming.title")
    let subtitleKey = L10n("tool.httptiming.subtitle")
    let systemImage = "chart.bar.xaxis"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(HTTPTimingView()) }
}

@MainActor
struct HTTPTimingView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = HTTPTimingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if !viewModel.phases.isEmpty {
                    resultSection
                }
                Text(L10n("httptiming.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.httptiming.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("httptiming.input.title"), systemImage: "link") {
            TextField(L10nString("httptiming.input.url"), text: $viewModel.url)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("httptiming.action.measure"), systemImage: "stopwatch").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private var resultSection: some View {
        SectionCard(title: L10n("httptiming.section.result"), systemImage: "chart.bar.xaxis") {
            HStack {
                StatusBadge(kind: (200..<400).contains(viewModel.status) ? .success : .warning, text: L10n("httptiming.status"))
                Text("\(viewModel.status)").font(AppTypography.monoBody).foregroundStyle(theme.textPrimary)
                Spacer()
                Text(String(format: "%.0f ms", viewModel.total))
                    .font(AppTypography.monoBody).foregroundStyle(theme.accent)
                    .environment(\.layoutDirection, .leftToRight)
            }
            let maxMs = max(viewModel.phases.map(\.ms).max() ?? 1, 1)
            ForEach(viewModel.phases) { phase in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(phase.name).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f ms", phase.ms))
                            .font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accent)
                            .frame(width: max(4, geo.size.width * CGFloat(phase.ms / maxMs)), height: 8)
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}
