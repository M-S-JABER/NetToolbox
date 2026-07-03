import SwiftUI
import Observation

@MainActor
@Observable
final class QRGeneratorViewModel {
    var text = ""
}

struct QRGeneratorTool: NetworkTool {
    let id = "qr-generator"
    let titleKey = L10n("tool.qr.title")
    let subtitleKey = L10n("tool.qr.subtitle")
    let systemImage = "qrcode.viewfinder"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(QRGeneratorView()) }
}

struct QRGeneratorView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = QRGeneratorViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("qr.input.title"), systemImage: "text.cursor") {
                    TextField(L10nString("qr.input.placeholder"), text: $viewModel.text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .lineLimit(2...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                }

                if !viewModel.text.isEmpty {
                    SectionCard(title: L10n("qr.section.code"), systemImage: "qrcode") {
                        #if canImport(UIKit)
                        if let image = QRCode.image(from: viewModel.text) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(Color.white))
                        }
                        #endif
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.qr.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
