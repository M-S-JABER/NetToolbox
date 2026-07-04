import SwiftUI
import Observation

enum FTPError: LocalizedError, Equatable {
    case connectionFailed
    case loginFailed
    case passiveFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed: String(localized: "error.ftp.connection", bundle: .module)
        case .loginFailed: String(localized: "error.ftp.login", bundle: .module)
        case .passiveFailed: String(localized: "error.ftp.passive", bundle: .module)
        }
    }
}

/// FTP protocol helpers. The PASV response parser is pure and unit-tested.
enum FTP {
    /// Parses "227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)" into a data
    /// endpoint.
    static func parsePASV(_ response: String) -> (host: String, port: UInt16)? {
        guard let open = response.firstIndex(of: "("),
              let close = response[open...].firstIndex(of: ")"), open < close else { return nil }
        let inside = response[response.index(after: open)..<close]
        let numbers = inside.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 6, numbers.allSatisfy({ (0...255).contains($0) }) else { return nil }
        let host = "\(numbers[0]).\(numbers[1]).\(numbers[2]).\(numbers[3])"
        let port = UInt16(numbers[4] * 256 + numbers[5])
        return (host, port)
    }

    static func replyCode(_ reply: String) -> Int? {
        Int(reply.prefix(3))
    }
}

/// A minimal FTP client: connects, logs in, and lists a directory over a
/// passive-mode data connection. Plaintext FTP only (SFTP needs SSH).
final class FTPClient: @unchecked Sendable {
    private let control: TCPConnection

    init?(host: String, port: UInt16) {
        guard let control = TCPConnection(host: host, port: port) else { return nil }
        self.control = control
    }

    func list(user: String, password: String, path: String) async -> Result<String, FTPError> {
        if case .failure = await control.open(timeout: 8) { return .failure(.connectionFailed) }
        _ = await readReply()                                   // 220 greeting

        _ = await command("USER \(user)")
        let passReply = await command("PASS \(password)")
        if let code = FTP.replyCode(passReply), code >= 500 { return .failure(.loginFailed) }

        _ = await command("TYPE A")
        let pasvReply = await command("PASV")
        guard let endpoint = FTP.parsePASV(pasvReply),
              let data = TCPConnection(host: endpoint.host, port: endpoint.port) else {
            control.cancel()
            return .failure(.passiveFailed)
        }
        if case .failure = await data.open(timeout: 8) {
            control.cancel()
            return .failure(.passiveFailed)
        }

        let command = path.isEmpty ? "LIST" : "LIST \(path)"
        _ = await self.command(command)
        let listing = await data.receiveAll(timeout: 8)
        data.cancel()
        _ = await readReply()                                   // 226 transfer complete
        control.cancel()

        switch listing {
        case .success(let bytes):
            let text = String(decoding: bytes, as: UTF8.self)
            return .success(text)
        case .failure:
            return .success("")
        }
    }

    private func readReply() async -> String {
        if case .success(let data) = await control.receive() {
            return String(decoding: data, as: UTF8.self)
        }
        return ""
    }

    private func command(_ text: String) async -> String {
        guard let payload = (text + "\r\n").data(using: .utf8) else { return "" }
        _ = await control.send(payload)
        return await readReply()
    }
}

@MainActor
@Observable
final class FTPViewModel {
    enum Output: Equatable {
        case idle, loading
        case listing(String)
        case failure(String)
    }

    var host = ""
    var portText = "21"
    var user = "anonymous"
    var password = "anonymous@"
    var path = ""
    private(set) var output: Output = .idle

    func connect() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            output = .failure(String(localized: "error.probe.invalidPort", bundle: .module))
            return
        }
        guard let client = FTPClient(host: target, port: port) else {
            output = .failure(String(localized: "error.probe.invalidHost", bundle: .module))
            return
        }
        output = .loading
        let result = await client.list(user: user, password: password, path: path.trimmingCharacters(in: .whitespaces))
        switch result {
        case .success(let listing):
            output = .listing(listing.isEmpty ? String(localized: "ftp.empty", bundle: .module) : listing)
        case .failure(let error):
            output = .failure(error.localizedDescription)
        }
    }
}

struct FTPTool: NetworkTool {
    let id = "ftp"
    let titleKey = L10n("tool.ftp.title")
    let subtitleKey = L10n("tool.ftp.subtitle")
    let systemImage = "folder.badge.gearshape"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(FTPView()) }
}

struct FTPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = FTPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
                Text(L10n("ftp.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ftp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ftp.input.title"), systemImage: "network") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("ftp.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
                TextField("21", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 70)
                    .environment(\.layoutDirection, .leftToRight)
            }
            TextField(L10nString("ftp.input.user"), text: $viewModel.user)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            SecureField(L10nString("ftp.input.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10nString("ftp.input.path"), text: $viewModel.path)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            Button {
                Task { await viewModel.connect() }
            } label: {
                Label(L10nString("ftp.action.list"), systemImage: "folder")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("common.loading")).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .failure(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        case .listing(let text):
            SectionCard(title: L10n("ftp.section.listing"), systemImage: "list.bullet") {
                Text(text)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}
