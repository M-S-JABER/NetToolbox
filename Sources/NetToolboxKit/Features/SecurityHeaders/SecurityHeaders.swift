import SwiftUI
import Observation

struct SecurityHeaderCheck: Identifiable, Sendable {
    let id: String
    let name: String
    let present: Bool
    let value: String
    let advice: String
}

/// Grades a site's HTTP response for the common security headers.
struct SecurityHeadersService: Sendable {
    private static let headers: [(field: String, name: String, advice: String)] = [
        ("Strict-Transport-Security", "HSTS", "Forces HTTPS for future visits."),
        ("Content-Security-Policy", "CSP", "Limits where scripts/resources can load from."),
        ("X-Content-Type-Options", "X-Content-Type-Options", "Stops MIME-type sniffing (nosniff)."),
        ("X-Frame-Options", "X-Frame-Options", "Prevents clickjacking via framing."),
        ("Referrer-Policy", "Referrer-Policy", "Controls the Referer header sent to other sites."),
        ("Permissions-Policy", "Permissions-Policy", "Restricts powerful browser features."),
    ]

    func grade(urlString: String) async throws -> (checks: [SecurityHeaderCheck], score: Int) {
        var text = urlString.trimmingCharacters(in: .whitespaces)
        if !text.lowercased().hasPrefix("http") { text = "https://\(text)" }
        guard let url = URL(string: text) else { throw NetworkServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkServiceError.decoding }

        var checks: [SecurityHeaderCheck] = []
        var present = 0
        for header in Self.headers {
            let value = http.value(forHTTPHeaderField: header.field) ?? ""
            let has = !value.isEmpty
            if has { present += 1 }
            checks.append(SecurityHeaderCheck(id: header.field, name: header.name, present: has, value: value, advice: header.advice))
        }
        return (checks, Int(Double(present) / Double(Self.headers.count) * 100))
    }
}

@MainActor
@Observable
final class SecurityHeadersViewModel {
    var url = ""
    private(set) var checks: [SecurityHeaderCheck] = []
    private(set) var score = 0
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private let service = SecurityHeadersService()

    func run() async {
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isRunning = true
        errorMessage = nil
        checks = []
        do {
            let result = try await service.grade(urlString: url)
            checks = result.checks
            score = result.score
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

struct SecurityHeadersTool: NetworkTool {
    let id = "security-headers"
    let titleKey = L10n("tool.secheaders.title")
    let subtitleKey = L10n("tool.secheaders.subtitle")
    let systemImage = "checkerboard.shield"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(SecurityHeadersView()) }
}

struct SecurityHeadersView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SecurityHeadersViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("secheaders.input.title"), systemImage: "checkerboard.shield") {
                    TextField(L10nString("httptiming.input.url"), text: $viewModel.url)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        Task { await viewModel.run() }
                    } label: {
                        Label(L10nString("secheaders.action.grade"), systemImage: "checkmark.shield").font(AppTypography.headline)
                    }
                    .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
                    if viewModel.isRunning { ProgressView() }
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if !viewModel.checks.isEmpty {
                    scoreCard
                    resultsCard
                }
                Text(L10n("secheaders.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.secheaders.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var scoreCard: some View {
        SectionCard(title: L10n("secheaders.section.score"), systemImage: "gauge") {
            HStack {
                Text("\(viewModel.score)%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.score >= 67 ? theme.success : (viewModel.score >= 34 ? theme.warning : theme.danger))
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
            }
        }
    }

    private var resultsCard: some View {
        SectionCard(title: L10n("secheaders.section.headers"), systemImage: "list.bullet") {
            ForEach(viewModel.checks) { check in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: check.present ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundStyle(check.present ? theme.success : theme.warning)
                        Text(check.name).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                    if check.present, !check.value.isEmpty {
                        Text(check.value).font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                            .lineLimit(2).environment(\.layoutDirection, .leftToRight)
                    } else {
                        Text(check.advice).font(AppTypography.footnote).foregroundStyle(theme.textSecondary)
                    }
                }
                if check.id != viewModel.checks.last?.id { Divider().overlay(theme.separator) }
            }
        }
    }
}
