import SwiftUI
import Observation

// MARK: - Model

struct CertExpiryResult: Identifiable, Equatable, Sendable {
    let host: String
    var daysRemaining: Int?
    var notAfter: String?
    var subject: String?
    var error: String?

    var id: String { host }
}

enum CertExpiryLevel: Sendable, Equatable {
    case ok, warning, critical, expired, unknown
}

enum CertExpiryEngine {
    /// Buckets a certificate by how close it is to expiry.
    static func level(days: Int?) -> CertExpiryLevel {
        guard let days else { return .unknown }
        if days < 0 { return .expired }
        if days < 15 { return .critical }
        if days < 30 { return .warning }
        return .ok
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class CertExpiryViewModel {
    var newHost = ""
    private(set) var results: [CertExpiryResult] = []
    private(set) var isChecking = false

    private var hosts: [String] = []
    private let inspector: any SSLInspecting

    init(inspector: any SSLInspecting = SSLInspector()) {
        self.inspector = inspector
    }

    func add() {
        let host = newHost.trimmingCharacters(in: .whitespaces).lowercased()
        guard !host.isEmpty, !hosts.contains(host) else { return }
        hosts.append(host)
        results.append(CertExpiryResult(host: host))
        newHost = ""
        Task { await refresh() }
    }

    func remove(_ host: String) {
        hosts.removeAll { $0 == host }
        results.removeAll { $0.host == host }
    }

    func refresh() async {
        guard !hosts.isEmpty, !isChecking else { return }
        isChecking = true
        let inspector = self.inspector
        let targets = hosts
        let checked = await withTaskGroup(of: CertExpiryResult.self) { group in
            for host in targets {
                group.addTask {
                    var result = CertExpiryResult(host: host)
                    switch await inspector.inspect(host: host, port: 443) {
                    case .success(let info):
                        result.daysRemaining = info.daysRemaining
                        result.notAfter = info.notAfter
                        result.subject = info.subject
                    case .failure(let error):
                        result.error = error.localizedDescription
                    }
                    return result
                }
            }
            var out: [CertExpiryResult] = []
            for await result in group { out.append(result) }
            return out
        }
        results = targets.compactMap { host in checked.first { $0.host == host } }
        isChecking = false
    }
}

// MARK: - Tool

struct CertExpiryTool: NetworkTool {
    let id = "cert-expiry"
    let titleKey = L10n("tool.certexp.title")
    let subtitleKey = L10n("tool.certexp.subtitle")
    let systemImage = "calendar.badge.clock"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(CertExpiryView()) }
}

// MARK: - View

@MainActor
struct CertExpiryView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = CertExpiryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.results.isEmpty {
                    listSection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.certexp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("certexp.input.title"), systemImage: "plus.circle") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("certexp.input.host"), text: $viewModel.newHost)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { viewModel.add() }
                Button {
                    viewModel.add()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text(L10n("certexp.action.add")))
            }
            if !viewModel.results.isEmpty {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label(L10nString("certexp.action.refresh"), systemImage: "arrow.clockwise")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isChecking)
            }
        }
    }

    private var listSection: some View {
        SectionCard(title: L10n("certexp.section.hosts"), systemImage: "lock.doc") {
            ForEach(viewModel.results) { result in
                row(result)
                if result.id != viewModel.results.last?.id {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }

    private func row(_ result: CertExpiryResult) -> some View {
        let level = CertExpiryEngine.level(days: result.daysRemaining)
        return HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.host)
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                if let error = result.error {
                    Text(error).font(AppTypography.caption).foregroundStyle(theme.danger).lineLimit(1)
                } else if let notAfter = result.notAfter {
                    Text(notAfter).font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Spacer()
            expiryBadge(level: level, days: result.daysRemaining, checking: viewModel.isChecking, hasError: result.error != nil)
            Button {
                viewModel.remove(result.host)
            } label: {
                Image(systemName: "trash").font(.caption).foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n("common.delete")))
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func expiryBadge(level: CertExpiryLevel, days: Int?, checking: Bool, hasError: Bool) -> some View {
        if hasError {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.warning)
        } else if let days {
            let color: Color = {
                switch level {
                case .ok: theme.success
                case .warning: theme.warning
                case .critical, .expired: theme.danger
                case .unknown: theme.textSecondary
                }
            }()
            Text(days < 0 ? L10nString("certexp.expired") : String(format: L10nString("certexp.days"), days))
                .font(AppTypography.monoCaption.weight(.semibold))
                .foregroundStyle(color)
                .environment(\.layoutDirection, .leftToRight)
        } else if checking {
            ProgressView()
        } else {
            Text("—").foregroundStyle(theme.textSecondary)
        }
    }

    private var noteSection: some View {
        Text(L10n("certexp.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
