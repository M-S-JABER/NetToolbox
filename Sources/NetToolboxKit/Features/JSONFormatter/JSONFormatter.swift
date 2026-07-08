import SwiftUI
import Observation

/// Validates and pretty-prints / minifies JSON via Foundation's parser.
enum JSONTools {
    static func transform(_ text: String, minify: Bool) -> Result<String, EngineError> {
        let data = Data(text.utf8)
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let options: JSONSerialization.WritingOptions = minify
                ? [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
                : [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
            let output = try JSONSerialization.data(withJSONObject: object, options: options)
            return .success(String(decoding: output, as: UTF8.self))
        } catch {
            return .failure(EngineError(error.localizedDescription))
        }
    }
}

@MainActor
@Observable
final class JSONFormatterViewModel {
    var input = ""
    var minify = false

    var output: Result<String, EngineError>? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : JSONTools.transform(input, minify: minify)
    }
}

struct JSONFormatterTool: NetworkTool {
    let id = "json-formatter"
    let titleKey = L10n("tool.json.title")
    let subtitleKey = L10n("tool.json.subtitle")
    let systemImage = "curlybraces"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(JSONFormatterView()) }
}

@MainActor
struct JSONFormatterView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = JSONFormatterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("json.input.title"), systemImage: "curlybraces") {
                    TextField(L10nString("json.input.placeholder"), text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder).font(AppTypography.monoCaption)
                        .lineLimit(3...12)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    Toggle(isOn: $viewModel.minify) {
                        Text(L10n("json.minify")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                    }
                }
                outputSection
                Text(L10n("json.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.json.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .none:
            EmptyView()
        case .success(let json):
            SectionCard(title: L10n("json.section.output"), systemImage: "checkmark.seal") {
                Text(json)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
                CopyButton(value: json)
            }
        case .failure(let message):
            SectionCard(title: L10n("json.invalid"), systemImage: "exclamationmark.triangle") {
                Text(message.description).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }
}
