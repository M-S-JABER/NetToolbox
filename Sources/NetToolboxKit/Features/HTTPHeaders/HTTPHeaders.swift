import SwiftUI
import Observation

/// A captured HTTP response summary.
struct HTTPResponseInfo: Equatable, Sendable {
    let statusCode: Int
    let finalURL: String
    let headers: [HTTPHeaderField]
}

struct HTTPHeaderField: Identifiable, Equatable, Sendable {
    let name: String
    let value: String
    var id: String { name }
}

/// Fetches a URL and reports its status line and response headers.
protocol HTTPInspecting: Sendable {
    func inspect(_ urlString: String) async throws -> HTTPResponseInfo
}

struct HTTPInspectorService: HTTPInspecting {
    func inspect(_ urlString: String) async throws -> HTTPResponseInfo {
        var normalized = urlString.trimmingCharacters(in: .whitespaces)
        if !normalized.lowercased().hasPrefix("http://") && !normalized.lowercased().hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        guard let url = URL(string: normalized) else {
            throw NetworkServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("NetToolbox/1.0", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkServiceError.decoding
            }
            let headers = http.allHeaderFields
                .compactMap { key, value -> HTTPHeaderField? in
                    guard let name = key as? String else { return nil }
                    return HTTPHeaderField(name: name, value: "\(value)")
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            return HTTPResponseInfo(
                statusCode: http.statusCode,
                finalURL: http.url?.absoluteString ?? normalized,
                headers: headers
            )
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkServiceError.offline
        }
    }
}

@MainActor
@Observable
final class HTTPHeadersViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(HTTPResponseInfo)
        case failure(String)
    }

    var urlString = ""
    private(set) var output: Output = .idle

    private let service: any HTTPInspecting

    init(service: any HTTPInspecting = HTTPInspectorService()) {
        self.service = service
    }

    func inspect() async {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        output = .loading
        do {
            output = .success(try await service.inspect(trimmed))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct HTTPHeadersTool: NetworkTool {
    let id = "http-headers"
    let titleKey = L10n("tool.http.title")
    let subtitleKey = L10n("tool.http.subtitle")
    let systemImage = "doc.text.below.ecg"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(HTTPHeadersView()) }
}

@MainActor
struct HTTPHeadersView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = HTTPHeadersViewModel()

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
        .navigationTitle(Text(L10n("tool.http.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("http.input.title"), systemImage: "link") {
            TextField(L10nString("http.input.url"), text: $viewModel.urlString)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await viewModel.inspect() } }

            Button {
                Task { await viewModel.inspect() }
            } label: {
                Label(L10nString("http.action.fetch"), systemImage: "arrow.down.circle")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func statusKind(_ code: Int) -> StatusBadge.Kind {
        switch code {
        case 200..<300: .success
        case 300..<400: .info
        case 400..<500: .warning
        default: .danger
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            ContentUnavailableView {
                Label(L10nString("http.empty.title"), systemImage: "doc.text.below.ecg")
            } description: {
                Text(L10n("http.empty.description"))
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("http.section.status"), systemImage: "info.circle") {
                    HStack {
                        StatusBadge(kind: statusKind(info.statusCode), text: L10n("http.badge.status"))
                        Text(String(info.statusCode))
                            .font(AppTypography.monoLarge)
                            .foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                    Divider().overlay(theme.separator)
                    HStack {
                        Text(L10n("http.result.finalURL"))
                            .font(AppTypography.footnote)
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        CopyableValue(value: info.finalURL, font: AppTypography.monoCaption)
                    }
                }
                SectionCard(title: L10n("http.section.headers"), systemImage: "list.bullet.rectangle") {
                    VStack(spacing: Spacing.sm) {
                        ForEach(info.headers) { header in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(header.name)
                                    .font(AppTypography.monoCaption.weight(.semibold))
                                    .foregroundStyle(theme.accent)
                                    .environment(\.layoutDirection, .leftToRight)
                                Text(header.value)
                                    .font(AppTypography.monoCaption)
                                    .foregroundStyle(theme.textPrimary)
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
}
