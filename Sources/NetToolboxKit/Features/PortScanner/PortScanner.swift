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

@MainActor
@Observable
final class PortScannerViewModel {
    enum Preset: String, CaseIterable, Identifiable {
        case common, web, all
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .common: "portscan.preset.common"
            case .web: "portscan.preset.web"
            case .all: "portscan.preset.all"
            }
        }
    }

    var host = ""
    var preset: Preset = .common
    private(set) var results: [PortScanResult] = []
    private(set) var isScanning = false
    private(set) var scannedCount = 0
    private(set) var totalCount = 0

    private let scanner: any PortScanning

    init(scanner: any PortScanning = TCPPortScanner()) {
        self.scanner = scanner
    }

    var openPorts: [PortScanResult] { results.filter { $0.state == .open } }

    private var ports: [UInt16] {
        switch preset {
        case .common:
            return [21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 587, 993, 995, 3306, 3389, 5432, 8080, 8443, 8728]
        case .web:
            return [80, 443, 8000, 8008, 8080, 8443, 8888]
        case .all:
            return Array(PortDatabase.all.map { UInt16($0.port) })
        }
    }

    func scan() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        let targetPorts = ports
        isScanning = true
        results = []
        scannedCount = 0
        totalCount = targetPorts.count

        let scanned = await scanner.scan(host: target, ports: targetPorts, timeout: 1.5)
        results = scanned
        scannedCount = scanned.count
        isScanning = false
    }
}

struct PortScannerTool: NetworkTool {
    let id = "port-scanner"
    let titleKey = L10n("tool.portscan.title")
    let subtitleKey = L10n("tool.portscan.subtitle")
    let systemImage = "magnifyingglass.circle"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(PortScannerView()) }
}

struct PortScannerView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = PortScannerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if viewModel.isScanning {
                    HStack(spacing: Spacing.md) {
                        ProgressView()
                        Text(L10n("portscan.scanning"))
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                if !viewModel.results.isEmpty {
                    resultsSection
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
        SectionCard(title: L10n("portscan.input.title"), systemImage: "target") {
            TextField(L10nString("portscan.input.host"), text: $viewModel.host)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)

            Picker(L10nString("portscan.preset.title"), selection: $viewModel.preset) {
                ForEach(PortScannerViewModel.Preset.allCases) { preset in
                    Text(L10n(preset.labelKey)).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            Button {
                Task { await viewModel.scan() }
            } label: {
                Label(L10nString("portscan.action.scan"), systemImage: "magnifyingglass")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)
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
