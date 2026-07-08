import SwiftUI
import Observation

// MARK: - Model

enum RPKIStatus: String, Sendable, Equatable {
    case valid, invalid, unknown

    /// Normalizes RIPEstat's status strings.
    static func from(_ raw: String) -> RPKIStatus {
        switch raw.lowercased() {
        case "valid": .valid
        case "invalid", "invalid_asn", "invalid_length": .invalid
        default: .unknown
        }
    }
}

struct RPKIRoa: Identifiable, Equatable, Sendable {
    let origin: String
    let prefix: String
    let maxLength: Int
    let validity: String
    var id: String { "\(origin)-\(prefix)-\(maxLength)" }
}

struct RPKIResult: Equatable, Sendable {
    let status: RPKIStatus
    let asn: String
    let prefix: String
    let roas: [RPKIRoa]
}

enum RPKIEngine {
    /// Normalizes an AS input ("AS13335", "as 13335", "13335") to digits only.
    static func normalizeASN(_ input: String) -> String {
        let lowered = input.lowercased().replacingOccurrences(of: "as", with: "")
        return lowered.filter(\.isNumber)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class RPKIViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(RPKIResult)
        case failure(String)
    }

    var asn = ""
    var prefix = ""
    private(set) var output: Output = .idle

    func check() async {
        let asnDigits = RPKIEngine.normalizeASN(asn)
        let cleanPrefix = prefix.trimmingCharacters(in: .whitespaces)
        guard !asnDigits.isEmpty, !cleanPrefix.isEmpty else {
            output = .failure(L10nString("rpki.error.input"))
            return
        }
        guard let encodedPrefix = cleanPrefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://stat.ripe.net/data/rpki-validation/data.json?resource=\(asnDigits)&prefix=\(encodedPrefix)") else {
            output = .failure(L10nString("rpki.error.input"))
            return
        }
        output = .loading
        do {
            let (data, _) = try await URLSession(configuration: .ephemeral).data(from: url)
            let decoded = try JSONDecoder().decode(RIPEStatRPKI.self, from: data)
            let roas = (decoded.data.validating_roas ?? []).map {
                RPKIRoa(origin: $0.origin ?? "?", prefix: $0.prefix ?? "?",
                        maxLength: $0.max_length ?? 0, validity: $0.validity ?? "?")
            }
            output = .success(RPKIResult(
                status: RPKIStatus.from(decoded.data.status ?? "unknown"),
                asn: "AS\(asnDigits)", prefix: cleanPrefix, roas: roas
            ))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }

    private struct RIPEStatRPKI: Decodable {
        struct Payload: Decodable {
            let status: String?
            let validating_roas: [Roa]?
        }
        struct Roa: Decodable {
            let origin: String?
            let prefix: String?
            let max_length: Int?
            let validity: String?
        }
        let data: Payload
    }
}

// MARK: - Tool

struct RPKITool: NetworkTool {
    let id = "rpki"
    let titleKey = L10n("tool.rpki.title")
    let subtitleKey = L10n("tool.rpki.subtitle")
    let systemImage = "checkmark.shield.fill"
    let category: ToolCategory = .bgp

    func makeView() -> AnyView { AnyView(RPKIView()) }
}

// MARK: - View

@MainActor
struct RPKIView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = RPKIViewModel()

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
        .navigationTitle(Text(L10n("tool.rpki.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("rpki.input.title"), systemImage: "shield.lefthalf.filled") {
            TextField(L10nString("rpki.input.asn"), text: $viewModel.asn)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10nString("rpki.input.prefix"), text: $viewModel.prefix)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.check() }
            } label: {
                Label(L10nString("rpki.action.check"), systemImage: "checkmark.shield")
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
        case .success(let result):
            resultCard(result)
        }
    }

    private func resultCard(_ result: RPKIResult) -> some View {
        let (kind, key): (StatusBadge.Kind, String) = {
            switch result.status {
            case .valid: return (.success, "rpki.status.valid")
            case .invalid: return (.danger, "rpki.status.invalid")
            case .unknown: return (.warning, "rpki.status.unknown")
            }
        }()
        return SectionCard(title: L10n("rpki.section.result"), systemImage: "checkmark.seal") {
            HStack {
                StatusBadge(kind: kind, text: L10n(key))
                Spacer()
                Text("\(result.asn) · \(result.prefix)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            if result.roas.isEmpty {
                Text(L10n("rpki.noroas"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(result.roas) { roa in
                    Divider().overlay(theme.separator)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AS\(roa.origin) → \(roa.prefix)")
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                        Text("max-length /\(roa.maxLength) · \(roa.validity)")
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var noteSection: some View {
        Text(L10n("rpki.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
