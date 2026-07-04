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

/// One line in the terminal transcript.
struct MikroTikLine: Identifiable {
    enum Role { case prompt, header, attribute, trap, info }
    let id: Int
    let role: Role
    let key: String?
    let text: String
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
    private(set) var transcript: [MikroTikLine] = []
    private(set) var isBusy = false

    private var client: MikroTikClient?
    private var lineCounter = 0

    /// The whole transcript as plain text, for copy / share.
    var transcriptText: String {
        transcript.map { line in
            switch line.role {
            case .prompt: return "> \(line.text)"
            case .header: return "── \(line.text) ──"
            case .attribute: return line.key.map { "  \($0): \(line.text)" } ?? "  \(line.text)"
            case .trap: return "! \(line.text)"
            case .info: return line.text
            }
        }.joined(separator: "\n")
    }

    private func append(_ role: MikroTikLine.Role, key: String? = nil, _ text: String) {
        transcript.append(MikroTikLine(id: lineCounter, role: role, key: key, text: text))
        lineCounter += 1
    }

    func connect() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            statusMessage = String(localized: "error.probe.invalidPort", bundle: .module)
            return
        }
        disconnect()
        isBusy = true
        statusMessage = nil

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
        append(.info, "\(L10nString("mikrotik.connected")) \(user)@\(target)")
    }

    func run(_ commandText: String) async {
        command = commandText
        await runCommand()
    }

    func runCommand() async {
        guard let client, isConnected else { return }
        let words = command
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard !words.isEmpty else { return }
        append(.prompt, command)
        isBusy = true
        let result = await client.send(words: words, timeout: 8)
        switch result {
        case .success(let sentences):
            format(sentences)
        case .failure(let error):
            append(.trap, error.localizedDescription)
        }
        isBusy = false
    }

    /// Turns reply sentences into structured transcript lines: each `!re`
    /// becomes a numbered record with aligned `key: value` rows, traps show
    /// as errors, and `!done` reports the record count.
    private func format(_ sentences: [[String]]) {
        var recordNumber = 0
        for sentence in sentences {
            guard let type = sentence.first else { continue }
            switch type {
            case "!re":
                recordNumber += 1
                append(.header, "\(L10nString("mikrotik.record")) \(recordNumber)")
                for attribute in sentence.dropFirst() {
                    guard attribute.hasPrefix("=") else {
                        append(.attribute, attribute)
                        continue
                    }
                    let body = attribute.dropFirst()
                    if let equals = body.firstIndex(of: "=") {
                        append(.attribute, key: String(body[..<equals]), String(body[body.index(after: equals)...]))
                    } else {
                        append(.attribute, String(body))
                    }
                }
            case "!trap", "!fatal":
                let message = sentence.first { $0.hasPrefix("=message=") }?
                    .replacingOccurrences(of: "=message=", with: "") ?? type
                append(.trap, message)
            case "!done":
                append(.info, "\(L10nString("mikrotik.done")) · \(recordNumber) \(L10nString("mikrotik.records"))")
            default:
                break
            }
        }
    }

    func clearTranscript() { transcript.removeAll() }

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

    private let quickCommands = [
        "/system/resource/print",
        "/system/identity/print",
        "/interface/print",
        "/ip/address/print",
        "/ip/route/print",
        "/ip/dhcp-server/lease/print",
        "/system/clock/print",
        "/log/print",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.isConnected {
                    quickSection
                    terminalSection
                    commandBar
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

    private var quickSection: some View {
        SectionCard(title: L10n("mikrotik.quick"), systemImage: "bolt.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(quickCommands, id: \.self) { cmd in
                        Button {
                            Task { await viewModel.run(cmd) }
                        } label: {
                            Text(cmd)
                                .font(AppTypography.monoCaption)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isBusy)
                    }
                }
            }
        }
    }

    private var terminalSection: some View {
        SectionCard(title: L10n("mikrotik.section.terminal"), systemImage: "terminal") {
            HStack {
                Spacer()
                if !viewModel.transcript.isEmpty {
                    ShareLink(item: viewModel.transcriptText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        viewModel.clearTranscript()
                    } label: {
                        Label(L10nString("mikrotik.clear"), systemImage: "trash")
                            .font(AppTypography.caption)
                    }
                    .tint(theme.danger)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(viewModel.transcript) { line in
                            terminalRow(line).id(line.id)
                        }
                        Color.clear.frame(height: 1).id(-1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .environment(\.layoutDirection, .leftToRight)
                }
                .frame(minHeight: 220, maxHeight: 420)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .onChange(of: viewModel.transcript.count) {
                    withAnimation { proxy.scrollTo(-1, anchor: .bottom) }
                }
            }
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func terminalRow(_ line: MikroTikLine) -> some View {
        switch line.role {
        case .prompt:
            Text("❯ \(line.text)")
                .font(AppTypography.monoCaption.weight(.semibold))
                .foregroundStyle(theme.accent)
        case .header:
            Text(line.text.uppercased())
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.mono)
                .padding(.top, 4)
        case .attribute:
            HStack(alignment: .top, spacing: Spacing.sm) {
                if let key = line.key {
                    Text(key)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 130, alignment: .leading)
                }
                Text(line.text)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
        case .trap:
            Text("⚠︎ \(line.text)")
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.danger)
        case .info:
            Text(line.text)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.success)
        }
    }

    private var commandBar: some View {
        SectionCard(title: L10n("mikrotik.section.command"), systemImage: "chevron.left.forwardslash.chevron.right") {
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
}
