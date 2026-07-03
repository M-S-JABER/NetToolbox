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

    private(set) var output: String?
    private(set) var errorMessage: String?
    private(set) var isBusy = false

    private let runner: any SSHRunning

    init(runner: any SSHRunning = CitadelSSHRunner()) {
        self.runner = runner
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = Int(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = String(localized: "error.probe.invalidPort", bundle: .module)
            return
        }
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        guard !trimmedCommand.isEmpty else { return }

        isBusy = true
        errorMessage = nil
        output = nil
        do {
            output = try await runner.execute(
                host: target,
                port: port,
                username: username.trimmingCharacters(in: .whitespaces),
                password: password,
                command: trimmedCommand
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}

struct SSHTool: NetworkTool {
    let id = "ssh"
    let titleKey = L10n("tool.ssh.title")
    let subtitleKey = L10n("tool.ssh.subtitle")
    let systemImage = "apple.terminal"
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
                commandSection
                if let output = viewModel.output {
                    outputSection(output)
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
                TextField("22", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 80)
                    .environment(\.layoutDirection, .leftToRight)
            }
            TextField(L10nString("ssh.input.user"), text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            SecureField(L10nString("ssh.input.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var commandSection: some View {
        SectionCard(title: L10n("ssh.section.command"), systemImage: "terminal") {
            HStack(spacing: Spacing.sm) {
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
                    if viewModel.isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }
            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func outputSection(_ output: String) -> some View {
        SectionCard(title: L10n("ssh.section.output"), systemImage: "text.alignleft") {
            Text(output.isEmpty ? L10nString("ssh.noOutput") : output)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small).fill(theme.background)
                )
            HStack {
                Spacer()
                CopyButton(value: output)
            }
        }
    }
}
