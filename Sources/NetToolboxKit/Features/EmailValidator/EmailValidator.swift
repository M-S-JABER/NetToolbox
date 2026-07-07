import SwiftUI
import Observation

/// Pure email syntax validation. Unit-tested; the MX check is layered on top.
enum EmailValidator {
    /// The domain part of an email, or nil if the address is malformed.
    static func domain(of email: String) -> String? {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return String(parts[1])
    }

    /// A pragmatic RFC-5322-lite syntax check.
    static func isValidSyntax(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(" ") else { return false }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, !domain.isEmpty else { return false }
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }

        let localOK = local.allSatisfy { $0.isLetter || $0.isNumber || "._%+-".contains($0) }
        let domainOK = domain.allSatisfy { $0.isLetter || $0.isNumber || ".-".contains($0) }
        return localOK && domainOK
    }
}

@MainActor
@Observable
final class EmailValidatorViewModel {
    struct Result: Equatable {
        let syntaxValid: Bool
        let domain: String
        let mxRecords: [String]
        var deliverable: Bool { syntaxValid && !mxRecords.isEmpty }
    }

    enum Output: Equatable {
        case idle, checking
        case result(Result)
    }

    var email = ""
    private(set) var output: Output = .idle

    private let resolver: any DNSResolving

    init(resolver: any DNSResolving = UDPDNSResolver()) {
        self.resolver = resolver
    }

    func check() async {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }

        let valid = EmailValidator.isValidSyntax(trimmed)
        guard valid, let domain = EmailValidator.domain(of: trimmed) else {
            output = .result(Result(syntaxValid: false, domain: "", mxRecords: []))
            return
        }
        output = .checking
        let mx = (try? await resolver.resolve(name: domain, type: .mx, server: "1.1.1.1")) ?? []
        output = .result(Result(syntaxValid: true, domain: domain, mxRecords: mx.map(\.value)))
    }
}

struct EmailValidatorTool: NetworkTool {
    let id = "email-validator"
    let titleKey = L10n("tool.email.title")
    let subtitleKey = L10n("tool.email.subtitle")
    let systemImage = "envelope.badge.shield.half.filled"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(EmailValidatorView()) }
}

@MainActor
struct EmailValidatorView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = EmailValidatorViewModel()

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
        .navigationTitle(Text(L10n("tool.email.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("email.input.title"), systemImage: "envelope") {
            TextField(L10nString("email.input.placeholder"), text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await viewModel.check() } }

            Button {
                Task { await viewModel.check() }
            } label: {
                Label(L10nString("email.action.check"), systemImage: "checkmark.shield")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            ContentUnavailableView {
                Label(L10nString("email.empty.title"), systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text(L10n("email.empty.description"))
            }
        case .checking:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("email.checking")).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .result(let result):
            resultCard(result)
        }
    }

    private func resultCard(_ result: EmailValidatorViewModel.Result) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionCard(title: L10n("email.section.summary"), systemImage: "checkmark.seal") {
                HStack {
                    StatusBadge(kind: result.syntaxValid ? .success : .danger, text: L10n("email.syntax"))
                    Spacer()
                    if result.syntaxValid {
                        StatusBadge(
                            kind: result.deliverable ? .success : .warning,
                            text: result.deliverable ? L10n("email.deliverable") : L10n("email.noMX")
                        )
                    }
                }
            }
            if result.syntaxValid, !result.mxRecords.isEmpty {
                SectionCard(title: L10n("email.section.mx"), systemImage: "tray.full") {
                    VStack(spacing: Spacing.sm) {
                        ForEach(result.mxRecords, id: \.self) { record in
                            HStack {
                                CopyableValue(value: record)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}
