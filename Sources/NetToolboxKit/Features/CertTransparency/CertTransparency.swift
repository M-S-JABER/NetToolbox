import SwiftUI
import Observation

/// One certificate entry from a crt.sh Certificate Transparency search.
struct CTEntry: Identifiable, Sendable {
    let id: Int
    let commonName: String
    let names: [String]
    let issuer: String
    let notBefore: String
    let notAfter: String
}

/// Searches Certificate Transparency logs via crt.sh's JSON endpoint — every
/// certificate ever publicly issued for a domain (great for spotting rogue or
/// forgotten certs / subdomains). No key.
struct CertTransparencyService: Sendable {
    func search(domain: String) async throws -> [CTEntry] {
        var components = URLComponents(string: "https://crt.sh/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: domain),
            URLQueryItem(name: "output", value: "json"),
        ]
        guard let url = components?.url else { throw NetworkServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NetworkServiceError.badStatus(http.statusCode)
        }

        struct Row: Decodable {
            let id: Int64?
            let common_name: String?
            let name_value: String?
            let issuer_name: String?
            let not_before: String?
            let not_after: String?
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else {
            throw NetworkServiceError.decoding
        }

        var seen = Set<String>()
        var entries: [CTEntry] = []
        for row in rows {
            let names = (row.name_value ?? "")
                .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                .map { String($0) }
            let key = "\(row.common_name ?? "")|\(row.not_after ?? "")|\(row.issuer_name ?? "")"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            entries.append(CTEntry(
                id: Int(row.id ?? Int64(entries.count)),
                commonName: row.common_name ?? (names.first ?? "—"),
                names: Array(Set(names)).sorted(),
                issuer: Self.shortIssuer(row.issuer_name ?? "—"),
                notBefore: Self.day(row.not_before),
                notAfter: Self.day(row.not_after)
            ))
            if entries.count >= 50 { break }
        }
        return entries
    }

    private static func day(_ value: String?) -> String {
        guard let value else { return "—" }
        return String(value.split(separator: "T").first ?? Substring(value))
    }

    private static func shortIssuer(_ value: String) -> String {
        // Pull "CN=…" out of the RFC 4514 issuer string when present.
        for part in value.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("CN=") { return String(trimmed.dropFirst(3)) }
        }
        return value
    }
}

@MainActor
@Observable
final class CertTransparencyViewModel {
    var domain = ""
    private(set) var entries: [CTEntry] = []
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private let service = CertTransparencyService()

    func run() async {
        let target = domain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !target.isEmpty else { return }
        isRunning = true
        errorMessage = nil
        entries = []
        do {
            entries = try await service.search(domain: target)
            if entries.isEmpty { errorMessage = L10nString("ct.empty") }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

struct CertTransparencyTool: NetworkTool {
    let id = "cert-transparency"
    let titleKey = L10n("tool.ct.title")
    let subtitleKey = L10n("tool.ct.subtitle")
    let systemImage = "checkmark.shield"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(CertTransparencyView()) }
}

struct CertTransparencyView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = CertTransparencyViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if !viewModel.entries.isEmpty {
                    resultsSection
                }
                Text(L10n("ct.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ct.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ct.input.title"), systemImage: "magnifyingglass") {
            TextField(L10nString("ct.input.domain"), text: $viewModel.domain)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("ct.action.search"), systemImage: "checkmark.shield")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("ct.section.results"), systemImage: "list.bullet.rectangle") {
            ForEach(viewModel.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.commonName)
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                    Text("\(entry.issuer) · \(entry.notBefore) → \(entry.notAfter)")
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                    if entry.names.count > 1 {
                        Text(entry.names.prefix(8).joined(separator: ", "))
                            .font(AppTypography.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if entry.id != viewModel.entries.last?.id {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }
}
