import SwiftUI
import Observation

/// Guesses the likely algorithm(s) that produced a hash string from its length
/// and character set / prefix. Pure heuristics — no network.
enum HashID {
    static func identify(_ input: String) -> [String] {
        let hash = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hash.isEmpty else { return [] }

        // Prefixed crypt / modular formats first.
        let prefixes: [(String, String)] = [
            ("$2a$", "bcrypt"), ("$2b$", "bcrypt"), ("$2y$", "bcrypt"),
            ("$1$", "md5crypt"), ("$5$", "sha256crypt"), ("$6$", "sha512crypt"),
            ("$apr1$", "Apache apr1-md5"), ("$argon2", "Argon2"),
            ("$pbkdf2", "PBKDF2"), ("{SSHA}", "Salted SHA-1 (LDAP)"), ("{SHA}", "SHA-1 (LDAP)"),
        ]
        for (prefix, name) in prefixes where hash.hasPrefix(prefix) {
            return [name]
        }

        let isHex = hash.allSatisfy { $0.isHexDigit }
        if isHex {
            switch hash.count {
            case 32: return ["MD5", "NTLM", "MD4", "LM"]
            case 40: return ["SHA-1", "RIPEMD-160"]
            case 56: return ["SHA-224", "SHA3-224"]
            case 64: return ["SHA-256", "SHA3-256", "BLAKE2s"]
            case 96: return ["SHA-384", "SHA3-384"]
            case 128: return ["SHA-512", "SHA3-512", "BLAKE2b", "Whirlpool"]
            case 16: return ["CRC-64", "MySQL 3.23"]
            case 8: return ["CRC-32", "Adler-32"]
            default: break
            }
        }

        // base64-ish
        let isBase64 = hash.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" }
        if isBase64, hash.count == 24, hash.hasSuffix("==") {
            return ["MD5 (base64)"]
        }
        if isBase64, hash.count == 28, hash.hasSuffix("=") {
            return ["SHA-1 (base64)"]
        }
        if isBase64, hash.count == 44, hash.hasSuffix("=") {
            return ["SHA-256 (base64)"]
        }
        return []
    }
}

@MainActor
@Observable
final class HashIDViewModel {
    var input = ""
    var candidates: [String] { HashID.identify(input) }
}

struct HashIDTool: NetworkTool {
    let id = "hash-id"
    let titleKey = L10n("tool.hashid.title")
    let subtitleKey = L10n("tool.hashid.subtitle")
    let systemImage = "questionmark.square.dashed"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(HashIDView()) }
}

struct HashIDView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = HashIDViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("hashid.input.title"), systemImage: "number") {
                    TextField(L10nString("hashid.input.hash"), text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoCaption)
                        .lineLimit(1...4)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                }
                if !viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty {
                    resultsSection
                }
                Text(L10n("hashid.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.hashid.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.candidates.isEmpty {
            SectionCard(title: L10n("hashid.section.candidates"), systemImage: "questionmark.circle") {
                Text(L10n("hashid.none")).font(AppTypography.body).foregroundStyle(theme.textSecondary)
            }
        } else {
            SectionCard(title: L10n("hashid.section.candidates"), systemImage: "list.bullet") {
                ForEach(viewModel.candidates, id: \.self) { candidate in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "number").font(.caption).foregroundStyle(theme.accent)
                        Text(candidate)
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                }
            }
        }
    }
}
