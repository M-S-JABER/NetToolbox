import SwiftUI
import Observation

/// Structured registration data for a domain or IP, from RDAP (the modern JSON
/// successor to WHOIS) via the rdap.org bootstrap.
struct RDAPResult: Sendable, Equatable {
    var name: String
    var handle: String
    var registrar: String
    var statuses: [String]
    var events: [String]
    var nameservers: [String]
}

struct RDAPService: Sendable {
    func lookup(query: String) async throws -> RDAPResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let isIP = trimmed.contains(where: { $0 == ":" }) || trimmed.allSatisfy { $0.isNumber || $0 == "." }
        let path = isIP ? "ip" : "domain"
        guard let url = URL(string: "https://rdap.org/\(path)/\(trimmed)") else { throw NetworkServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/rdap+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw NetworkServiceError.badStatus(404)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkServiceError.decoding
        }

        let name = (json["ldhName"] as? String) ?? (json["handle"] as? String) ?? trimmed
        let handle = (json["handle"] as? String) ?? "—"
        let statuses = (json["status"] as? [String]) ?? []

        var events: [String] = []
        for event in (json["events"] as? [[String: Any]]) ?? [] {
            if let action = event["eventAction"] as? String, let date = event["eventDate"] as? String {
                events.append("\(action): \(String(date.prefix(10)))")
            }
        }

        var nameservers: [String] = []
        for ns in (json["nameservers"] as? [[String: Any]]) ?? [] {
            if let ldh = ns["ldhName"] as? String { nameservers.append(ldh) }
        }

        return RDAPResult(
            name: name,
            handle: handle,
            registrar: Self.registrar(from: json),
            statuses: statuses,
            events: events,
            nameservers: nameservers
        )
    }

    /// Digs the registrar/organization "fn" out of the entities' vCard arrays.
    private static func registrar(from json: [String: Any]) -> String {
        guard let entities = json["entities"] as? [[String: Any]] else { return "—" }
        for entity in entities {
            let roles = (entity["roles"] as? [String]) ?? []
            guard roles.contains("registrar") || roles.contains("registrant") else { continue }
            if let vcard = entity["vcardArray"] as? [Any], vcard.count >= 2,
               let fields = vcard[1] as? [[Any]] {
                for field in fields where field.count >= 4 {
                    if let key = field[0] as? String, key == "fn", let value = field[3] as? String {
                        return value
                    }
                }
            }
            if let handle = entity["handle"] as? String { return handle }
        }
        return "—"
    }
}

@MainActor
@Observable
final class RDAPViewModel {
    var query = ""
    private(set) var result: RDAPResult?
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private let service = RDAPService()

    func run() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isRunning = true
        errorMessage = nil
        result = nil
        do {
            result = try await service.lookup(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

struct RDAPTool: NetworkTool {
    let id = "rdap"
    let titleKey = L10n("tool.rdap.title")
    let subtitleKey = L10n("tool.rdap.subtitle")
    let systemImage = "doc.text.magnifyingglass"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(RDAPView()) }
}

@MainActor
struct RDAPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = RDAPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let result = viewModel.result {
                    resultSection(result)
                }
                Text(L10n("rdap.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.rdap.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("rdap.input.title"), systemImage: "doc.text.magnifyingglass") {
            TextField(L10nString("rdap.input.query"), text: $viewModel.query)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("rdap.action.lookup"), systemImage: "magnifyingglass").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private func resultSection(_ result: RDAPResult) -> some View {
        SectionCard(title: L10n("rdap.section.result"), systemImage: "doc.text") {
            row(L10n("rdap.name"), result.name)
            row(L10n("rdap.registrar"), result.registrar)
            row(L10n("rdap.handle"), result.handle)
            if !result.events.isEmpty {
                divider(); labeledList(L10n("rdap.events"), result.events)
            }
            if !result.statuses.isEmpty {
                divider(); labeledList(L10n("rdap.status"), result.statuses)
            }
            if !result.nameservers.isEmpty {
                divider(); labeledList(L10n("rdap.nameservers"), result.nameservers)
            }
        }
    }

    private func row(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(AppTypography.footnote).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing).environment(\.layoutDirection, .leftToRight)
        }
    }

    private func labeledList(_ label: LocalizedStringResource, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption.weight(.semibold)).foregroundStyle(theme.textSecondary).textCase(.uppercase)
            ForEach(values, id: \.self) { value in
                Text(value).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    private func divider() -> some View { Divider().overlay(theme.separator) }
}
