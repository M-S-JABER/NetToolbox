import SwiftUI
import Observation

/// Connects to an SMTP server and runs a short EHLO handshake, showing the
/// banner and advertised capabilities — a quick server health / capability probe.
struct SMTPService: Sendable {
    func probe(host: String, port: UInt16, tls: Bool) async -> Result<String, String> {
        guard let connection = TCPConnection(host: host, port: port, tls: tls) else {
            return .failure(L10nString("banner.error.host"))
        }
        if case .failure(let error) = await connection.open(timeout: 6) {
            connection.cancel()
            return .failure(error.localizedDescription)
        }
        var log = ""
        func read() async {
            if case .success(let data) = await connection.receive(), !data.isEmpty {
                log += "S: " + String(decoding: data, as: UTF8.self)
                if !log.hasSuffix("\n") { log += "\n" }
            }
        }
        func send(_ line: String) async {
            _ = await connection.send(Data((line + "\r\n").utf8))
            log += "C: \(line)\n"
        }

        await read()                       // greeting
        await send("EHLO nettoolbox.local")
        await read()                       // capabilities
        await send("QUIT")
        await read()
        connection.cancel()
        return log.isEmpty ? .failure(L10nString("banner.empty")) : .success(log)
    }
}

@MainActor
@Observable
final class SMTPViewModel {
    var host = ""
    var portText = "25"
    var tls = false
    private(set) var output: String?
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let service = SMTPService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        output = nil
        errorMessage = nil
        let result = await service.probe(host: target, port: port, tls: tls)
        switch result {
        case .success(let text): output = text
        case .failure(let message): errorMessage = message
        }
        isRunning = false
    }
}

struct SMTPTool: NetworkTool {
    let id = "smtp"
    let titleKey = L10n("tool.smtp.title")
    let subtitleKey = L10n("tool.smtp.subtitle")
    let systemImage = "envelope.arrow.triangle.branch"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SMTPView()) }
}

struct SMTPView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = SMTPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("smtp.input.title"), systemImage: "envelope") {
                    HStack(spacing: Spacing.sm) {
                        TextField(L10nString("banner.input.host"), text: $viewModel.host)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                            .environment(\.layoutDirection, .leftToRight)
                        SavedHostMenu(host: $viewModel.host)
                    }
                    HStack(spacing: Spacing.md) {
                        TextField("25", text: $viewModel.portText)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                            .keyboardType(.numberPad).frame(maxWidth: 90)
                            .environment(\.layoutDirection, .leftToRight)
                        Toggle(isOn: $viewModel.tls) {
                            Text(L10n("banner.tls")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                        }
                    }
                    Button {
                        Task { await viewModel.run() }
                    } label: {
                        Label(L10nString("smtp.action.probe"), systemImage: "arrow.right.circle").font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
                    if viewModel.isRunning { ProgressView() }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let output = viewModel.output {
                    SectionCard(title: L10n("smtp.section.transcript"), systemImage: "text.alignleft") {
                        Text(output).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .leftToRight)
                        CopyButton(value: output)
                    }
                }
                Text(L10n("smtp.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.smtp.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
