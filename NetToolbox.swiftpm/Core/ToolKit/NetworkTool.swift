import SwiftUI

/// Categories shown as sections in the sidebar and on the home grid.
enum ToolCategory: String, CaseIterable, Identifiable, Hashable {
    case calculators
    case diagnostics
    case localNetwork
    case professional

    var id: String { rawValue }

    var titleKey: LocalizedStringResource {
        switch self {
        case .calculators: "category.calculators"
        case .diagnostics: "category.diagnostics"
        case .localNetwork: "category.localNetwork"
        case .professional: "category.professional"
        }
    }

    var systemImage: String {
        switch self {
        case .calculators: "function"
        case .diagnostics: "waveform.path.ecg"
        case .localNetwork: "wifi.router"
        case .professional: "terminal"
        }
    }
}

/// Contract every tool implements.
///
/// Adding a tool to the app = one type conforming to `NetworkTool`
/// + one line in `ToolRegistry.all`. The home screen, navigation and
/// categories are all derived from the registry automatically.
@MainActor
protocol NetworkTool: Identifiable {
    var id: String { get }
    var titleKey: LocalizedStringResource { get }
    var subtitleKey: LocalizedStringResource { get }
    var systemImage: String { get }
    var category: ToolCategory { get }
    /// `false` for tools that are documented but not shipped yet
    /// (or not possible on iOS) — they render as disabled cards.
    var isAvailable: Bool { get }
    func makeView() -> AnyView
}

extension NetworkTool {
    var isAvailable: Bool { true }
}
