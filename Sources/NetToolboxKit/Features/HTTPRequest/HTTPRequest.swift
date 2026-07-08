import SwiftUI
import Observation

struct HTTPRequestResult: Equatable, Sendable {
    let statusCode: Int
    let headers: [HTTPHeaderField]
    let body: String
}

/// Sends a configurable HTTP request and returns status, headers and body.
protocol HTTPRequesting: Sendable {
    func send(method: String, url: String, headers: [(String, String)], body: String) async throws -> HTTPRequestResult
}

struct HTTPRequestService: HTTPRequesting {
    func send(method: String, url: String, headers: [(String, String)], body: String) async throws -> HTTPRequestResult {
        var normalized = url.trimmingCharacters(in: .whitespaces)
        if !normalized.lowercased().hasPrefix("http") { normalized = "https://" + normalized }
        guard let requestURL = URL(string: normalized) else { throw NetworkServiceError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("NetToolbox/1.0", forHTTPHeaderField: "User-Agent")
        for (key, value) in headers where !key.isEmpty {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if !body.isEmpty, method != "GET", method != "HEAD" {
            request.httpBody = Data(body.utf8)
        }

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw NetworkServiceError.decoding }
            let responseHeaders = http.allHeaderFields
                .compactMap { key, value -> HTTPHeaderField? in
                    guard let name = key as? String else { return nil }
                    return HTTPHeaderField(name: name, value: "\(value)")
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            let text = String(decoding: data.prefix(20_000), as: UTF8.self)
            return HTTPRequestResult(statusCode: http.statusCode, headers: responseHeaders, body: text)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkServiceError.offline
        }
    }
}

@MainActor
@Observable
final class HTTPRequestViewModel {
    enum Output: Equatable {
        case idle, loading
        case result(HTTPRequestResult)
        case failure(String)
    }

    var method = "GET"
    var url = ""
    var headersText = ""
    var body = ""
    private(set) var output: Output = .idle

    let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"]

    private let service: any HTTPRequesting

    init(service: any HTTPRequesting = HTTPRequestService()) {
        self.service = service
    }

    private func parseHeaders() -> [(String, String)] {
        headersText.split(whereSeparator: \.isNewline).compactMap { line in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return key.isEmpty ? nil : (key, value)
        }
    }

    func send() async {
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty else { output = .idle; return }
        output = .loading
        do {
            output = .result(try await service.send(method: method, url: url, headers: parseHeaders(), body: body))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct HTTPRequestTool: NetworkTool {
    let id = "http-request"
    let titleKey = L10n("tool.httpreq.title")
    let subtitleKey = L10n("tool.httpreq.subtitle")
    let systemImage = "paperplane"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(HTTPRequestView()) }
}

@MainActor
struct HTTPRequestView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = HTTPRequestViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                requestCard
                outputSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.httpreq.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var requestCard: some View {
        SectionCard(title: L10n("httpreq.section.request"), systemImage: "paperplane") {
            Picker(L10nString("httpreq.method"), selection: $viewModel.method) {
                ForEach(viewModel.methods, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Spacing.sm) {
                TextField(L10nString("httpreq.url"), text: $viewModel.url)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.URL).autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.url)
            }

            TextField(L10nString("httpreq.headers"), text: $viewModel.headersText, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                .lineLimit(2...5).autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            if viewModel.method != "GET", viewModel.method != "HEAD" {
                TextField(L10nString("httpreq.body"), text: $viewModel.body, axis: .vertical)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                    .lineLimit(2...6).autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Button {
                Task { await viewModel.send() }
            } label: {
                Label(L10nString("httpreq.send"), systemImage: "paperplane.fill")
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
        case .result(let result):
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("http.section.status"), systemImage: "info.circle") {
                    HStack {
                        StatusBadge(kind: statusKind(result.statusCode), text: L10n("http.badge.status"))
                        Text(String(result.statusCode))
                            .font(AppTypography.monoLarge).foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                }
                if !result.body.isEmpty {
                    SectionCard(title: L10n("httpreq.section.body"), systemImage: "curlybraces") {
                        Text(result.body)
                            .font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }
}
