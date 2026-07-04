import SwiftUI
import Observation
import Network
import Security

/// Details extracted from a server's TLS certificate.
struct SSLCertInfo: Equatable, Sendable {
    let host: String
    let subject: String
    let issuer: String
    let notBefore: String
    let notAfter: String
    let daysRemaining: Int?
    let chainLength: Int
    let systemTrusted: Bool
    var subjectAltNames: [String] = []
}

/// Opens a TLS connection and inspects the presented certificate chain.
protocol SSLInspecting: Sendable {
    func inspect(host: String, port: UInt16) async -> Result<SSLCertInfo, NetProbeError>
}

struct SSLInspector: SSLInspecting {
    func inspect(host: String, port: UInt16) async -> Result<SSLCertInfo, NetProbeError> {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                shot.resume(.failure(.invalidPort)); return
            }
            let cleanHost = host.trimmingCharacters(in: .whitespaces)
            guard !cleanHost.isEmpty else { shot.resume(.failure(.invalidHost)); return }

            let queue = DispatchQueue(label: "net.probe.tls")
            let tlsOptions = NWProtocolTLS.Options()

            // Inspect the chain from the verify block, then allow the
            // handshake to proceed so we can report even on trust failures.
            sec_protocol_options_set_verify_block(
                tlsOptions.securityProtocolOptions,
                { _, trustRef, complete in
                    let secTrust = sec_trust_copy_ref(trustRef).takeRetainedValue()
                    let info = Self.extract(host: cleanHost, trust: secTrust)
                    complete(true)
                    if let info { shot.resume(.success(info)) }
                },
                queue
            )

            let parameters = NWParameters(tls: tlsOptions)
            let connection = NWConnection(host: NWEndpoint.Host(cleanHost), port: nwPort, using: parameters)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                case .failed(let error), .waiting(let error):
                    connection.cancel()
                    shot.resume(.failure(.connection(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 10) {
                connection.cancel()
                shot.resume(.failure(.timeout))
            }
        }
    }

    /// Pulls subject/issuer/validity out of the evaluated trust object,
    /// using only APIs available on iOS.
    private static func extract(host: String, trust: SecTrust) -> SSLCertInfo? {
        var trustError: CFError?
        let trusted = SecTrustEvaluateWithError(trust, &trustError)

        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return nil
        }
        let subject = (SecCertificateCopySubjectSummary(leaf) as String?) ?? "—"
        var issuer = "—"
        if chain.count > 1 {
            issuer = (SecCertificateCopySubjectSummary(chain[1]) as String?) ?? "—"
        }

        // iOS has no API to read validity dates from a SecCertificate, so
        // parse them out of the DER ourselves.
        let der = SecCertificateCopyData(leaf) as Data
        let (notBefore, notAfter) = X509.validity(fromDER: der)
        let sans = X509.subjectAltNames(fromDER: der)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return SSLCertInfo(
            host: host,
            subject: subject,
            issuer: issuer,
            notBefore: notBefore.map(formatter.string(from:)) ?? "—",
            notAfter: notAfter.map(formatter.string(from:)) ?? "—",
            daysRemaining: notAfter.map { Int($0.timeIntervalSinceNow / 86_400) },
            chainLength: chain.count,
            systemTrusted: trusted,
            subjectAltNames: sans
        )
    }
}

@MainActor
@Observable
final class SSLCheckerViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(SSLCertInfo)
        case failure(String)
    }

    var host = ""
    var portText = "443"
    private(set) var output: Output = .idle

    private let inspector: any SSLInspecting

    init(inspector: any SSLInspecting = SSLInspector()) {
        self.inspector = inspector
    }

    func check() async {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            output = .failure(String(localized: "error.probe.invalidPort", bundle: .module))
            return
        }
        output = .loading
        let result = await inspector.inspect(host: trimmed, port: port)
        switch result {
        case .success(let info): output = .success(info)
        case .failure(let error): output = .failure(error.localizedDescription)
        }
    }
}

struct SSLCheckerTool: NetworkTool {
    let id = "ssl-checker"
    let titleKey = L10n("tool.ssl.title")
    let subtitleKey = L10n("tool.ssl.subtitle")
    let systemImage = "lock.shield"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(SSLCheckerView()) }
}

struct SSLCheckerView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SSLCheckerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ssl.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ssl.input.title"), systemImage: "lock.shield") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("ssl.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                TextField("443", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Button {
                Task { await viewModel.check() }
            } label: {
                Label(L10nString("ssl.action.check"), systemImage: "checkmark.shield")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            ContentUnavailableView {
                Label(L10nString("ssl.empty.title"), systemImage: "lock.shield")
            } description: {
                Text(L10n("ssl.empty.description"))
            }
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
        case .success(let info):
            resultCard(info)
        }
    }

    private func resultCard(_ info: SSLCertInfo) -> some View {
        SectionCard(title: L10n("ssl.section.certificate"), systemImage: "checkmark.seal") {
            HStack {
                StatusBadge(
                    kind: info.systemTrusted ? .success : .warning,
                    text: info.systemTrusted ? L10n("ssl.trusted") : L10n("ssl.untrusted")
                )
                Spacer()
                if let days = info.daysRemaining {
                    StatusBadge(
                        kind: days < 0 ? .danger : (days < 15 ? .warning : .info),
                        text: L10n("ssl.expiry")
                    )
                    Text(days < 0 ? L10nString("ssl.expired") : "\(days)d")
                        .font(AppTypography.monoBody)
                        .foregroundStyle(days < 0 ? theme.danger : theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Divider().overlay(theme.separator)
            ResultRow(label: L10n("ssl.result.subject"), value: info.subject, isMonospaced: false)
            ResultRow(label: L10n("ssl.result.issuer"), value: info.issuer, isMonospaced: false)
            ResultRow(label: L10n("ssl.result.notBefore"), value: info.notBefore)
            ResultRow(label: L10n("ssl.result.notAfter"), value: info.notAfter)
            ResultRow(label: L10n("ssl.result.chain"), value: String(info.chainLength))
            if !info.subjectAltNames.isEmpty {
                Divider().overlay(theme.separator)
                Text(L10n("ssl.result.sans"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(info.subjectAltNames.prefix(20).joined(separator: "\n"))
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}
