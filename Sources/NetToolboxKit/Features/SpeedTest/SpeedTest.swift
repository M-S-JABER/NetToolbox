import SwiftUI
import Observation

struct SpeedResult: Equatable, Sendable {
    let mbps: Double
    let bytes: Int
    let seconds: Double
}

/// Measures download throughput by fetching a fixed-size payload.
protocol SpeedTesting: Sendable {
    func measureDownload(bytes: Int) async throws -> SpeedResult
}

struct CloudflareSpeedTest: SpeedTesting {
    func measureDownload(bytes: Int) async throws -> SpeedResult {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else {
            throw NetworkServiceError.invalidURL
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)

        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NetworkServiceError.badStatus(http.statusCode)
            }
            let elapsed = clock.now - start
            let seconds = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
            guard seconds > 0 else { throw NetworkServiceError.decoding }
            let mbps = Double(data.count) * 8 / seconds / 1_000_000
            return SpeedResult(mbps: mbps, bytes: data.count, seconds: seconds)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkServiceError.offline
        }
    }
}

@MainActor
@Observable
final class SpeedTestViewModel {
    enum Output: Equatable {
        case idle, running
        case result(SpeedResult)
        case failure(String)
    }

    private(set) var output: Output = .idle

    private let service: any SpeedTesting

    init(service: any SpeedTesting = CloudflareSpeedTest()) {
        self.service = service
    }

    func run() async {
        output = .running
        do {
            output = .result(try await service.measureDownload(bytes: 10_000_000))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct SpeedTestTool: NetworkTool {
    let id = "speed-test"
    let titleKey = L10n("tool.speed.title")
    let subtitleKey = L10n("tool.speed.subtitle")
    let systemImage = "speedometer"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(SpeedTestView()) }
}

struct SpeedTestView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SpeedTestViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                gaugeSection
                Text(L10n("speed.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.speed.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var gaugeSection: some View {
        SectionCard(title: L10n("speed.section.download"), systemImage: "arrow.down.circle") {
            VStack(spacing: Spacing.md) {
                switch viewModel.output {
                case .idle:
                    Text("—")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                case .running:
                    ProgressView()
                        .controlSize(.large)
                        .padding(Spacing.lg)
                    Text(L10n("speed.running"))
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                case .result(let result):
                    HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                        Text(String(format: "%.1f", result.mbps))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accent)
                            .environment(\.layoutDirection, .leftToRight)
                        Text("Mbps")
                            .font(AppTypography.title)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(String(format: "%.1f MB · %.1fs", Double(result.bytes) / 1_000_000, result.seconds))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                case .failure(let message):
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(theme.danger)
                }

                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("speed.action.start"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.output == .running)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
