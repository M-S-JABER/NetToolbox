import SwiftUI
import Observation

/// Queries a memcached server's `version` and `stats` over its text protocol.
struct MemcachedService: Sendable {
    func stats(host: String, port: UInt16) async -> Result<String, String> {
        guard let connection = TCPConnection(host: host, port: port) else {
            return .failure(L10nString("banner.error.host"))
        }
        if case .failure(let error) = await connection.open(timeout: 6) {
            connection.cancel()
            return .failure(error.localizedDescription)
        }
        _ = await connection.send(Data("version\r\nstats\r\n".utf8))
        let result = await connection.receiveAll(timeout: 3)
        connection.cancel()
        switch result {
        case .success(let data):
            let text = String(decoding: data, as: UTF8.self)
            return text.isEmpty ? .failure(L10nString("banner.empty")) : .success(text)
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class MemcachedViewModel {
    var host = ""
    var portText = "11211"
    private(set) var output: String?
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let service = MemcachedService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        output = nil
        errorMessage = nil
        let result = await service.stats(host: target, port: port)
        switch result {
        case .success(let text): output = text
        case .failure(let message): errorMessage = message
        }
        isRunning = false
    }
}

struct MemcachedTool: NetworkTool {
    let id = "memcached"
    let titleKey = L10n("tool.memcached.title")
    let subtitleKey = L10n("tool.memcached.subtitle")
    let systemImage = "memorychip"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(MemcachedView()) }
}

@MainActor
struct MemcachedView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = MemcachedViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("memcached.input.title"), systemImage: "memorychip") {
                    HStack(spacing: Spacing.sm) {
                        TextField(L10nString("banner.input.host"), text: $viewModel.host)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                            .environment(\.layoutDirection, .leftToRight)
                        SavedHostMenu(host: $viewModel.host)
                    }
                    TextField("11211", text: $viewModel.portText)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .keyboardType(.numberPad).frame(maxWidth: 120)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        Task { await viewModel.run() }
                    } label: {
                        Label(L10nString("memcached.action.stats"), systemImage: "chart.bar").font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
                    if viewModel.isRunning { ProgressView() }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let output = viewModel.output {
                    SectionCard(title: L10n("memcached.section.stats"), systemImage: "text.alignleft") {
                        Text(output).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .leftToRight)
                        CopyButton(value: output)
                    }
                }
                Text(L10n("memcached.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.memcached.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
