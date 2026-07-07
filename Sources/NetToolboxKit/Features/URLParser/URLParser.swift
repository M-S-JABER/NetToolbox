import SwiftUI
import Observation

/// Breaks a URL into its components. Pure logic (URLComponents).
enum URLParse {
    static func components(_ string: String) -> [(label: String, value: String)]? {
        guard let comps = URLComponents(string: string.trimmingCharacters(in: .whitespaces)), comps.scheme != nil || comps.host != nil else {
            return nil
        }
        var rows: [(String, String)] = []
        func add(_ label: String, _ value: String?) { if let value, !value.isEmpty { rows.append((label, value)) } }
        add("Scheme", comps.scheme)
        add("User", comps.user)
        add("Password", comps.password)
        add("Host", comps.host)
        add("Port", comps.port.map(String.init))
        add("Path", comps.path.isEmpty ? nil : comps.path)
        add("Fragment", comps.fragment)
        for item in comps.queryItems ?? [] {
            rows.append(("query: \(item.name)", item.value ?? ""))
        }
        return rows
    }
}

@MainActor
@Observable
final class URLParserViewModel {
    var input = ""
    var rows: [(label: String, value: String)]? { input.isEmpty ? nil : URLParse.components(input) }
}

struct URLParserTool: NetworkTool {
    let id = "url-parser"
    let titleKey = L10n("tool.urlparser.title")
    let subtitleKey = L10n("tool.urlparser.subtitle")
    let systemImage = "link.badge.plus"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(URLParserView()) }
}

@MainActor
struct URLParserView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = URLParserViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("urlparser.input.title"), systemImage: "link") {
                    TextField(L10nString("urlparser.input.url"), text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                        .lineLimit(1...4)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                        .environment(\.layoutDirection, .leftToRight)
                }
                if let rows = viewModel.rows {
                    if rows.isEmpty {
                        Text(L10n("urlparser.invalid")).font(AppTypography.footnote).foregroundStyle(theme.danger)
                    } else {
                        SectionCard(title: L10n("urlparser.section.result"), systemImage: "list.bullet") {
                            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top) {
                                    Text(row.label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                                        .frame(minWidth: 90, alignment: .leading)
                                    CopyableValue(value: row.value, font: AppTypography.monoCaption)
                                }
                            }
                        }
                    }
                }
                Text(L10n("urlparser.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.urlparser.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
