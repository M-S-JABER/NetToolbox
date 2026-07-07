import SwiftUI
import Observation

/// Random identifier generators: UUIDv4, locally-administered MAC, random hex.
enum RandomGen {
    static func mac() -> String {
        var bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = (bytes[0] | 0x02) & 0xFE // locally administered, unicast
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    static func hex(length: Int) -> String {
        let count = max(1, min(length, 256))
        return (0..<count).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
}

@MainActor
@Observable
final class GeneratorsViewModel {
    var uuids: [String] = []
    var macs: [String] = []
    var hexLengthText = "16"
    var randomHex = ""

    func addUUID() { uuids.insert(UUID().uuidString, at: 0); trim(&uuids) }
    func addMAC() { macs.insert(RandomGen.mac(), at: 0); trim(&macs) }
    func makeHex() { randomHex = RandomGen.hex(length: Int(hexLengthText) ?? 16) }

    private func trim(_ list: inout [String]) { if list.count > 20 { list.removeLast(list.count - 20) } }
}

struct GeneratorsTool: NetworkTool {
    let id = "generators"
    let titleKey = L10n("tool.generators.title")
    let subtitleKey = L10n("tool.generators.subtitle")
    let systemImage = "dice"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(GeneratorsView()) }
}

@MainActor
struct GeneratorsView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = GeneratorsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                uuidSection
                macSection
                hexSection
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.generators.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var uuidSection: some View {
        SectionCard(title: L10n("gen.uuid.title"), systemImage: "number") {
            Button {
                viewModel.addUUID()
            } label: {
                Label(L10nString("gen.uuid.action"), systemImage: "plus").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            ForEach(viewModel.uuids, id: \.self) { CopyableValue(value: $0, font: AppTypography.monoCaption) }
        }
    }

    private var macSection: some View {
        SectionCard(title: L10n("gen.mac.title"), systemImage: "network") {
            Button {
                viewModel.addMAC()
            } label: {
                Label(L10nString("gen.mac.action"), systemImage: "plus").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            ForEach(viewModel.macs, id: \.self) { CopyableValue(value: $0, font: AppTypography.monoCaption) }
        }
    }

    private var hexSection: some View {
        SectionCard(title: L10n("gen.hex.title"), systemImage: "number") {
            HStack(spacing: Spacing.sm) {
                TextField("16", text: $viewModel.hexLengthText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    viewModel.makeHex()
                } label: {
                    Label(L10nString("gen.hex.action"), systemImage: "plus").font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
            if !viewModel.randomHex.isEmpty {
                CopyableValue(value: viewModel.randomHex, font: AppTypography.monoCaption)
            }
        }
    }
}
