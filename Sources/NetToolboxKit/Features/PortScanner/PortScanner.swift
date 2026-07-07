import SwiftUI
import Observation

/// Result of probing a single port.
struct PortScanResult: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable { case open, closed }
    let port: UInt16
    let state: State
    let service: String?

    var id: UInt16 { port }
}

/// Scans TCP ports on a host via `TCPProbe`, with bounded concurrency.
protocol PortScanning: Sendable {
    func scan(host: String, ports: [UInt16], timeout: Double) async -> [PortScanResult]
}

struct TCPPortScanner: PortScanning {
    func scan(host: String, ports: [UInt16], timeout: Double) async -> [PortScanResult] {
        await withTaskGroup(of: PortScanResult.self) { group in
            let semaphore = ConcurrencyLimiter(limit: 16)
            for port in ports {
                group.addTask {
                    await semaphore.acquire()
                    defer { Task { await semaphore.release() } }
                    let result = await TCPProbe.connectLatency(host: host, port: port, timeout: timeout)
                    let isOpen = (try? result.get()) != nil
                    return PortScanResult(
                        port: port,
                        state: isOpen ? .open : .closed,
                        service: PortDatabase.serviceName(for: Int(port))
                    )
                }
            }
            var results: [PortScanResult] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.port < $1.port }
        }
    }
}

/// A simple async concurrency gate.
actor ConcurrencyLimiter {
    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.limit = limit }

    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
        active += 1
    }

    func release() {
        active -= 1
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

/// Parses a port specification like "22, 80, 443, 8000-8100" into a sorted
/// list of ports. Pure and unit-tested.
enum PortList {
    static func parse(_ text: String, max: Int = 4096) -> [UInt16]? {
        let tokens = text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
        guard !tokens.isEmpty else { return nil }
        var set = Set<Int>()
        for token in tokens {
            if let dash = token.firstIndex(of: "-") {
                let low = token[..<dash]
                let high = token[token.index(after: dash)...]
                guard let a = Int(low), let b = Int(high), a <= b, a >= 1, b <= 65535 else { return nil }
                for port in a...b { set.insert(port) }
            } else {
                guard let port = Int(token), port >= 1, port <= 65535 else { return nil }
                set.insert(port)
            }
            if set.count > max { return nil }
        }
        return set.isEmpty ? nil : set.sorted().map { UInt16($0) }
    }
}

@MainActor
@Observable
final class PortScannerViewModel {
    enum Preset: String, CaseIterable, Identifiable {
        case common, web, all, custom
        var id: String { rawValue }
        var labelKey: String { "portscan.preset.\(rawValue)" }
    }

    var host = ""
    var preset: Preset = .common
    var customPorts = "1-1024"
    private(set) var results: [PortScanResult] = []
    private(set) var isScanning = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isScanning else { return }
            if isScanning { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var scannedCount = 0
    private(set) var totalCount = 0
    private(set) var errorMessage: String?
    private(set) var history: [String] = []
    var activity: ActivityCenter?
    var toolID = ""

    var openPorts: [PortScanResult] { results }

    private var ports: [UInt16]? {
        switch preset {
        case .common:
            return [21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 587, 993, 995, 3306, 3389, 5432, 8080, 8443, 8728]
        case .web:
            return [80, 443, 8000, 8008, 8080, 8443, 8888]
        case .all:
            return PortDatabase.all.map { UInt16($0.port) }.sorted()
        case .custom:
            return PortList.parse(customPorts)
        }
    }

    func scan() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        guard let targetPorts = ports else {
            errorMessage = String(localized: "error.portscan.invalidPorts", bundle: .module)
            return
        }
        errorMessage = nil
        isScanning = true
        results = []
        scannedCount = 0
        totalCount = targetPorts.count

        await withTaskGroup(of: PortScanResult?.self) { group in
            let limiter = ConcurrencyLimiter(limit: 24)
            for port in targetPorts {
                group.addTask {
                    await limiter.acquire()
                    defer { Task { await limiter.release() } }
                    let result = await TCPProbe.connectLatency(host: target, port: port, timeout: 1.5)
                    guard (try? result.get()) != nil else { return nil }
                    return PortScanResult(
                        port: port, state: .open,
                        service: PortDatabase.serviceName(for: Int(port))
                    )
                }
            }
            for await result in group {
                scannedCount += 1
                if let result {
                    results.append(result)
                    results.sort { $0.port < $1.port }
                }
                if !isScanning { break }
            }
        }
        isScanning = false
        history.insert("\(target) — \(results.count) open / \(totalCount)", at: 0)
        if history.count > 10 { history.removeLast() }
    }

    func stop() { isScanning = false }
}

struct PortScannerTool: NetworkTool {
    let id = "port-scanner"
    let titleKey = L10n("tool.portscan.title")
    let subtitleKey = L10n("tool.portscan.subtitle")
    let systemImage = "magnifyingglass.circle"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(PortScannerView()) }
}

@MainActor
struct PortScannerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: PortScannerViewModel {
        sessions.session("port-scanner") {
            let model = PortScannerViewModel()
            model.activity = activity
            model.toolID = "port-scanner"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if viewModel.isScanning || viewModel.totalCount > 0 {
                    progressSection
                }
                if !viewModel.results.isEmpty {
                    resultsSection
                }
                if !viewModel.history.isEmpty {
                    ToolHistorySection(entries: viewModel.history)
                }
                Text(L10n("portscan.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.portscan.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("portscan.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("portscan.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }

            Picker(L10nString("portscan.preset.title"), selection: $viewModel.preset) {
                ForEach(PortScannerViewModel.Preset.allCases) { preset in
                    Text(L10n(preset.labelKey)).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.preset == .custom {
                TextField("1-1024, 8080, 3000-3010", text: $viewModel.customPorts)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }

            HStack {
                Button {
                    Task { await viewModel.scan() }
                } label: {
                    Label(L10nString("portscan.action.scan"), systemImage: "magnifyingglass")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)

                if viewModel.isScanning {
                    Button(L10nString("common.stop"), role: .destructive) { viewModel.stop() }
                        .buttonStyle(.bordered)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var progressSection: some View {
        SectionCard(title: L10n("range.section.progress"), systemImage: "gauge") {
            HStack {
                if viewModel.isScanning { ProgressView() }
                Text("\(viewModel.scannedCount) / \(viewModel.totalCount)")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                StatusBadge(
                    kind: .success,
                    text: LocalizedStringResource(stringLiteral: "\(viewModel.openPorts.count) open")
                )
            }
            ProgressView(value: Double(viewModel.scannedCount), total: Double(max(viewModel.totalCount, 1)))
                .tint(theme.accent)
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("portscan.section.open"), systemImage: "lock.open") {
            if viewModel.openPorts.isEmpty {
                Text(L10n("portscan.noneOpen"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.openPorts) { result in
                        HStack {
                            Text(String(result.port))
                                .font(AppTypography.monoLarge)
                                .foregroundStyle(theme.mono)
                                .frame(minWidth: 70, alignment: .leading)
                                .environment(\.layoutDirection, .leftToRight)
                            Text(result.service ?? "—")
                                .font(AppTypography.body)
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            StatusBadge(kind: .success, text: L10n("portscan.open"))
                        }
                    }
                }
            }
        }
    }
}
