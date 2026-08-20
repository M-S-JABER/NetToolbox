import SwiftUI
import Observation

@MainActor
@Observable
final class SSHViewModel {
    enum Mode: Hashable { case command, shell }

    var host = ""
    var portText = "22"
    var username = ""
    var password = ""
    var privateKey = ""
    var useKey = false
    var command = "uname -a"
    var mode: Mode = .command

    private(set) var isRunning = false
    private(set) var result: SSHRunResult?
    private(set) var errorMessage: String?

    // Host-key trust-on-first-use.
    var knownHosts: KnownHostsStore?
    private(set) var hostKeyTrust: KnownHostsStore.Trust?
    private var lastFingerprint = ""

    // Interactive shell state.
    private(set) var shellConnected = false {
        didSet {
            guard !toolID.isEmpty, oldValue != shellConnected else { return }
            if shellConnected { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var shellTranscript = ""
    var shellInput = ""
    var activity: ActivityCenter?
    var toolID = ""
    private var shellClient: SSHClient?
    private var readTask: Task<Void, Never>?

    private func makeAuth() -> SSHAuth? {
        if useKey {
            do {
                return .key(try SSHPrivateKey(parsing: privateKey))
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
        }
        return .password(password)
    }

    /// Compares the presented host key against what we remember (TOFU).
    private func evaluateTrust(fingerprint: String) {
        lastFingerprint = fingerprint
        let port = portText.trimmingCharacters(in: .whitespaces)
        hostKeyTrust = knownHosts?.evaluate(host: host, port: port, fingerprint: fingerprint)
    }

    /// Accept a changed host key after the user confirms it.
    func acceptChangedKey() {
        guard !lastFingerprint.isEmpty else { return }
        knownHosts?.accept(host: host, port: portText.trimmingCharacters(in: .whitespaces), fingerprint: lastFingerprint)
        hostKeyTrust = .known
    }

    private func makeClient() -> (SSHClient, SSHAuth)? {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { errorMessage = L10nString("error.probe.invalidHost"); return nil }
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = L10nString("error.probe.invalidPort"); return nil
        }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = L10nString("ssh.error.noUser"); return nil
        }
        guard let auth = makeAuth() else {
            if errorMessage == nil { errorMessage = L10nString("sftp.error.key") }
            return nil
        }
        guard let client = SSHClient(host: target, port: port) else {
            errorMessage = L10nString("error.probe.invalidHost"); return nil
        }
        return (client, auth)
    }

    // MARK: Command mode

    func run() async {
        errorMessage = nil
        result = nil
        hostKeyTrust = nil
        guard let (client, auth) = makeClient() else { return }
        isRunning = true
        let user = username.trimmingCharacters(in: .whitespaces)
        let command = self.command
        do {
            let runResult = try await client.run(username: user, auth: auth, command: command, timeout: 12)
            result = runResult
            evaluateTrust(fingerprint: runResult.fingerprint)
        } catch {
            errorMessage = error.localizedDescription + "\n\(client.diagnostics) · stage=\(client.stage)"
        }
        isRunning = false
    }

    // MARK: Shell mode

    func connectShell() async {
        errorMessage = nil
        shellTranscript = ""
        hostKeyTrust = nil
        guard let (client, auth) = makeClient() else { return }
        isRunning = true
        let user = username.trimmingCharacters(in: .whitespaces)
        do {
            try await client.openShell(username: user, auth: auth, timeout: 12)
            evaluateTrust(fingerprint: client.fingerprint)
            shellClient = client
            shellConnected = true
            startReading(client)
        } catch {
            errorMessage = error.localizedDescription + "\n\(client.diagnostics) · stage=\(client.stage)"
        }
        isRunning = false
    }

    private func startReading(_ client: SSHClient) {
        readTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let chunk = try await client.readShellChunk() else { break }
                    await MainActor.run { self?.shellTranscript.append(chunk) }
                } catch {
                    break
                }
            }
            await MainActor.run { self?.shellConnected = false }
        }
    }

    func sendShell() async {
        guard let client = shellClient else { return }
        let line = shellInput + "\n"
        shellInput = ""
        try? await client.sendShell(line)
    }

    func disconnectShell() {
        readTask?.cancel()
        readTask = nil
        shellClient?.close()
        shellClient = nil
        shellConnected = false
    }
}

