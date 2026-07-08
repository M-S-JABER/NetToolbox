import SwiftUI
import Observation

/// SNMP v2c GET and walk (GETNEXT) over UDP, using the pure `SNMPMessage`
/// codec. The port is configurable.
protocol SNMPQuerying: Sendable {
    func get(host: String, community: String, oid: String, port: UInt16) async throws -> SNMPVarbind
    func walk(host: String, community: String, oid: String, port: UInt16) async throws -> [SNMPVarbind]
}

struct SNMPService: SNMPQuerying {
    func get(host: String, community: String, oid: String, port: UInt16) async throws -> SNMPVarbind {
        let request = try SNMPMessage.encodeGet(oid: oid, community: community, requestID: 1)
        let response = await UDPExchange.request(host: host, port: port, payload: request, timeout: 5)
        switch response {
        case .success(let data): return try SNMPMessage.decodeResponse(data)
        case .failure(let error): throw error
        }
    }

    func walk(host: String, community: String, oid: String, port: UInt16) async throws -> [SNMPVarbind] {
        var results: [SNMPVarbind] = []
        var current = oid
        var requestID = 1

        for _ in 0..<256 {
            let request = try SNMPMessage.encodeGetNext(oid: current, community: community, requestID: requestID)
            requestID += 1
            let response = await UDPExchange.request(host: host, port: port, payload: request, timeout: 5)
            guard case .success(let data) = response,
                  let varbind = try? SNMPMessage.decodeResponse(data) else { break }
            // Stop when the walk leaves the requested subtree or stops advancing.
            guard varbind.oid.hasPrefix(oid + ".") || varbind.oid == oid, varbind.oid != current else { break }
            results.append(varbind)
            current = varbind.oid
        }
        guard !results.isEmpty else { throw NetProbeError.noData }
        return results
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
        Preset(name: "system", oid: "1.3.6.1.2.1.1"),
        Preset(name: "interfaces", oid: "1.3.6.1.2.1.2.2.1.2"),
    ]

    enum Mode: String, CaseIterable, Identifiable {
        case get, walk
        var id: String { rawValue }
        var labelKey: String { "snmp.mode.\(rawValue)" }
    }

    enum Version: String, CaseIterable, Identifiable {
        case v2c, v3
        var id: String { rawValue }
        var label: String { self == .v2c ? "v2c" : "v3" }
    }

    enum Output: Equatable {
        case idle, loading
        case get(SNMPVarbind)
        case walk([SNMPVarbind])
        case failure(String)
    }

    var host = ""
    var community = "public"
    var oid = "1.3.6.1.2.1.1.1.0"
    var portText = "161"
    var mode: Mode = .get
    var version: Version = .v2c
    // v3 (USM authNoPriv) parameters
    var username = ""
    var authPassword = ""
    var authProtocol: SNMPv3Auth = .sha
    private(set) var output: Output = .idle

    private let service: any SNMPQuerying
    private let v3Service = SNMPv3Service()

    init(service: any SNMPQuerying = SNMPService()) {
        self.service = service
    }

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { output = .idle; return }
        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? 161
        let oid = oid.trimmingCharacters(in: .whitespaces)
        output = .loading
        do {
            if version == .v3 {
                let user = username.trimmingCharacters(in: .whitespaces)
                guard !user.isEmpty, !authPassword.isEmpty else {
                    output = .failure(L10nString("snmp.v3.needCredentials")); return
                }
                let varbind = try await v3Service.get(
                    host: target, port: port, user: user,
                    password: authPassword, auth: authProtocol, oid: oid
                )
                output = .get(varbind)
                return
            }
            let community = community.trimmingCharacters(in: .whitespaces)
            switch mode {
            case .get:
                output = .get(try await service.get(host: target, community: community, oid: oid, port: port))
            case .walk:
                output = .walk(try await service.walk(host: target, community: community, oid: oid, port: port))
            }
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

@MainActor
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
            Picker(L10nString("snmp.version.title"), selection: $viewModel.version) {
                ForEach(SNMPViewModel.Version.allCases) { version in
                    Text(version.label).tag(version)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Spacing.md) {
                TextField(L10nString("snmp.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
                TextField("161", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 70)
                    .environment(\.layoutDirection, .leftToRight)
            }

            if viewModel.version == .v2c {
                TextField(L10nString("snmp.input.community"), text: $viewModel.community)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                v3CredentialFields
            }

            TextField(L10nString("snmp.input.oid"), text: $viewModel.oid)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            if viewModel.version == .v2c {
                Picker(L10nString("snmp.mode.title"), selection: $viewModel.mode) {
                    ForEach(SNMPViewModel.Mode.allCases) { mode in
                        Text(L10n(mode.labelKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString(viewModel.version == .v2c && viewModel.mode == .walk ? "snmp.action.walk" : "snmp.action.get"),
                      systemImage: "arrow.down.doc")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var v3CredentialFields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(L10n("snmp.v3.beta"))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(theme.background)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent, in: Capsule())
                Text(L10n("snmp.v3.authNoPriv"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            TextField(L10nString("snmp.v3.username"), text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            SecureField(L10nString("snmp.v3.authPassword"), text: $viewModel.authPassword)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)
            Picker(L10nString("snmp.v3.authProtocol"), selection: $viewModel.authProtocol) {
                ForEach(SNMPv3Auth.allCases) { proto in
                    Text(proto.displayName).tag(proto)
                }
            }
            .pickerStyle(.segmented)
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
        case .get(let varbind):
            SectionCard(title: L10n("snmp.section.result"), systemImage: "checkmark.circle") {
                ResultRow(label: L10n("snmp.result.oid"), value: varbind.oid)
                ResultRow(label: L10n("snmp.result.type"), value: varbind.typeName)
                Divider().overlay(theme.separator)
                CopyableValue(value: varbind.value.isEmpty ? "—" : varbind.value)
            }
        case .walk(let varbinds):
            SectionCard(title: L10n("snmp.section.walk"), systemImage: "list.bullet.indent") {
                VStack(spacing: Spacing.sm) {
                    ForEach(varbinds, id: \.oid) { varbind in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(varbind.oid)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .environment(\.layoutDirection, .leftToRight)
                            Text(varbind.value.isEmpty ? "—" : varbind.value)
                                .font(AppTypography.monoBody)
                                .foregroundStyle(theme.mono)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }
            }
        }
    }
}
