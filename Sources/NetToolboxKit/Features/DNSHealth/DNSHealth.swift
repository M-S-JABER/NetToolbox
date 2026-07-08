import SwiftUI
import Observation

// MARK: - Model

/// One public resolver's answer for the queried record.
struct DNSResolverResult: Identifiable, Equatable, Sendable {
    let name: String
    let server: String
    var values: [String] = []
    var error: String?

    var id: String { server }
    var ok: Bool { error == nil }
}

enum DNSSECStatus: Sendable, Equatable {
    case signed, unsigned, bogus, unknown
}

enum DNSHealthEngine {
    /// A spread of well-known public resolvers for propagation checks.
    static let resolvers: [(name: String, ip: String)] = [
        ("Cloudflare", "1.1.1.1"),
        ("Google", "8.8.8.8"),
        ("Quad9", "9.9.9.9"),
        ("OpenDNS", "208.67.222.222"),
        ("AdGuard", "94.140.14.14"),
        ("Level3", "4.2.2.2"),
    ]

    /// True when every resolver that answered returned the same value set.
    static func consistent(_ results: [DNSResolverResult]) -> Bool {
        let sets = results.filter(\.ok).map { Set($0.values) }
        guard let first = sets.first else { return false }
        return sets.dropFirst().allSatisfy { $0 == first }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class DNSHealthViewModel {
    var name = ""
    var type: DNSRecordType = .a

    private(set) var results: [DNSResolverResult] = []
    private(set) var consistent = false
    private(set) var dnssec: DNSSECStatus = .unknown
    private(set) var isRunning = false
    private(set) var hasRun = false
    private(set) var errorMessage: String?

    private let resolver: any DNSResolving

    init(resolver: any DNSResolving = UDPDNSResolver()) {
        self.resolver = resolver
    }

    func run() async {
        let host = name.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { errorMessage = L10nString("dnshealth.error.host"); return }
        let type = self.type
        let resolver = self.resolver

        errorMessage = nil
        isRunning = true
        dnssec = .unknown
        results = DNSHealthEngine.resolvers.map { DNSResolverResult(name: $0.name, server: $0.ip) }

        await withTaskGroup(of: (Int, DNSResolverResult).self) { group in
            for (index, entry) in DNSHealthEngine.resolvers.enumerated() {
                group.addTask {
                    var result = DNSResolverResult(name: entry.name, server: entry.ip)
                    do {
                        let records = try await resolver.resolve(name: host, type: type, server: entry.ip)
                        result.values = records.map(\.value).sorted()
                        if result.values.isEmpty { result.error = L10nString("dnshealth.noanswer") }
                    } catch {
                        result.error = error.localizedDescription
                    }
                    return (index, result)
                }
            }
            for await (index, result) in group where results.indices.contains(index) {
                results[index] = result
            }
        }
        consistent = DNSHealthEngine.consistent(results)
        dnssec = await checkDNSSEC(host: host, type: type)
        hasRun = true
        isRunning = false
    }

    private func checkDNSSEC(host: String, type: DNSRecordType) async -> DNSSECStatus {
        guard let query = try? DNSMessage.encodeQuery(name: host, type: type, id: 0x2A2A, dnssecOK: true) else {
            return .unknown
        }
        let response = await UDPExchange.request(host: "1.1.1.1", port: 53, payload: query, timeout: 5)
        switch response {
        case .success(let data):
            let flags = DNSMessage.responseFlags(data)
            if flags.rcode == 2 { return .bogus }   // SERVFAIL from a validating resolver
            return flags.authenticated ? .signed : .unsigned
        case .failure:
            return .unknown
        }
    }

    func stop() { isRunning = false }
}

// MARK: - Tool

struct DNSHealthTool: NetworkTool {
    let id = "dns-health"
    let titleKey = L10n("tool.dnshealth.title")
    let subtitleKey = L10n("tool.dnshealth.subtitle")
    let systemImage = "checkmark.shield.fill"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(DNSHealthView()) }
}

// MARK: - View

@MainActor
struct DNSHealthView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = DNSHealthViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if viewModel.hasRun {
                    dnssecSection
                    propagationSection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.dnshealth.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("dnshealth.input.title"), systemImage: "globe") {
            TextField(L10nString("dnshealth.input.host"), text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)

            Picker(L10nString("dnshealth.opt.type"), selection: $viewModel.type) {
                ForEach(DNSRecordType.allCases) { recordType in
                    Text(recordType.label).tag(recordType)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    Task { await viewModel.run() }
                } label: {
                    Label(L10nString("dnshealth.action.check"), systemImage: "checkmark.shield")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
                if viewModel.isRunning { ProgressView() }
            }

            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var dnssecSection: some View {
        let (kind, key): (StatusBadge.Kind, String) = {
            switch viewModel.dnssec {
            case .signed: return (.success, "dnshealth.dnssec.signed")
            case .unsigned: return (.warning, "dnshealth.dnssec.unsigned")
            case .bogus: return (.danger, "dnshealth.dnssec.bogus")
            case .unknown: return (.neutral, "dnshealth.dnssec.unknown")
            }
        }()
        return SectionCard(title: L10n("dnshealth.section.dnssec"), systemImage: "lock.shield") {
            HStack {
                StatusBadge(kind: kind, text: L10n(key))
                Spacer()
            }
            Text(L10n("dnshealth.dnssec.note"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var propagationSection: some View {
        SectionCard(title: L10n("dnshealth.section.propagation"), systemImage: "arrow.triangle.branch") {
            HStack {
                StatusBadge(
                    kind: viewModel.consistent ? .success : .warning,
                    text: viewModel.consistent ? L10n("dnshealth.consistent") : L10n("dnshealth.inconsistent")
                )
                Spacer()
            }
            ForEach(viewModel.results) { result in
                Divider().overlay(theme.separator)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(result.name)
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                        Text(result.server)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        Image(systemName: result.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(result.ok ? theme.success : theme.warning)
                            .font(.caption)
                    }
                    Text(result.ok ? result.values.joined(separator: ", ") : (result.error ?? "—"))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(result.ok ? theme.mono : theme.textSecondary)
                        .lineLimit(2)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }

    private var noteSection: some View {
        Text(L10n("dnshealth.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
