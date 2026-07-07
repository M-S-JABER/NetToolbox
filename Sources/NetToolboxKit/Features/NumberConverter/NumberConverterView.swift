import SwiftUI
import Observation

@MainActor
@Observable
final class NumberConverterViewModel {
    var input = ""
    private(set) var result: NumberConverter.Result?
    private(set) var errorMessage: String?

    func convert() {
        errorMessage = nil
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else {
            result = nil
            return
        }
        do {
            result = NumberConverter.format(try NumberConverter.parse(input))
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }
}

struct NumberConverterTool: NetworkTool {
    let id = "number-converter"
    let titleKey = L10n("tool.number.title")
    let subtitleKey = L10n("tool.number.subtitle")
    let systemImage = "number"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(NumberConverterView()) }
}

@MainActor
struct NumberConverterView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = NumberConverterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("number.input.title"), systemImage: "keyboard") {
                    TextField(L10nString("number.input.placeholder"), text: $viewModel.input)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .environment(\.layoutDirection, .leftToRight)
                        .onChange(of: viewModel.input) { viewModel.convert() }
                    Text(L10n("number.hint"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                if let message = viewModel.errorMessage {
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                }

                if let result = viewModel.result {
                    SectionCard(title: L10n("number.output.title"), systemImage: "arrow.left.arrow.right") {
                        row("HEX", result.hex)
                        row("DEC", result.decimal)
                        row("OCT", result.octal)
                        row("BIN", result.binary)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.number.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(label)
                .font(AppTypography.monoCaption.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 44, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            Text(value)
                .font(AppTypography.monoBody)
                .foregroundStyle(theme.mono)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
