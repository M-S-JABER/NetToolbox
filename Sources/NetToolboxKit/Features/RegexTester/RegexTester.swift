import SwiftUI
import Observation

struct RegexMatch: Identifiable, Sendable, Equatable {
    let id: Int
    let full: String
    let groups: [String]
}

/// Tests an NSRegularExpression pattern against a string. Pure logic.
enum RegexTools {
    static func matches(pattern: String, text: String, caseInsensitive: Bool) -> Result<[RegexMatch], String> {
        guard !pattern.isEmpty else { return .success([]) }
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return .failure(L10nString("regex.invalid"))
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var results: [RegexMatch] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let full = match.range.location != NSNotFound ? nsText.substring(with: match.range) : ""
            var groups: [String] = []
            if match.numberOfRanges > 1 {
                for index in 1..<match.numberOfRanges {
                    let groupRange = match.range(at: index)
                    groups.append(groupRange.location != NSNotFound ? nsText.substring(with: groupRange) : "")
                }
            }
            results.append(RegexMatch(id: results.count, full: full, groups: groups))
        }
        return .success(results)
    }
}

@MainActor
@Observable
final class RegexTesterViewModel {
    var pattern = ""
    var text = ""
    var caseInsensitive = false

    var result: Result<[RegexMatch], String>? {
        pattern.isEmpty ? nil : RegexTools.matches(pattern: pattern, text: text, caseInsensitive: caseInsensitive)
    }
}

struct RegexTesterTool: NetworkTool {
    let id = "regex"
    let titleKey = L10n("tool.regex.title")
    let subtitleKey = L10n("tool.regex.subtitle")
    let systemImage = "textformat.abc.dottedunderline"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(RegexTesterView()) }
}

@MainActor
struct RegexTesterView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = RegexTesterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
                Text(L10n("regex.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.regex.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("regex.input.title"), systemImage: "textformat") {
            TextField(L10nString("regex.input.pattern"), text: $viewModel.pattern)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10nString("regex.input.text"), text: $viewModel.text, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                .lineLimit(3...8)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            Toggle(isOn: $viewModel.caseInsensitive) {
                Text(L10n("regex.caseInsensitive")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.result {
        case .none:
            EmptyView()
        case .failure(let message):
            SectionCard(title: L10n("regex.invalid"), systemImage: "exclamationmark.triangle") {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        case .success(let matches):
            SectionCard(title: L10n("regex.section.matches"), systemImage: "text.magnifyingglass") {
                if matches.isEmpty {
                    Text(L10n("regex.noMatch")).font(AppTypography.body).foregroundStyle(theme.textSecondary)
                } else {
                    Text(String(format: L10nString("regex.count"), matches.count))
                        .font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                    ForEach(matches) { match in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.full).font(AppTypography.monoBody).foregroundStyle(theme.accent)
                                .environment(\.layoutDirection, .leftToRight)
                            if !match.groups.isEmpty {
                                Text(match.groups.enumerated().map { "$\($0 + 1)=\($1)" }.joined(separator: "  "))
                                    .font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        if match.id != matches.last?.id { Divider().overlay(theme.separator) }
                    }
                }
            }
        }
    }
}
