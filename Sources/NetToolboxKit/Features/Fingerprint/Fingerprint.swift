import SwiftUI
import Observation

// MARK: - Engine

/// Heuristic service identification from a connection banner. Pure + tested.
enum ServiceFingerprint {
    struct Match: Equatable, Sendable {
        let service: String
        let product: String
    }

    static func identify(banner: String, port: UInt16) -> Match {
        let text = banner
        let lower = text.lowercased()

        if text.hasPrefix("SSH-") {
            // e.g. "SSH-2.0-OpenSSH_8.9p1 Ubuntu"
            let parts = text.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)
            let software = parts.count >= 3 ? String(parts[2]) : ""
            return Match(service: "SSH", product: firstLine(software))
        }
        if lower.contains("http/") {
            return Match(service: "HTTP", product: headerValue(text, "server") ?? firstLine(text))
        }
        if lower.contains("rtsp/1.0") {
            return Match(service: "RTSP", product: headerValue(text, "server") ?? "")
        }
        if text.hasPrefix("220"), lower.contains("ftp") || lower.contains("vsftpd") || lower.contains("filezilla") {
            return Match(service: "FTP", product: firstLine(text).replacingOccurrences(of: "220 ", with: ""))
        }
        if lower.contains("esmtp") || (text.hasPrefix("220") && lower.contains("smtp")) {
            return Match(service: "SMTP", product: firstLine(text).replacingOccurrences(of: "220 ", with: ""))
        }
        if text.hasPrefix("* OK"), lower.contains("imap") {
            return Match(service: "IMAP", product: firstLine(text))
        }
        if text.hasPrefix("+OK") {
            return Match(service: "POP3", product: firstLine(text))
        }
        if text.contains("+PONG") || lower.contains("-err") || lower.contains("redis_version") {
            return Match(service: "Redis", product: value(after: "redis_version:", in: text))
        }
        if lower.contains("mysql") || lower.contains("mariadb") {
            return Match(service: "MySQL", product: firstLine(text))
        }
        // Fallback to the well-known name for the port.
        return Match(service: PortDatabase.serviceName(for: Int(port)) ?? "unknown", product: firstLine(text))
    }

    // MARK: Helpers

    static func firstLine(_ text: String) -> String {
        (text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text)
            .trimmingCharacters(in: .whitespaces)
    }

    static func headerValue(_ text: String, _ name: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == name.lowercased() {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func value(after marker: String, in text: String) -> String {
        guard let range = text.range(of: marker) else { return "" }
        let rest = text[range.upperBound...]
        return firstLine(String(rest))
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class FingerprintViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(service: String, product: String, banner: String)
        case failure(String)
    }

    var host = ""
    var portText = "22"
    private(set) var output: Output = .idle

    private let banner = BannerGrabService()
    private let httpPorts: Set<UInt16> = [80, 443, 8000, 8008, 8080, 8443]

    func run() async {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else {
            output = .failure(L10nString("fingerprint.error.port")); return
        }
        output = .loading
        let probe = httpPorts.contains(port) ? "GET / HTTP/1.0" : ""
        let tls = port == 443 || port == 8443
        switch await banner.grab(host: trimmed, port: port, probe: probe, tls: tls, timeout: 6) {
        case .success(let text):
            let match = ServiceFingerprint.identify(banner: text, port: port)
            output = .success(service: match.service, product: match.product, banner: text)
        case .failure(let error):
            output = .failure(error.description)
        }
    }
}

// MARK: - Tool

struct FingerprintTool: NetworkTool {
    let id = "fingerprint"
    let titleKey = L10n("tool.fingerprint.title")
    let subtitleKey = L10n("tool.fingerprint.subtitle")
    let systemImage = "person.text.rectangle"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(FingerprintView()) }
}

// MARK: - View

@MainActor
struct FingerprintView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = FingerprintViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.fingerprint.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("fingerprint.input.title"), systemImage: "target") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("fingerprint.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.run() } }
                TextField("22", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("fingerprint.action.scan"), systemImage: "sparkle.magnifyingglass")
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
        case .success(let service, let product, let banner):
            SectionCard(title: L10n("fingerprint.section.result"), systemImage: "person.text.rectangle") {
                HStack {
                    StatusBadge(kind: .info, text: L10n("fingerprint.service"))
                    Text(service)
                        .font(AppTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer()
                }
                if !product.isEmpty {
                    ResultRow(label: L10n("fingerprint.product"), value: product, isMonospaced: false)
                }
                Divider().overlay(theme.separator)
                Text(L10n("fingerprint.banner"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(banner.isEmpty ? "—" : banner)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    private var noteSection: some View {
        Text(L10n("fingerprint.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
