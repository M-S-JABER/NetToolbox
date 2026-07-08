import SwiftUI
import Observation

/// Resolves DNS records over UDP using the pure `DNSMessage` codec.
protocol DNSResolving: Sendable {
    func resolve(name: String, type: DNSRecordType, server: String) async throws -> [DNSRecord]
}

struct UDPDNSResolver: DNSResolving {
    func resolve(name: String, type: DNSRecordType, server: String) async throws -> [DNSRecord] {
        // A fixed ID is fine: each query uses its own short-lived socket.
        let query = try DNSMessage.encodeQuery(name: name, type: type, id: 0x1234)
        let response = await UDPExchange.request(
            host: server, port: 53, payload: query, timeout: 5
        )
        switch response {
        case .success(let data):
            return try DNSMessage.decodeAnswers(data)
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
@Observable
final class DNSLookupViewModel {
    enum Output: Equatable {
        case idle
        case loading
        case success([DNSRecord])
        case failure(String)
    }

    var name = ""
    var type: DNSRecordType = .a
    var server = "1.1.1.1"
    private(set) var output: Output = .idle

    private let resolver: any DNSResolving

    init(resolver: any DNSResolving = UDPDNSResolver()) {
        self.resolver = resolver
    }

    func lookup() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        let resolver = self.resolver
        let type = self.type
        let server = self.server.trimmingCharacters(in: .whitespaces)
        output = .loading
        do {
            let records = try await resolver.resolve(name: trimmed, type: type, server: server)
            output = .success(records)
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct DNSLookupTool: NetworkTool {
    let id = "dns-lookup"
    let titleKey = L10n("tool.dns.title")
    let subtitleKey = L10n("tool.dns.subtitle")
    let systemImage = "at"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(DNSLookupView()) }
}

@MainActor
struct DNSLookupView: View {
    @Environment(\.theme) private var theme
    @Environment(HistoryStore.self) private var history
    @State private var viewModel = DNSLookupViewModel()

    private func lookup() async {
        await viewModel.lookup()
        if case .success(let records) = viewModel.output {
            history.log(
                toolID: "dns-lookup",
                input: "\(viewModel.name) \(viewModel.type.label)",
                summary: records.first?.value ?? "0 records"
            )
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
        .navigationTitle(Text(L10n("tool.dns.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("dns.input.title"), systemImage: "at") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("dns.input.name"), text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.name)
            }

            Picker(L10nString("dns.input.type"), selection: $viewModel.type) {
                ForEach(DNSRecordType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text(L10n("dns.input.server"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                TextField("1.1.1.1", text: $viewModel.server)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(maxWidth: 180)
                    .environment(\.layoutDirection, .leftToRight)
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
                Label(L10nString("dns.empty.title"), systemImage: "at")
            } description: {
                Text(L10n("dns.empty.description"))
            }
        case .loading:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("common.loading"))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .failure(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.danger)
            }
        case .success(let records):
            if records.isEmpty {
                SectionCard(title: L10n("dns.section.answers"), systemImage: "tray") {
                    Text(L10n("dns.noRecords"))
                        .font(AppTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                SectionCard(title: L10n("dns.section.answers"), systemImage: "tray.full") {
                    VStack(spacing: Spacing.sm) {
                        ForEach(records) { record in
                            recordRow(record)
                        }
                    }
                }
            }
        }
    }

    private func recordRow(_ record: DNSRecord) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(record.type.label)
                .font(AppTypography.monoCaption.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(minWidth: 56, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                CopyableValue(value: record.value)
                Text("TTL \(record.ttl)s")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()
        }
    }
}
