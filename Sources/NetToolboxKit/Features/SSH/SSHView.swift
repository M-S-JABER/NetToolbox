import SwiftUI
import Observation

@MainActor
@Observable
final class SSHViewModel {
    var host = ""
    var portText = "22"
    var username = ""
    var password = ""
    var command = "uname -a"

    private(set) var isRunning = false
    private(set) var result: SSHRunResult?
    private(set) var errorMessage: String?

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = L10nString("error.probe.invalidPort")
            return
        }
        let user = username.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty else {
            errorMessage = L10nString("ssh.error.noUser")
            return
        }
        guard let client = SSHClient(host: target, port: port) else {
            errorMessage = L10nString("error.probe.invalidHost")
            return
        }

        isRunning = true
        errorMessage = nil
        result = nil
        let password = self.password
        let command = self.command

        do {
            result = try await client.run(username: user, password: password, command: command, timeout: 12)
        } catch {
            var message = error.localizedDescription
            if !client.diagnostics.isEmpty {
                message += "\n\(client.diagnostics) · stage=\(client.stage)"
            } else {
                message += "\n(stage=\(client.stage))"
            }
            errorMessage = message
        }
        isRunning = false
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

struct SSHView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SSHViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if let result = viewModel.result {
                    hostKeySection(result)
                    outputSection(result)
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

    private var connectionSection: some View {
        SectionCard(title: L10n("ssh.input.title"), systemImage: "network") {
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
                    .frame(maxWidth: 72)
                    .environment(\.layoutDirection, .leftToRight)
            }

            TextField(L10nString("ssh.input.username"), text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            SecureField(L10nString("ssh.input.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)

            TextField(L10nString("ssh.input.command"), text: $viewModel.command)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("ssh.action.run"), systemImage: "play.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning { ProgressView() }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
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
        }
    }

    private func outputSection(_ result: SSHRunResult) -> some View {
        SectionCard(title: L10n("ssh.section.output"), systemImage: "text.alignleft") {
            if let status = result.exitStatus {
                ResultRow(label: L10n("ssh.exitStatus"), value: String(status))
            }
            Text(result.output.isEmpty ? " " : result.output)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.success)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(theme.background)
                )
        }
    }
}
