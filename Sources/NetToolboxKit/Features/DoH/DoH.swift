import SwiftUI
import Observation

/// DNS-over-HTTPS resolver (RFC 8484): POSTs the DNS wire-format query and
/// decodes the wire-format answer with the shared `DNSMessage` codec.
struct DoHResolver {
    func resolve(name: String, type: DNSRecordType, server: String) async throws -> [DNSRecord] {
        let query = try DNSMessage.encodeQuery(name: name, type: type, id: 0)
        let host = server.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "https://\(host)/dns-query") else {
            throw NetworkServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/dns-message", forHTTPHeaderField: "content-type")
        request.setValue("application/dns-message", forHTTPHeaderField: "accept")
        request.httpBody = query

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NetworkServiceError.badStatus(http.statusCode)
            }
            return try DNSMessage.decodeAnswers(data)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkServiceError.offline
        }
    }
}

@MainActor
@Observable
final class DoHViewModel {
    enum Output: Equatable {
        case idle, loading
        case success([DNSRecord])
        case failure(String)
    }

    var name = ""
    var type: DNSRecordType = .a
    var server = "cloudflare-dns.com"
    private(set) var output: Output = .idle

    private let resolver = DoHResolver()

    func lookup() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        output = .loading
        do {
            output = .success(try await resolver.resolve(name: trimmed, type: type, server: server))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct DoHTool: NetworkTool {
    let id = "doh"
    let titleKey = L10n("tool.doh.title")
    let subtitleKey = L10n("tool.doh.subtitle")
    let systemImage = "lock.doc"
    let category: ToolCategory = .dns

    func makeView() -> AnyView { AnyView(DoHView()) }
}

@MainActor
struct DoHView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = DoHViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("dns.input.title"), systemImage: "lock.doc") {
                    HStack(spacing: Spacing.sm) {
                        TextField(L10nString("dns.input.name"), text: $viewModel.name)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .environment(\.layoutDirection, .leftToRight)
                        SavedHostMenu(host: $viewModel.name)
                    }
                    Picker(L10nString("dns.input.type"), selection: $viewModel.type) {
                        ForEach(DNSRecordType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text(L10n("dns.input.server")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                        TextField("cloudflare-dns.com", text: $viewModel.server)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    Button {
                        Task { await viewModel.lookup() }
                    } label: {
                        Label(L10nString("common.search"), systemImage: "magnifyingglass.circle.fill")
                            .font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }

                switch viewModel.output {
                case .idle:
                    ContentUnavailableView {
                        Label(L10nString("doh.empty.title"), systemImage: "lock.doc")
                    } description: {
                        Text(L10n("doh.empty.description"))
                    }
                case .loading:
                    HStack(spacing: Spacing.md) {
                        ProgressView(); Text(L10n("common.loading")).foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                case .failure(let message):
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                case .success(let records):
                    SectionCard(title: L10n("dns.section.answers"), systemImage: "tray.full") {
                        if records.isEmpty {
                            Text(L10n("dns.noRecords")).font(AppTypography.body).foregroundStyle(theme.textSecondary)
                        } else {
                            VStack(spacing: Spacing.sm) {
                                ForEach(records) { record in
                                    HStack(alignment: .top, spacing: Spacing.md) {
                                        Text(record.type.label)
                                            .font(AppTypography.monoCaption.weight(.semibold))
                                            .foregroundStyle(theme.accent).frame(minWidth: 56, alignment: .leading)
                                            .environment(\.layoutDirection, .leftToRight)
                                        CopyableValue(value: record.value)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.doh.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
