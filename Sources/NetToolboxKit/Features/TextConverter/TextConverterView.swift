import SwiftUI
import Observation

@MainActor
@Observable
final class TextConverterViewModel {
    var input = ""
    var operation: TextConverter.Operation = .base64Encode
    private(set) var output = ""
    private(set) var errorMessage: String?

    func convert() {
        errorMessage = nil
        guard !input.isEmpty else { output = ""; return }
        do {
            output = try TextConverter.apply(operation, to: input)
        } catch {
            output = ""
            errorMessage = error.localizedDescription
        }
    }
}

struct TextConverterTool: NetworkTool {
    let id = "text-converter"
    let titleKey = L10n("tool.convert.title")
    let subtitleKey = L10n("tool.convert.subtitle")
    let systemImage = "arrow.left.arrow.right.square"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(TextConverterView()) }
}

struct TextConverterView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = TextConverterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.output.isEmpty {
                    outputSection
                }
                if let message = viewModel.errorMessage {
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.convert.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("convert.input.title"), systemImage: "keyboard") {
            Picker(L10nString("convert.operation"), selection: $viewModel.operation) {
                ForEach(TextConverter.Operation.allCases) { op in
                    Text(L10n(op.labelKey)).tag(op)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.operation) { viewModel.convert() }

            TextField(L10nString("convert.input.placeholder"), text: $viewModel.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .lineLimit(3...8)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .onChange(of: viewModel.input) { viewModel.convert() }
        }
    }

    private var outputSection: some View {
        SectionCard(title: L10n("convert.output.title"), systemImage: "text.alignleft") {
            Text(viewModel.output)
                .font(AppTypography.monoBody)
                .foregroundStyle(theme.mono)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            HStack {
                Spacer()
                CopyButton(value: viewModel.output)
            }
        }
    }
}
