import SwiftUI
import Observation

/// One probe's ping result from a global location.
struct WorldPingProbe: Identifiable, Sendable, Equatable {
    let id: Int
    let location: String
    let network: String
    let min: Double?
    let avg: Double?
    let max: Double?
    let loss: Double?
    let sent: Int
    let received: Int
}

enum WorldPingError: LocalizedError {
    case network
    case badInput

    var errorDescription: String? {
        switch self {
        case .network: return L10nString("worldping.error.network")
        case .badInput: return L10nString("worldping.error.badInput")
        }
    }
}

/// "World Ping": pings a target from probes distributed around the globe via
/// the free, key-less **globalping.io** API (a measurement is started, then
/// polled until it finishes). No local ICMP — the probes do the pinging.
struct WorldPingService: Sendable {
    private let base = "https://api.globalping.io/v1/measurements"

    /// Starts a measurement and returns its id.
    func start(target: String, limit: Int, packets: Int) async throws -> String {
        guard let url = URL(string: base) else { throw WorldPingError.network }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "type": "ping",
            "target": target,
            "limit": limit,
            "locations": [["magic": "world"]],
            "measurementOptions": ["packets": packets],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WorldPingError.network
        }
        struct Created: Decodable { let id: String }
        guard let created = try? JSONDecoder().decode(Created.self, from: data) else { throw WorldPingError.badInput }
        return created.id
    }

    /// Fetches the current results; `finished` is true once the run completes.
    func poll(id: String) async throws -> (finished: Bool, probes: [WorldPingProbe]) {
        guard let url = URL(string: "\(base)/\(id)") else { throw WorldPingError.network }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw WorldPingError.network }

        struct Resp: Decodable {
            let status: String
            let results: [Row]
            struct Row: Decodable { let probe: Probe; let result: Res }
            struct Probe: Decodable { let country: String?; let city: String?; let network: String? }
            struct Res: Decodable {
                let stats: Stats?
                struct Stats: Decodable {
                    let min: Double?; let avg: Double?; let max: Double?
                    let loss: Double?; let total: Int?; let rcv: Int?
                }
            }
        }
        guard let decoded = try? JSONDecoder().decode(Resp.self, from: data) else { throw WorldPingError.badInput }
        let probes = decoded.results.enumerated().map { index, row in
            WorldPingProbe(
                id: index,
                location: [row.probe.city, row.probe.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
                network: row.probe.network ?? "—",
                min: row.result.stats?.min, avg: row.result.stats?.avg, max: row.result.stats?.max,
                loss: row.result.stats?.loss, sent: row.result.stats?.total ?? 0, received: row.result.stats?.rcv ?? 0
            )
        }
        return (decoded.status == "finished", probes)
    }
}

@MainActor
@Observable
final class WorldPingViewModel {
    var host = ""
    var limitText = "8"
    var packetsText = "4"

    private(set) var probes: [WorldPingProbe] = []
    private(set) var isRunning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isRunning else { return }
            if isRunning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var errorMessage: String?
    var activity: ActivityCenter?
    var toolID = ""

    private let service = WorldPingService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        let limit = max(1, min(20, Int(limitText) ?? 8))
        let packets = max(1, min(16, Int(packetsText) ?? 4))

        isRunning = true
        errorMessage = nil
        probes = []
        do {
            let id = try await service.start(target: target, limit: limit, packets: packets)
            for _ in 0..<25 {
                if !isRunning { break }
                try? await Task.sleep(for: .seconds(1))
                let (finished, results) = try await service.poll(id: id)
                probes = results
                if finished { break }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }

    func stop() { isRunning = false }
}

struct WorldPingTool: NetworkTool {
    let id = "world-ping"
    let titleKey = L10n("tool.worldping.title")
    let subtitleKey = L10n("tool.worldping.subtitle")
    let systemImage = "globe"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(WorldPingView()) }
}

@MainActor
struct WorldPingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: WorldPingViewModel {
        sessions.session("world-ping") {
            let model = WorldPingViewModel()
            model.activity = activity
            model.toolID = "world-ping"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.probes.isEmpty {
                    resultsSection
                }
                Text(L10n("worldping.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.worldping.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("worldping.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("worldping.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack {
                labeledField(L10n("worldping.opt.limit"), text: $viewModel.limitText)
                labeledField(L10n("worldping.opt.packets"), text: $viewModel.packetsText)
                Spacer()
            }
            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("worldping.action.start"), systemImage: "globe")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
                if viewModel.isRunning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                    ProgressView()
                }
            }
            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func labeledField(_ label: LocalizedStringResource, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numberPad)
                .frame(maxWidth: 80)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("worldping.section.results"), systemImage: "list.bullet") {
            ForEach(viewModel.probes) { probe in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(probe.location.isEmpty ? "—" : probe.location)
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(lossText(probe))
                            .font(AppTypography.monoCaption)
                            .foregroundStyle((probe.loss ?? 0) == 0 ? theme.success : theme.warning)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    HStack(spacing: Spacing.md) {
                        Text(probe.network)
                            .font(AppTypography.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(rttText(probe))
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(.vertical, 2)
                Divider().overlay(theme.separator)
            }
        }
    }

    private func rttText(_ probe: WorldPingProbe) -> String {
        guard let avg = probe.avg else { return "— ms" }
        let minText = probe.min.map { String(format: "%.0f", $0) } ?? "—"
        let maxText = probe.max.map { String(format: "%.0f", $0) } ?? "—"
        return String(format: "%@ / %.0f / %@ ms", minText, avg, maxText)
    }

    private func lossText(_ probe: WorldPingProbe) -> String {
        "\(probe.received)/\(probe.sent) · \(Int(probe.loss ?? 0))%"
    }
}