struct SSHTool: NetworkTool {
    let id = "ssh"
    let titleKey = L10n("tool.ssh.title")
    let subtitleKey = L10n("tool.ssh.subtitle")
    let systemImage = "terminal.fill"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SSHView()) }
}

@MainActor
struct SSHView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity
    @Environment(SSHProfilesStore.self) private var profiles
    @Environment(KnownHostsStore.self) private var knownHosts

    private var viewModel: SSHViewModel {
        sessions.session("ssh") {
            let model = SSHViewModel()
            model.activity = activity
            model.toolID = "ssh"
            model.knownHosts = knownHosts
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                modeSection
                if viewModel.mode == .command {
                    SectionCard(title: L10n("ssh.section.command"), systemImage: "chevron.left.forwardslash.chevron.right") {
                        runBar
                        if viewModel.isRunning { ProgressView() }
                    }
                    if let result = viewModel.result {
                        hostKeySection(result)
                        outputSection(result)
                    }
                } else {
                    shellSection
                }
                Text(L10n("ssh.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ssh.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var profilesMenu: some View {
        Menu {
            if profiles.profiles.isEmpty {
                Text(L10n("ssh.profiles.empty"))
            } else {
                Section(L10nString("ssh.profiles.saved")) {
                    ForEach(profiles.profiles) { profile in
                        Button { load(profile) } label: { Text(profile.displayName) }
                    }
                }
            }
            Divider()
            Button {
                saveProfile()
            } label: {
                Label(L10nString("ssh.profiles.save"), systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "person.crop.circle.badge.plus")
                .foregroundStyle(theme.accent)
        }
    }

    private func load(_ profile: SSHProfilesStore.Profile) {
        viewModel.host = profile.host
        viewModel.portText = profile.port
        viewModel.username = profile.username
        viewModel.password = profile.password
        viewModel.useKey = profile.usesKey
        viewModel.privateKey = profile.privateKey
    }

    private func saveProfile() {
        var profile = SSHProfilesStore.Profile()
        profile.host = viewModel.host
        profile.port = viewModel.portText
        profile.username = viewModel.username
        profile.password = viewModel.password
        profile.usesKey = viewModel.useKey
        profile.privateKey = viewModel.privateKey
        profiles.save(profile)
    }

    private var connectionSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("ssh.input.title"), systemImage: "network") {
            HStack {
                Text(L10n("ssh.profiles.title"))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                profilesMenu
            }
            HStack(spacing: Spacing.md) {
                TextField(L10nString("ssh.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
                TextField("22", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 64)
                    .environment(\.layoutDirection, .leftToRight)
            }

            TextField(L10nString("ssh.input.username"), text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            Picker(L10nString("ssh.auth.mode"), selection: $viewModel.useKey) {
                Text(L10n("ssh.auth.password")).tag(false)
                Text(L10n("ssh.auth.key")).tag(true)
            }
            .pickerStyle(.segmented)

            if viewModel.useKey {
                TextEditor(text: $viewModel.privateKey)
                    .font(AppTypography.monoCaption)
                    .frame(minHeight: 90)
                    .environment(\.layoutDirection, .leftToRight)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small).strokeBorder(theme.separator)
                    )
                Text(L10n("ssh.key.hint"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                SecureField(L10nString("ssh.input.password"), text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .environment(\.layoutDirection, .leftToRight)
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var modeSection: some View {
        @Bindable var viewModel = viewModel
        return Picker(L10nString("ssh.mode.title"), selection: $viewModel.mode) {
            Text(L10n("ssh.mode.command")).tag(SSHViewModel.Mode.command)
            Text(L10n("ssh.mode.shell")).tag(SSHViewModel.Mode.shell)
        }
        .pickerStyle(.segmented)
    }

    private func hostKeySection(_ result: SSHRunResult) -> some View {
        SectionCard(title: L10n("ssh.section.hostKey"), systemImage: "key.fill") {
            ResultRow(label: L10n("ssh.hostKey.type"), value: result.hostKeyType)
            ResultRow(label: L10n("ssh.hostKey.fingerprint"), value: result.fingerprint)
            HStack(spacing: Spacing.sm) {
                Image(systemName: result.hostKeyVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(result.hostKeyVerified ? theme.success : theme.warning)
                Text(L10n(result.hostKeyVerified ? "ssh.hostKey.verified" : "ssh.hostKey.unverified"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(result.hostKeyVerified ? theme.success : theme.warning)
            }
            trustRow
        }
    }

    /// Trust-on-first-use status: new host, matches the remembered key, or a
    /// mismatch (with a button to accept the new key).
    @ViewBuilder
    private var trustRow: some View {
        if let trust = viewModel.hostKeyTrust {
            Divider().overlay(theme.separator)
            switch trust {
            case .new:
                trustLine("info.circle", L10n("ssh.hostKey.trust.new"), theme.textSecondary)
            case .known:
                trustLine("checkmark.seal.fill", L10n("ssh.hostKey.trust.known"), theme.success)
            case .changed:
                trustLine("exclamationmark.triangle.fill", L10n("ssh.hostKey.trust.changed"), theme.danger)
                Button {
                    viewModel.acceptChangedKey()
                } label: {
                    Label(L10nString("ssh.hostKey.acceptNew"), systemImage: "key.fill")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
                .tint(theme.danger)
            }
        }
    }

    private func trustLine(_ icon: String, _ text: LocalizedStringResource, _ color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(AppTypography.footnote)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func outputSection(_ result: SSHRunResult) -> some View {
        SectionCard(title: L10n("ssh.section.output"), systemImage: "text.alignleft") {
            if let status = result.exitStatus {
                ResultRow(label: L10n("ssh.exitStatus"), value: String(status))
            }
            terminalText(result.output.isEmpty ? " " : result.output)
        }
    }

    @ViewBuilder
    private var shellSection: some View {
        @Bindable var viewModel = viewModel
        SectionCard(title: L10n("ssh.mode.shell"), systemImage: "terminal") {
            if viewModel.shellConnected {
                trustRow
                terminalText(viewModel.shellTranscript.isEmpty ? " " : viewModel.shellTranscript)
                HStack(spacing: Spacing.sm) {
                    TextField(L10nString("ssh.shell.input"), text: $viewModel.shellInput)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                        .onSubmit { Task { await viewModel.sendShell() } }
                    Button {
                        Task { await viewModel.sendShell() }
                    } label: {
                        Image(systemName: "return")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(L10nString("ssh.shell.disconnect"), role: .destructive) {
                    viewModel.disconnectShell()
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await viewModel.connectShell() }
                } label: {
                    Label(L10nString("ssh.shell.connect"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
                if viewModel.isRunning { ProgressView() }
            }
        }
    }

    private func terminalText(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.monoCaption)
            .foregroundStyle(theme.success)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .textSelection(.enabled)
            .environment(\.layoutDirection, .leftToRight)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(theme.background)
            )
    }
}

private extension SSHView {
    // Command run button lives under the mode picker in command mode.
    var runBar: some View {
        @Bindable var viewModel = viewModel
        return HStack(spacing: Spacing.sm) {
            TextField(L10nString("ssh.input.command"), text: $viewModel.command)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await viewModel.run() } }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("ssh.action.run"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)
        }
    }
}
