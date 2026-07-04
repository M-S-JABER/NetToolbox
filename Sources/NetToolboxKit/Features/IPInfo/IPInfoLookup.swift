import SwiftUI
import Observation

/// Looks up geo/ISP details for an arbitrary IP or hostname (not just the
/// device's own public IP). Backed by ipwho.is behind a swappable protocol.
protocol IPInfoProviding: Sendable {
    func lookup(_ query: String) async throws -> PublicIPInfo
}

struct IpwhoisLookupService: IPInfoProviding {
    private let client: any HTTPDataClient

    init(client: any HTTPDataClient = URLSessionDataClient()) {
        self.client = client
    }

    private struct Response: Decodable {
        struct Connection: Decodable {
            let asn: Int?
            let org: String?
            let isp: String?
        }
        struct Timezone: Decodable {
            let id: String?
        }
        let ip: String
        let success: Bool
        let message: String?
        let country: String?
        let country_code: String?
        let city: String?
        let connection: Connection?
        let timezone: Timezone?
    }

    func lookup(_ query: String) async throws -> PublicIPInfo {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let url = URL(string: "https://ipwho.is/\(encoded)") else {
            throw NetworkServiceError.invalidURL
        }
        let data = try await client.data(from: url)
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw NetworkServiceError.decoding
        }
        guard decoded.success else {
            throw NetworkServiceError.badStatus(422)
        }
        return PublicIPInfo(
            ip: decoded.ip,
            country: decoded.country,
            countryCode: decoded.country_code,
            city: decoded.city,
            isp: decoded.connection?.isp,
            organization: decoded.connection?.org,
            asn: decoded.connection?.asn,
            timezone: decoded.timezone?.id
        )
    }
}

@MainActor
@Observable
final class IPInfoViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(PublicIPInfo)
        case failure(String)
    }

    var query = ""
    private(set) var output: Output = .idle

    private let service: any IPInfoProviding

    init(service: any IPInfoProviding = IpwhoisLookupService()) {
        self.service = service
    }

    func lookup() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        output = .loading
        do {
            let info = try await service.lookup(trimmed)
            output = .success(info)
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct IPInfoTool: NetworkTool {
    let id = "ip-info"
    let titleKey = L10n("tool.ipinfo.title")
    let subtitleKey = L10n("tool.ipinfo.subtitle")
    let systemImage = "mappin.and.ellipse"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(IPInfoView()) }
}

struct IPInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(HistoryStore.self) private var history
    @State private var viewModel = IPInfoViewModel()

    private func lookup() async {
        await viewModel.lookup()
        if case .success(let info) = viewModel.output {
            let place = [info.city, info.country].compactMap { $0 }.joined(separator: ", ")
            history.log(toolID: "ip-info", input: viewModel.query, summary: "\(info.ip) \(place)")
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
        .navigationTitle(Text(L10n("tool.ipinfo.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ipinfo.input.title"), systemImage: "magnifyingglass") {
            TextField(L10nString("ipinfo.input.placeholder"), text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await lookup() } }

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
                Label(L10nString("ipinfo.empty.title"), systemImage: "mappin.and.ellipse")
            } description: {
                Text(L10n("ipinfo.empty.description"))
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
            SectionCard(title: L10n("ipinfo.section.result"), systemImage: "globe") {
                HStack {
                    CopyableValue(value: info.ip, font: AppTypography.monoLarge)
                    Spacer()
                }
                Divider().overlay(theme.separator)
                if let country = info.country {
                    ResultRow(
                        label: L10n("publicip.result.country"),
                        value: info.countryCode.map { "\(country) (\($0))" } ?? country,
                        isMonospaced: false
                    )
                }
                if let city = info.city {
                    ResultRow(label: L10n("publicip.result.city"), value: city, isMonospaced: false)
                }
                if let isp = info.isp {
                    ResultRow(label: L10n("publicip.result.isp"), value: isp, isMonospaced: false)
                }
                if let org = info.organization {
                    ResultRow(label: L10n("publicip.result.org"), value: org, isMonospaced: false)
                }
                if let asn = info.asn {
                    ResultRow(label: L10n("publicip.result.asn"), value: "AS\(asn)")
                }
                if let timezone = info.timezone {
                    ResultRow(label: L10n("publicip.result.timezone"), value: timezone, isMonospaced: false)
                }
                HStack { Spacer(); ShareButton(text: shareText(info)) }
            }
        }
    }

    private func shareText(_ info: PublicIPInfo) -> String {
        var lines = ["IP: \(info.ip)"]
        if let c = info.country { lines.append("Country: \(c)") }
        if let city = info.city { lines.append("City: \(city)") }
        if let isp = info.isp { lines.append("ISP: \(isp)") }
        if let asn = info.asn { lines.append("ASN: AS\(asn)") }
        return lines.joined(separator: "\n")
    }
}
