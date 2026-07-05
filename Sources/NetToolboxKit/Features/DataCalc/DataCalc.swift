import SwiftUI
import Observation

/// Data-size unit conversion and transfer-time estimation. Pure logic.
enum DataCalc {
    /// Bytes for a value in a named unit.
    static func bytes(value: Double, unit: String) -> Double {
        switch unit {
        case "KB": return value * 1_000
        case "MB": return value * 1_000_000
        case "GB": return value * 1_000_000_000
        case "TB": return value * 1_000_000_000_000
        case "KiB": return value * 1024
        case "MiB": return value * 1024 * 1024
        case "GiB": return value * 1024 * 1024 * 1024
        default: return value
        }
    }

    /// Bits per second for a value in a named speed unit.
    static func bitsPerSecond(value: Double, unit: String) -> Double {
        switch unit {
        case "Kbps": return value * 1_000
        case "Mbps": return value * 1_000_000
        case "Gbps": return value * 1_000_000_000
        default: return value
        }
    }

    static func transferSeconds(sizeBytes: Double, bitsPerSecond: Double) -> Double {
        guard bitsPerSecond > 0 else { return 0 }
        return sizeBytes * 8 / bitsPerSecond
    }

    static func humanDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds < 1 { return String(format: "%.0f ms", seconds * 1000) }
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return "\(h)h \(m)m \(sec)s" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }
}

@MainActor
@Observable
final class DataCalcViewModel {
    var sizeText = "1"
    var sizeUnit = "GB"
    var speedText = "100"
    var speedUnit = "Mbps"

    let sizeUnits = ["KB", "MB", "GB", "TB", "KiB", "MiB", "GiB"]
    let speedUnits = ["Kbps", "Mbps", "Gbps"]

    var bytes: Double { DataCalc.bytes(value: Double(sizeText) ?? 0, unit: sizeUnit) }
    var bps: Double { DataCalc.bitsPerSecond(value: Double(speedText) ?? 0, unit: speedUnit) }
    var transfer: String { DataCalc.humanDuration(DataCalc.transferSeconds(sizeBytes: bytes, bitsPerSecond: bps)) }
}

struct DataCalcTool: NetworkTool {
    let id = "data-calc"
    let titleKey = L10n("tool.datacalc.title")
    let subtitleKey = L10n("tool.datacalc.subtitle")
    let systemImage = "externaldrive.badge.timemachine"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(DataCalcView()) }
}

struct DataCalcView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = DataCalcViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionCard(title: L10n("datacalc.input.title"), systemImage: "externaldrive") {
                    HStack {
                        TextField("1", text: $viewModel.sizeText)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody).keyboardType(.decimalPad)
                            .environment(\.layoutDirection, .leftToRight)
                        Picker("", selection: $viewModel.sizeUnit) {
                            ForEach(viewModel.sizeUnits, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                    }
                    HStack {
                        TextField("100", text: $viewModel.speedText)
                            .textFieldStyle(.roundedBorder).font(AppTypography.monoBody).keyboardType(.decimalPad)
                            .environment(\.layoutDirection, .leftToRight)
                        Picker("", selection: $viewModel.speedUnit) {
                            ForEach(viewModel.speedUnits, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                    }
                }
                SectionCard(title: L10n("datacalc.section.result"), systemImage: "timer") {
                    VStack(spacing: Spacing.md) {
                        Text(viewModel.transfer)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accent)
                            .environment(\.layoutDirection, .leftToRight)
                        Text(L10n("datacalc.transferTime")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().overlay(theme.separator)
                    row(L10n("datacalc.bytes"), String(format: "%.0f", viewModel.bytes))
                    row(L10n("datacalc.megabits"), String(format: "%.2f", viewModel.bytes * 8 / 1_000_000))
                }
                Text(L10n("datacalc.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.datacalc.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private func row(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.footnote).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
