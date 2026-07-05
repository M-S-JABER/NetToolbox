import SwiftUI
import Observation

/// Connects to a TCP port and reads whatever the service announces (SSH/FTP/
/// SMTP banners) — or the response to an optional probe line (e.g. an HTTP
/// request). Uses the shared `TCPConnection`.
struct BannerGrabService: Sendable {
    func grab(host: String, port: UInt16, probe: String, tls: Bool, timeout: Double) async -> Result<String, String> {
        guard let connection = TCPConnection(host: host, port: port, tls: tls) else {
            return .failure(L10nString("banner.error.host"))
        }
        if case .failure(let error) = await connection.open(timeout: timeout) {
            connection.cancel()
            return .failure(error.localizedDescription)
        }
        let trimmedProbe = probe.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProbe.isEmpty {
            _ = await connection.send(Data((trimmedProbe + "\r\n\r\n").utf8))
        }
        let result = await connection.receiveAll(timeout: timeout)
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
final class BannerGrabViewModel {
    var host = ""
    var portText = "22"
    var probe = ""
    var tls = false
    private(set) var output: String?
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let service = BannerGrabService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        output = nil
        errorMessage = nil
        let result = await service.grab(host: target, port: port, probe: probe, tls: tls, timeout: 5)
        switch result {
        case .success(let text): output = text
        case .failure(let message): errorMessage = message
        }
        isRunning = false
    }
}

struct BannerGrabTool: NetworkTool {
    let id = "banner-grab"
    let titleKey = L10n("tool.banner.title")
    let subtitleKey = L10n("tool.banner.subtitle")
    let systemImage = "text.viewfinder"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(BannerGrabView()) }
}

struct BannerGrabView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = BannerGrabViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let output = viewModel.output {
                    SectionCard(title: L10n("banner.section.response"), systemImage: "text.alignleft") {
                        Text(output)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .leftToRight)
                        CopyButton(value: output)
                    }
                }
                Text(L10n("banner.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.banner.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("banner.input.title"), systemImage: "text.viewfinder") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("banner.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                TextField("22", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
                Toggle(isOn: $viewModel.tls) {
                    Text(L10n("banner.tls")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                }
            }
            TextField(L10nString("banner.input.probe"), text: $viewModel.probe)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("banner.action.grab"), systemImage: "text.viewfinder").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }
}
