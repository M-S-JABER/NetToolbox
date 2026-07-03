import SwiftUI
import Observation

@MainActor
@Observable
final class PasswordGeneratorViewModel {
    var options = PasswordGenerator.Options()
    private(set) var password = ""

    var entropy: Double { PasswordGenerator.entropyBits(for: options) }
    var strength: PasswordGenerator.Strength { PasswordGenerator.strength(bits: entropy) }

    func generate() {
        password = PasswordGenerator.generate(options)
    }
}

struct PasswordGeneratorTool: NetworkTool {
    let id = "password-generator"
    let titleKey = L10n("tool.password.title")
    let subtitleKey = L10n("tool.password.subtitle")
    let systemImage = "key.horizontal"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(PasswordGeneratorView()) }
}

struct PasswordGeneratorView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = PasswordGeneratorViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                outputCard
                optionsCard
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.password.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { if viewModel.password.isEmpty { viewModel.generate() } }
    }

    private var outputCard: some View {
        SectionCard(title: L10n("password.output.title"), systemImage: "key.horizontal") {
            Text(viewModel.password.isEmpty ? " " : viewModel.password)
                .font(AppTypography.monoLarge)
                .foregroundStyle(theme.mono)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.small).fill(theme.background))

            HStack {
                StatusBadge(kind: strengthKind, text: L10n(viewModel.strength.labelKey))
                Text(String(format: "%.0f \(L10nString("password.bits"))", viewModel.entropy))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                CopyButton(value: viewModel.password)
                Button {
                    viewModel.generate()
                } label: {
                    Label(L10nString("password.regenerate"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var optionsCard: some View {
        SectionCard(title: L10n("password.options.title"), systemImage: "slider.horizontal.3") {
            HStack {
                Text(L10n("password.length"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(viewModel.options.length)")
                    .font(AppTypography.monoBody)
                    .foregroundStyle(theme.mono)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.options.length) },
                    set: { viewModel.options.length = Int($0); viewModel.generate() }
                ),
                in: 6...64, step: 1
            )

            toggle(L10n("password.lowercase"), \.lowercase)
            toggle(L10n("password.uppercase"), \.uppercase)
            toggle(L10n("password.digits"), \.digits)
            toggle(L10n("password.symbols"), \.symbols)
        }
    }

    private func toggle(_ label: LocalizedStringResource, _ keyPath: WritableKeyPath<PasswordGenerator.Options, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.options[keyPath: keyPath] },
            set: { viewModel.options[keyPath: keyPath] = $0; viewModel.generate() }
        )) {
            Text(label).font(AppTypography.body).foregroundStyle(theme.textPrimary)
        }
    }

    private var strengthKind: StatusBadge.Kind {
        switch viewModel.strength {
        case .weak: .danger
        case .fair: .warning
        case .strong: .info
        case .excellent: .success
        }
    }
}
