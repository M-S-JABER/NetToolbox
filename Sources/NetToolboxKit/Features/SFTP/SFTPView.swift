import SwiftUI
import Observation

@MainActor
@Observable
final class SFTPViewModel {
    var host = ""
    var portText = "22"
    var user = "admin"
    var password = ""
    var privateKey = ""
    var useKey = false
    var path = "."

    private(set) var entries: [SFTPEntry] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var downloadURL: URL?
    private(set) var hasListed = false

    private func makeAuth() -> SSHAuth? {
        if useKey {
            guard let key = SSHPrivateKey(pem: privateKey) else { return nil }
            return .key(key)
        }
        return .password(password)
    }

    private func filePath(_ name: String) -> String {
        path == "." || path.isEmpty ? name : "\(path)/\(name)"
    }

    func list() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = L10nString("error.probe.invalidPort")
            return
        }
        guard let auth = makeAuth() else {
            errorMessage = L10nString("sftp.error.key")
            return
        }
        guard let client = SSHClient(host: target, port: port) else {
            errorMessage = L10nString("error.probe.invalidHost")
            return
        }
        isBusy = true
        errorMessage = nil
        downloadURL = nil
        do {
            entries = try await client.listDirectory(username: user, auth: auth, path: path, timeout: 12)
            hasListed = true
        } catch {
            errorMessage = error.localizedDescription + "\n\(client.diagnostics) · stage=\(client.stage)"
        }
        isBusy = false
    }

    func open(_ entry: SFTPEntry) async {
        if entry.isDirectory {
            path = filePath(entry.name)
            await list()
        } else {
            await download(entry)
        }
    }

    private func download(_ entry: SFTPEntry) async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)),
              let auth = makeAuth(),
              let client = SSHClient(host: target, port: port) else { return }
        isBusy = true
        errorMessage = nil
        do {
            let data = try await client.downloadFile(username: user, auth: auth, path: filePath(entry.name), timeout: 20)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(entry.name)
            try data.write(to: url)
            downloadURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func goUp() async {
        guard path != "." && !path.isEmpty else { return }
        if let slash = path.lastIndex(of: "/") {
            path = String(path[..<slash])
        } else {
            path = "."
        }
        await list()
    }
}

struct SFTPTool: NetworkTool {
    let id = "sftp"
    let titleKey = L10n("tool.sftp.title")
    let subtitleKey = L10n("tool.sftp.subtitle")
    let systemImage = "folder.badge.gearshape"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SFTPView()) }
}

@MainActor
struct SFTPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SFTPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.hasListed {
                    filesSection
                }
                if let url = viewModel.downloadURL {
                    downloadSection(url)
                }
                Text(L10n("sftp.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.sftp.title")))
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
                    .frame(maxWidth: 64)
                    .environment(\.layoutDirection, .leftToRight)
            }
            TextField(L10nString("ssh.input.username"), text: $viewModel.user)
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
            } else {
                SecureField(L10nString("ssh.input.password"), text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .environment(\.layoutDirection, .leftToRight)
            }

            HStack(spacing: Spacing.sm) {
                TextField(L10nString("sftp.input.path"), text: $viewModel.path)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    Task { await viewModel.list() }
                } label: {
                    Label(L10nString("sftp.action.list"), systemImage: "folder")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }

            if viewModel.isBusy { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var filesSection: some View {
        SectionCard(title: L10n("sftp.section.files"), systemImage: "list.bullet") {
            HStack {
                Text(viewModel.path)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                Button {
                    Task { await viewModel.goUp() }
                } label: {
                    Label(L10nString("sftp.action.up"), systemImage: "arrow.up")
                        .font(AppTypography.caption)
                }
                .disabled(viewModel.isBusy)
            }
            Divider().overlay(theme.separator)

            if viewModel.entries.isEmpty {
                Text(L10n("sftp.empty"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(viewModel.entries) { entry in
                    Button {
                        Task { await viewModel.open(entry) }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                                .foregroundStyle(entry.isDirectory ? theme.accent : theme.textSecondary)
                                .frame(width: 24)
                            Text(entry.name)
                                .font(AppTypography.body)
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .environment(\.layoutDirection, .leftToRight)
                            Spacer()
                            if entry.isDirectory {
                                Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                            } else {
                                Text(byteSize(entry.size))
                                    .font(AppTypography.monoCaption)
                                    .foregroundStyle(theme.textSecondary)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }

    private func downloadSection(_ url: URL) -> some View {
        SectionCard(title: L10n("sftp.download"), systemImage: "arrow.down.circle") {
            HStack(spacing: Spacing.md) {
                Image(systemName: "doc.fill").foregroundStyle(theme.accent)
                Text(url.lastPathComponent)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private func byteSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
