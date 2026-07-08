import SwiftUI
import Observation

/// One email-authentication record's lookup result.
struct EmailSecurityRecord: Identifiable, Sendable {
    let id: String
    let title: String
    let found: Bool
    let value: String
    let hint: String
}

/// Looks up the email-authentication records for a domain — SPF, DMARC and a
/// DKIM selector — over DNS-over-HTTPS (reusing `DoHResolver`, all TXT records).
@MainActor
@Observable
final class EmailSecurityViewModel {
    var domain = ""
    var selector = "default"
    private(set) var records: [EmailSecurityRecord] = []
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    func run() async {
        let name = domain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        let dkimSelector = selector.trimmingCharacters(in: .whitespaces).isEmpty ? "default" : selector.trimmingCharacters(in: .whitespaces)

        isRunning = true
        errorMessage = nil
        records = []
        let resolver = DoHResolver()

        do {
            let spf = try await txt(resolver, name, contains: "v=spf1")
            let dmarc = try await txt(resolver, "_dmarc.\(name)", contains: "v=dmarc1")
            let dkim = try await txt(resolver, "\(dkimSelector)._domainkey.\(name)", contains: "p=")

            records = [
                EmailSecurityRecord(
                    id: "spf", title: "SPF", found: spf != nil,
                    value: spf ?? L10nString("emailsec.missing"),
                    hint: L10nString("emailsec.spf.hint")
                ),
                EmailSecurityRecord(
                    id: "dmarc", title: "DMARC", found: dmarc != nil,
                    value: dmarc ?? L10nString("emailsec.missing"),
                    hint: L10nString("emailsec.dmarc.hint")
                ),
                EmailSecurityRecord(
                    id: "dkim", title: "DKIM (\(dkimSelector))", found: dkim != nil,
                    value: dkim ?? L10nString("emailsec.missing"),
                    hint: L10nString("emailsec.dkim.hint")
                ),
            ]
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }

    /// Returns the first TXT value (loosely) matching `needle`, else nil.
    private func txt(_ resolver: DoHResolver, _ name: String, contains needle: String) async throws -> String? {
        let records = try await resolver.resolve(name: name, type: .txt, server: "cloudflare-dns.com")
        return records
            .map { $0.value.replacingOccurrences(of: "\"", with: "") }
            .first { $0.lowercased().contains(needle) }
    }
}

struct EmailSecurityTool: NetworkTool {
    let id = "email-security"
    let titleKey = L10n("tool.emailsec.title")
    let subtitleKey = L10n("tool.emailsec.subtitle")
    let systemImage = "envelope.badge"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(EmailSecurityView()) }
}

@MainActor
struct EmailSecurityView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = EmailSecurityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle") {
                        Text(errorMessage).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                }
                ForEach(viewModel.records) { record in
                    recordCard(record)
                }
                Text(L10n("emailsec.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.emailsec.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("emailsec.input.title"), systemImage: "envelope") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("emailsec.input.domain"), text: $viewModel.domain)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.domain)
            }
            HStack {
                Text(L10n("emailsec.input.selector")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                TextField("default", text: $viewModel.selector)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("emailsec.action.check"), systemImage: "magnifyingglass")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private func recordCard(_ record: EmailSecurityRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: record.found ? "checkmark.seal" : "xmark.seal")
                    .foregroundStyle(record.found ? theme.success : theme.warning)
                Text(record.title)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                StatusBadge(kind: record.found ? .success : .warning, text: record.found ? L10n("emailsec.present") : L10n("emailsec.absent"))
            }
            Text(record.value)
                .font(AppTypography.monoCaption)
                .foregroundStyle(record.found ? theme.textPrimary : theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            Text(record.hint)
                .font(AppTypography.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(theme.surface)
        )
    }
}
