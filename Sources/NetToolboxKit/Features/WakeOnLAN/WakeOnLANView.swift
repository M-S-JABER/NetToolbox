import SwiftUI
import Observation

@MainActor
@Observable
final class WakeOnLANViewModel {
    enum Output: Equatable {
        case idle
        case success(String)
        case failure(String)
    }

    var mac = ""
    var broadcast = "255.255.255.255"
    var portText = "9"
    private(set) var output: Output = .idle

    func send() {
        let macText = mac.trimmingCharacters(in: .whitespaces)
        guard !macText.isEmpty else { output = .idle; return }
        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? 9
        let broadcastAddress = broadcast.trimmingCharacters(in: .whitespaces)

        let result = WakeOnLAN.send(macText: macText, broadcast: broadcastAddress, port: port)
        switch result {
        case .success:
            output = .success(String(localized: "wol.sent", bundle: .module))
        case .failure(let error):
            output = .failure(error.localizedDescription)
        }
    }
}

struct WakeOnLANTool: NetworkTool {
    let id = "wake-on-lan"
    let titleKey = L10n("tool.wol.title")
    let subtitleKey = L10n("tool.wol.subtitle")
    let systemImage = "power"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(WakeOnLANView()) }
}

struct WakeOnLANView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = WakeOnLANViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
                Text(L10n("wol.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.wol.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("wol.input.title"), systemImage: "power") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("wol.input.mac"), text: $viewModel.mac)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.mac)
            }

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("wol.input.broadcast"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                    TextField("255.255.255.255", text: $viewModel.broadcast)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numbersAndPunctuation)
                        .environment(\.layoutDirection, .leftToRight)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("wol.input.port"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                    TextField("9", text: $viewModel.portText)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 80)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            Button {
                viewModel.send()
            } label: {
                Label(L10nString("wol.action.wake"), systemImage: "power")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            EmptyView()
        case .success(let message):
            SectionCard(title: L10n("wol.section.status"), systemImage: "checkmark.circle") {
                HStack(spacing: Spacing.sm) {
                    StatusBadge(kind: .success, text: L10n("wol.badge.sent"))
                    Text(message).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                }
            }
        case .failure(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        }
    }
}
