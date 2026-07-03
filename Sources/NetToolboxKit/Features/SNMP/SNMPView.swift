import SwiftUI
import Observation

/// Performs an SNMP v2c GET over UDP using the pure `SNMPMessage` codec.
protocol SNMPQuerying: Sendable {
    func get(host: String, community: String, oid: String) async throws -> SNMPVarbind
}

struct SNMPService: SNMPQuerying {
    func get(host: String, community: String, oid: String) async throws -> SNMPVarbind {
        let request = try SNMPMessage.encodeGet(oid: oid, community: community, requestID: 1)
        let response = await UDPExchange.request(
            host: host, port: 161, payload: request, timeout: 5
        )
        switch response {
        case .success(let data):
            return try SNMPMessage.decodeResponse(data)
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
@Observable
final class SNMPViewModel {
    struct Preset: Identifiable {
        let name: String
        let oid: String
        var id: String { oid }
    }

    static let presets: [Preset] = [
        Preset(name: "sysDescr", oid: "1.3.6.1.2.1.1.1.0"),
        Preset(name: "sysName", oid: "1.3.6.1.2.1.1.5.0"),
        Preset(name: "sysUpTime", oid: "1.3.6.1.2.1.1.3.0"),
        Preset(name: "sysContact", oid: "1.3.6.1.2.1.1.4.0"),
        Preset(name: "sysLocation", oid: "1.3.6.1.2.1.1.6.0"),
    ]

    enum Output: Equatable {
        case idle, loading
        case success(SNMPVarbind)
        case failure(String)
    }

    var host = ""
    var community = "public"
    var oid = "1.3.6.1.2.1.1.1.0"
    private(set) var output: Output = .idle

    private let service: any SNMPQuerying

    init(service: any SNMPQuerying = SNMPService()) {
        self.service = service
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { output = .idle; return }
        output = .loading
        do {
            let varbind = try await service.get(
                host: target,
                community: community.trimmingCharacters(in: .whitespaces),
                oid: oid.trimmingCharacters(in: .whitespaces)
            )
            output = .success(varbind)
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct SNMPTool: NetworkTool {
    let id = "snmp"
    let titleKey = L10n("tool.snmp.title")
    let subtitleKey = L10n("tool.snmp.subtitle")
    let systemImage = "chart.bar.doc.horizontal"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SNMPView()) }
}

struct SNMPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SNMPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                presetsSection
                outputSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.snmp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("snmp.input.title"), systemImage: "chart.bar.doc.horizontal") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("snmp.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                TextField(L10nString("snmp.input.community"), text: $viewModel.community)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: 140)
                    .environment(\.layoutDirection, .leftToRight)
            }
            TextField(L10nString("snmp.input.oid"), text: $viewModel.oid)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("snmp.action.get"), systemImage: "arrow.down.doc")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var presetsSection: some View {
        SectionCard(title: L10n("snmp.section.presets"), systemImage: "square.grid.2x2") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(SNMPViewModel.presets) { preset in
                    Button {
                        viewModel.oid = preset.oid
                    } label: {
                        Text(preset.name)
                            .font(AppTypography.monoCaption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
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
        case .success(let varbind):
            SectionCard(title: L10n("snmp.section.result"), systemImage: "checkmark.circle") {
                ResultRow(label: L10n("snmp.result.oid"), value: varbind.oid)
                ResultRow(label: L10n("snmp.result.type"), value: varbind.typeName)
                Divider().overlay(theme.separator)
                CopyableValue(value: varbind.value.isEmpty ? "—" : varbind.value)
            }
        }
    }
}
