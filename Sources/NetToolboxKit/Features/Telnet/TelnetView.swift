import SwiftUI
import Observation

@MainActor
@Observable
final class TelnetViewModel {
    var host = ""
    var portText = "23"
    var command = ""
    private(set) var transcript = ""
    private(set) var isConnected = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isConnected else { return }
            if isConnected { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var statusMessage: String?
    var activity: ActivityCenter?
    var toolID = ""

    private var connection: TCPConnection?
    private var readTask: Task<Void, Never>?

    func connect() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            statusMessage = String(localized: "error.probe.invalidPort", bundle: .module)
            return
        }
        disconnect()
        transcript = ""
        statusMessage = nil

        guard let connection = TCPConnection(host: target, port: port) else {
            statusMessage = String(localized: "error.probe.invalidHost", bundle: .module)
            return
        }
        let result = await connection.open(timeout: 8)
        switch result {
        case .success:
            self.connection = connection
            isConnected = true
            startReading()
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }

    private func startReading() {
        guard let connection else { return }
        readTask = Task { [weak self] in
            while !Task.isCancelled {
                let result = await connection.receive()
                guard case .success(let data) = result, !data.isEmpty else { break }
                let processed = TelnetProtocol.process([UInt8](data))
                if !processed.reply.isEmpty {
                    _ = await connection.send(Data(processed.reply))
                }
                await MainActor.run {
                    self?.transcript.append(processed.text)
                }
            }
            await MainActor.run { self?.isConnected = false }
        }
    }

    func sendCommand() async {
        guard let connection, isConnected else { return }
        let line = command + "\r\n"
        command = ""
        guard let data = line.data(using: .utf8) else { return }
        _ = await connection.send(data)
    }

    func disconnect() {
        readTask?.cancel()
        readTask = nil
        connection?.cancel()
        connection = nil
        isConnected = false
    }
}

struct TelnetTool: NetworkTool {
    let id = "telnet"
    let titleKey = L10n("tool.telnet.title")
    let subtitleKey = L10n("tool.telnet.subtitle")
    let systemImage = "terminal"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(TelnetView()) }
}

struct TelnetView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: TelnetViewModel {
        sessions.session("telnet") {
            let model = TelnetViewModel()
            model.activity = activity
            model.toolID = "telnet"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.isConnected || !viewModel.transcript.isEmpty {
                    terminalSection
                }
                Text(L10n("telnet.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.telnet.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var connectionSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("telnet.input.title"), systemImage: "network") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("telnet.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
                TextField("23", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 80)
                    .environment(\.layoutDirection, .leftToRight)
            }

            HStack {
                if viewModel.isConnected {
                    Button(L10nString("telnet.disconnect"), role: .destructive) {
                        viewModel.disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    StatusBadge(kind: .success, text: L10n("telnet.connected"))
                } else {
                    Button {
                        Task { await viewModel.connect() }
                    } label: {
                        Label(L10nString("telnet.connect"), systemImage: "bolt.horizontal.circle")
                            .font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let message = viewModel.statusMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var terminalSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("telnet.section.terminal"), systemImage: "terminal") {
            Text(viewModel.transcript.isEmpty ? " " : viewModel.transcript)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.success)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(theme.background)
                )

            HStack(spacing: Spacing.sm) {
                TextField(L10nString("telnet.input.command"), text: $viewModel.command)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.sendCommand() } }
                    .disabled(!viewModel.isConnected)
                Button {
                    Task { await viewModel.sendCommand() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isConnected)
            }
        }
    }
}
