import SwiftUI
import Observation

/// A live RouterOS API connection. Uses plain login (RouterOS 6.43+) over
/// the API port; the wire framing is handled by `MikroTikProtocol`.
final class MikroTikClient: @unchecked Sendable {
    private let connection: TCPConnection

    init?(host: String, port: UInt16) {
        guard let connection = TCPConnection(host: host, port: port) else { return nil }
        self.connection = connection
    }

    func connect(timeout: Double) async -> Result<Void, NetProbeError> {
        await connection.open(timeout: timeout)
    }

    /// Sends a sentence and reads reply sentences up to the closing `!done`.
    func send(words: [String], timeout: Double) async -> Result<[[String]], NetProbeError> {
        let payload = MikroTikProtocol.encodeSentence(words)
        if case .failure(let error) = await connection.send(payload) {
            return .failure(error)
        }
        return await readUntilDone(timeout: timeout)
    }

    private func readUntilDone(timeout: Double) async -> Result<[[String]], NetProbeError> {
        var buffer = Data()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        while clock.now < deadline {
            let result = await connection.receive()
            switch result {
            case .success(let chunk):
                if chunk.isEmpty {
                    return .success(MikroTikProtocol.decodeSentences(buffer))
                }
                buffer.append(chunk)
                let sentences = MikroTikProtocol.decodeSentences(buffer)
                let finished = sentences.contains {
                    ($0.first?.hasPrefix("!done") ?? false) || ($0.first?.hasPrefix("!fatal") ?? false)
                }
                if finished { return .success(sentences) }
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(MikroTikProtocol.decodeSentences(buffer))
    }

    /// Logs in with plain credentials. Returns an error message on failure.
    func login(user: String, password: String, timeout: Double) async -> String? {
        let reply = await send(
            words: ["/login", "=name=\(user)", "=password=\(password)"],
            timeout: timeout
        )
        switch reply {
        case .success(let sentences):
            if let trap = sentences.first(where: { $0.first == "!trap" }) {
                let message = trap.first(where: { $0.hasPrefix("=message=") })?
                    .replacingOccurrences(of: "=message=", with: "")
                return message ?? String(localized: "error.mikrotik.login", bundle: .module)
            }
            return nil
        case .failure(let error):
            return error.localizedDescription
        }
    }

    func cancel() { connection.cancel() }
}

@MainActor
@Observable
final class MikroTikViewModel {
    var host = ""
    var portText = "8728"
    var user = "admin"
    var password = ""
    var command = "/system/resource/print"

    private(set) var isConnected = false
    private(set) var statusMessage: String?
    private(set) var replies: [String] = []
    private(set) var isBusy = false

    private var client: MikroTikClient?

    func connect() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            statusMessage = String(localized: "error.probe.invalidPort", bundle: .module)
            return
        }
        disconnect()
        isBusy = true
        statusMessage = nil
        replies = []

        guard let client = MikroTikClient(host: target, port: port) else {
            statusMessage = String(localized: "error.probe.invalidHost", bundle: .module)
            isBusy = false
            return
        }
        if case .failure(let error) = await client.connect(timeout: 8) {
            statusMessage = error.localizedDescription
            isBusy = false
            return
        }
        if let loginError = await client.login(user: user, password: password, timeout: 8) {
            statusMessage = loginError
            client.cancel()
            isBusy = false
            return
        }
        self.client = client
        isConnected = true
        isBusy = false
    }

    func runCommand() async {
        guard let client, isConnected else { return }
        let words = command
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard !words.isEmpty else { return }
        isBusy = true
        let result = await client.send(words: words, timeout: 8)
        switch result {
        case .success(let sentences):
            replies = format(sentences)
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func format(_ sentences: [[String]]) -> [String] {
        var lines: [String] = []
        for sentence in sentences {
            guard let type = sentence.first else { continue }
            if type == "!re" {
                for attribute in sentence.dropFirst() {
                    lines.append(attribute.hasPrefix("=") ? String(attribute.dropFirst()) : attribute)
                }
                lines.append("──────────")
            } else if type == "!trap" {
                let message = sentence.first { $0.hasPrefix("=message=") } ?? "!trap"
                lines.append("⚠︎ " + message.replacingOccurrences(of: "=message=", with: ""))
            }
        }
        if lines.isEmpty { lines.append(String(localized: "mikrotik.done", bundle: .module)) }
        return lines
    }

    func disconnect() {
        client?.cancel()
        client = nil
        isConnected = false
    }
}

struct MikroTikAPITool: NetworkTool {
    let id = "mikrotik-api"
    let titleKey = L10n("tool.mikrotik.title")
    let subtitleKey = L10n("tool.mikrotik.subtitle")
    let systemImage = "point.3.connected.trianglepath.dotted"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(MikroTikAPIView()) }
}

struct MikroTikAPIView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = MikroTikViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.isConnected {
                    commandSection
                }
                if !viewModel.replies.isEmpty {
                    outputSection
                }
                Text(L10n("mikrotik.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.mikrotik.title")))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { viewModel.disconnect() }
    }

    private var connectionSection: some View {
        SectionCard(title: L10n("mikrotik.input.title"), systemImage: "network") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("mikrotik.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                TextField("8728", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
            }
            TextField(L10nString("mikrotik.input.user"), text: $viewModel.user)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            SecureField(L10nString("mikrotik.input.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)

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
                    .disabled(viewModel.isBusy)
                }
                if viewModel.isBusy { ProgressView() }
            }

            if let message = viewModel.statusMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var commandSection: some View {
        SectionCard(title: L10n("mikrotik.section.command"), systemImage: "terminal") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("mikrotik.input.command"), text: $viewModel.command)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.runCommand() } }
                Button {
                    Task { await viewModel.runCommand() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }
        }
    }

    private var outputSection: some View {
        SectionCard(title: L10n("mikrotik.section.output"), systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(viewModel.replies.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(line.hasPrefix("⚠︎") ? theme.danger : theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }
}
