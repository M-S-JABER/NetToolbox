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
    var keyBits: Int?
    var keyType: String?
}

/// Pure TLS "grade" from the negotiated protocols and certificate — mirrors
/// the spirit of SSL Labs, scoped to what iOS can observe natively.
enum TLSAudit {
    static func grade(protocols: [String], daysRemaining: Int?, trusted: Bool,
                      keyBits: Int?, keyType: String?) -> (grade: String, notes: [String]) {
        if let days = daysRemaining, days < 0 {
            return ("F", ["ssl.note.expired"])
        }
        let hasLegacy = protocols.contains("TLS 1.0") || protocols.contains("TLS 1.1")
        let hasModern = protocols.contains("TLS 1.2") || protocols.contains("TLS 1.3")
        let has13 = protocols.contains("TLS 1.3")
        guard hasModern else { return ("F", ["ssl.note.noModern"]) }

        var notes: [String] = []
        let weakKey: Bool = {
            guard let bits = keyBits else { return false }
            return keyType == "EC" ? bits < 256 : bits < 2048
        }()
        if weakKey { notes.append("ssl.note.weakKey") }

        var letter = has13 ? "A" : "B"
        if hasLegacy { letter = "C"; notes.append("ssl.note.legacy") }
        if weakKey { letter = "F" }
        if let days = daysRemaining, days < 15 { notes.append("ssl.note.expiring") }
        if !trusted { notes.append("ssl.note.untrusted"); return ("T", notes) }
        if letter == "A", !hasLegacy, (daysRemaining ?? 999) > 15,
           (keyBits ?? 4096) >= (keyType == "EC" ? 256 : 2048) {
            letter = "A+"
        }
        return (letter, notes)
    }
}

/// Opens a TLS connection and inspects the presented certificate chain.
protocol SSLInspecting: Sendable {
    func inspect(host: String, port: UInt16) async -> Result<SSLCertInfo, NetProbeError>
    /// Which of TLS 1.0–1.3 the server completes a handshake with.
    func probeProtocols(host: String, port: UInt16) async -> [String]
}

extension SSLInspecting {
    func probeProtocols(host: String, port: UInt16) async -> [String] { [] }
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

        var keyBits: Int?
        var keyType: String?
        if let key = SecCertificateCopyKey(leaf),
           let attrs = SecKeyCopyAttributes(key) as? [String: Any] {
            keyBits = attrs[kSecAttrKeySizeInBits as String] as? Int
            if let type = attrs[kSecAttrKeyType as String] as? String {
                if type == (kSecAttrKeyTypeRSA as String) { keyType = "RSA" }
                else if type == (kSecAttrKeyTypeECSECPrimeRandom as String) { keyType = "EC" }
                else { keyType = type }
            }
        }

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
            subjectAltNames: sans,
            keyBits: keyBits,
            keyType: keyType
        )
    }

    /// Probes TLS 1.0–1.3 concurrently and returns the versions that complete
    /// a handshake. Certificate trust is ignored here — only version support
    /// matters.
    func probeProtocols(host: String, port: UInt16) async -> [String] {
        let cleanHost = host.trimmingCharacters(in: .whitespaces)
        guard NWEndpoint.Port(rawValue: port) != nil, !cleanHost.isEmpty else { return [] }
        let versions: [(String, tls_protocol_version_t)] = [
            ("TLS 1.0", .TLSv10), ("TLS 1.1", .TLSv11),
            ("TLS 1.2", .TLSv12), ("TLS 1.3", .TLSv13),
        ]
        let supported = await withTaskGroup(of: (Int, String)?.self) { group in
            for (index, entry) in versions.enumerated() {
                group.addTask {
                    await Self.supports(host: cleanHost, port: port, version: entry.1) ? (index, entry.0) : nil
                }
            }
            var found: [(Int, String)] = []
            for await result in group { if let result { found.append(result) } }
            return found
        }
        return supported.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private static func supports(host: String, port: UInt16, version: tls_protocol_version_t) async -> Bool {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { shot.resume(false); return }
            let queue = DispatchQueue(label: "net.probe.tlsver")
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, version)
            sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, version)
            sec_protocol_options_set_verify_block(
                tls.securityProtocolOptions, { _, _, complete in complete(true) }, queue
            )
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort,
                                          using: NWParameters(tls: tls))
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: connection.cancel(); shot.resume(true)
                case .failed, .waiting: connection.cancel(); shot.resume(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 8) { connection.cancel(); shot.resume(false) }
        }
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

    struct AuditResult: Equatable, Sendable {
        let grade: String
        let protocols: [String]
        let notes: [String]
    }

    var host = ""
    var portText = "443"
    private(set) var output: Output = .idle
    private(set) var audit: AuditResult?

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
        audit = nil
        let result = await inspector.inspect(host: trimmed, port: port)
        switch result {
        case .success(let info):
            output = .success(info)
            let protocols = await inspector.probeProtocols(host: trimmed, port: port)
            let graded = TLSAudit.grade(
                protocols: protocols, daysRemaining: info.daysRemaining,
                trusted: info.systemTrusted, keyBits: info.keyBits, keyType: info.keyType
            )
            audit = AuditResult(grade: graded.grade, protocols: protocols, notes: graded.notes)
        case .failure(let error):
            output = .failure(error.localizedDescription)
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

@MainActor
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
            if let audit = viewModel.audit {
                gradeCard(audit)
            }
            resultCard(info)
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A+", "A": theme.success
        case "B", "C": theme.warning
        default: theme.danger   // F, T
        }
    }

    private func gradeCard(_ audit: SSLCheckerViewModel.AuditResult) -> some View {
        SectionCard(title: L10n("ssl.section.grade"), systemImage: "rosette") {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text(audit.grade)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor(audit.grade))
                    .frame(minWidth: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n("ssl.grade.protocols"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(audit.protocols.isEmpty ? "—" : audit.protocols.joined(separator: " · "))
                        .font(AppTypography.monoBody)
                        .foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
            }
            ForEach(audit.notes, id: \.self) { note in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning).font(.caption)
                    Text(L10n(note)).font(AppTypography.footnote).foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            if let bits = info.keyBits {
                ResultRow(label: L10n("ssl.result.key"), value: "\(info.keyType ?? "?") \(bits)-bit")
            }
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
