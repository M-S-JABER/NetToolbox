import SwiftUI
import Observation

/// Performs a WHOIS query (TCP port 43) against a referral chain.
protocol WhoisQuerying: Sendable {
    func query(_ domain: String) async throws -> String
}

struct WhoisService: WhoisQuerying {
    /// Picks a WHOIS server by TLD, defaulting to IANA which returns a
    /// referral to the authoritative server.
    static func server(for domain: String) -> String {
        let tld = domain.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
        switch tld {
        case "com", "net": return "whois.verisign-grs.com"
        case "org": return "whois.pir.org"
        case "io": return "whois.nic.io"
        case "dev", "app", "page": return "whois.nic.google"
        case "sa": return "whois.nic.net.sa"
        case "uk", "co": return "whois.nic.uk"
        default: return "whois.iana.org"
        }
    }

    func query(_ domain: String) async throws -> String {
        let clean = domain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { throw NetProbeError.invalidHost }
        let server = Self.server(for: clean)

        guard let connection = TCPConnection(host: server, port: 43) else {
            throw NetProbeError.invalidHost
        }
        if case .failure(let error) = await connection.open(timeout: 8) {
            connection.cancel()
            throw error
        }
        guard let payload = "\(clean)\r\n".data(using: .utf8) else {
            throw NetProbeError.noData
        }
        if case .failure(let error) = await connection.send(payload) {
            connection.cancel()
            throw error
        }
        let result = await connection.receiveAll(timeout: 8)
        connection.cancel()
        switch result {
        case .success(let data):
            let text = String(decoding: data, as: UTF8.self)
            return text.isEmpty ? String(localized: "whois.noData", bundle: .module) : text
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
@Observable
final class WhoisViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(String)
        case failure(String)
    }

    var domain = ""
    private(set) var output: Output = .idle

    private let service: any WhoisQuerying

    init(service: any WhoisQuerying = WhoisService()) {
        self.service = service
    }

    func lookup() async {
        let trimmed = domain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        output = .loading
        do {
            let text = try await service.query(trimmed)
            output = .success(text)
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct WhoisTool: NetworkTool {
    let id = "whois"
    let titleKey = L10n("tool.whois.title")
    let subtitleKey = L10n("tool.whois.subtitle")
    let systemImage = "doc.text.magnifyingglass"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(WhoisView()) }
}

@MainActor
struct WhoisView: View {
    @Environment(\.theme) private var theme
    @Environment(HistoryStore.self) private var history
    @State private var viewModel = WhoisViewModel()

    private func lookup() async {
        await viewModel.lookup()
        if case .success(let text) = viewModel.output {
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "OK"
            history.log(toolID: "whois", input: viewModel.domain, summary: String(firstLine.prefix(60)))
        }
    }

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
        .navigationTitle(Text(L10n("tool.whois.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("whois.input.title"), systemImage: "globe") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("whois.input.domain"), text: $viewModel.domain)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await lookup() } }
                SavedHostMenu(host: $viewModel.domain)
            }

            Button {
                Task { await lookup() }
            } label: {
                Label(L10nString("common.search"), systemImage: "magnifyingglass.circle.fill")
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
                Label(L10nString("whois.empty.title"), systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(L10n("whois.empty.description"))
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
        case .success(let text):
            let fields = WhoisParser.parse(text)
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if fields.hasAny {
                    SectionCard(title: L10n("whois.section.summary"), systemImage: "doc.text.magnifyingglass") {
                        if let registrar = fields.registrar {
                            ResultRow(label: L10n("whois.registrar"), value: registrar, isMonospaced: false)
                        }
                        if let created = fields.created {
                            ResultRow(label: L10n("whois.created"), value: created, isMonospaced: false)
                        }
                        if let updated = fields.updated {
                            ResultRow(label: L10n("whois.updated"), value: updated, isMonospaced: false)
                        }
                        if let expires = fields.expires {
                            ResultRow(label: L10n("whois.expires"), value: expires, isMonospaced: false)
                        }
                        if !fields.nameServers.isEmpty {
                            ResultRow(label: L10n("whois.nameServers"),
                                      value: fields.nameServers.joined(separator: "\n"))
                        }
                    }
                }
                SectionCard(title: L10n("whois.section.result"), systemImage: "doc.plaintext") {
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
}
