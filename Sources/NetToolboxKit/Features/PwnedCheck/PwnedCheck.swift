import SwiftUI
import Observation
import CryptoKit

/// Checks a password against Have I Been Pwned's breach corpus using the
/// **k-anonymity** range API: only the first 5 hex chars of the SHA-1 are sent,
/// never the password or full hash. All native.
enum PwnedCheck {
    static func sha1Hex(_ text: String) -> String {
        Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02X", $0) }.joined()
    }

    /// (first 5 hex, remaining suffix) of the uppercase SHA-1.
    static func split(_ text: String) -> (prefix: String, suffix: String) {
        let hash = sha1Hex(text)
        let prefix = String(hash.prefix(5))
        let suffix = String(hash.dropFirst(5))
        return (prefix, suffix)
    }

    /// Finds the breach count for `suffix` in a range-API response body.
    static func countInResponse(_ body: String, suffix: String) -> Int {
        // `\r\n` is a single Swift grapheme, so matching "\n"/"\r" individually
        // would miss CRLF line breaks (which the range API actually returns).
        for line in body.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":")
            guard parts.count == 2 else { continue }
            if parts[0].uppercased() == suffix {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }
}

struct PwnedService: Sendable {
    func check(password: String) async throws -> Int {
        let (prefix, suffix) = PwnedCheck.split(password)
        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else {
            throw NetworkServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("true", forHTTPHeaderField: "Add-Padding")
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NetworkServiceError.badStatus(http.statusCode)
        }
        return PwnedCheck.countInResponse(String(decoding: data, as: UTF8.self), suffix: suffix)
    }
}

@MainActor
@Observable
final class PwnedCheckViewModel {
    enum Output: Equatable {
        case idle, checking
        case safe
        case pwned(Int)
        case failure(String)
    }

    var password = ""
    private(set) var output: Output = .idle

    private let service = PwnedService()

    func check() async {
        guard !password.isEmpty else { output = .idle; return }
        output = .checking
        do {
            let count = try await service.check(password: password)
            output = count == 0 ? .safe : .pwned(count)
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct PwnedCheckTool: NetworkTool {
    let id = "pwned-check"
    let titleKey = L10n("tool.pwned.title")
    let subtitleKey = L10n("tool.pwned.subtitle")
    let systemImage = "lock.trianglebadge.exclamationmark"
    let category: ToolCategory = .security

    func makeView() -> AnyView { AnyView(PwnedCheckView()) }
}

@MainActor
struct PwnedCheckView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = PwnedCheckViewModel()
    @State private var reveal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                resultSection
                Text(L10n("pwned.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.pwned.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("pwned.input.title"), systemImage: "key") {
            HStack(spacing: Spacing.sm) {
                Group {
                    if reveal {
                        TextField(L10nString("pwned.input.password"), text: $viewModel.password)
                    } else {
                        SecureField(L10nString("pwned.input.password"), text: $viewModel.password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                Button {
                    reveal.toggle()
                } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(theme.textSecondary)
                }
            }
            Button {
                Task { await viewModel.check() }
            } label: {
                Label(L10nString("pwned.action.check"), systemImage: "checkmark.shield")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.password.isEmpty || viewModel.output == .checking)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.output {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: Spacing.md) { ProgressView(); Text(L10n("common.loading")).foregroundStyle(theme.textSecondary) }
        case .safe:
            SectionCard(title: L10n("pwned.section.result"), systemImage: "checkmark.seal.fill") {
                HStack(spacing: Spacing.sm) {
                    StatusBadge(kind: .success, text: L10n("pwned.safe.badge"))
                    Text(L10n("pwned.safe.message")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                }
            }
        case .pwned(let count):
            SectionCard(title: L10n("pwned.section.result"), systemImage: "exclamationmark.triangle.fill") {
                StatusBadge(kind: .danger, text: L10n("pwned.found.badge"))
                Text(String(format: L10nString("pwned.found.message"), count))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.danger)
            }
        case .failure(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle") {
                Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        }
    }
}
