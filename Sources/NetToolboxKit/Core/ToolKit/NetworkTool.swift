import SwiftUI

/// Categories shown as sections in the sidebar and on the home grid.
enum ToolCategory: String, CaseIterable, Identifiable, Hashable {
    case calculators
    case diagnostics
    case localNetwork
    case professional
    case bgp

    var id: String { rawValue }

    var titleKey: LocalizedStringResource {
        switch self {
        case .calculators: L10n("category.calculators")
        case .diagnostics: L10n("category.diagnostics")
        case .localNetwork: L10n("category.localNetwork")
        case .professional: L10n("category.professional")
        case .bgp: L10n("category.bgp")
        }
    }

    var systemImage: String {
        switch self {
        case .calculators: "function"
        case .diagnostics: "waveform.path.ecg"
        case .localNetwork: "wifi.router"
        case .professional: "terminal"
        case .bgp: "arrow.triangle.branch"
        }
    }

    /// A distinct accent hue per category, used to colour sidebar icons and
    /// dashboard cards. Fixed hues (not theme-derived) so categories stay
    /// recognisable at a glance, and each reads on both light and dark.
    var tint: Color {
        switch self {
        case .calculators: Color(red: 0.46, green: 0.42, blue: 0.95)  // indigo
        case .diagnostics: Color(red: 0.11, green: 0.66, blue: 0.56)  // teal
        case .localNetwork: Color(red: 0.16, green: 0.56, blue: 0.96) // blue
        case .professional: Color(red: 0.95, green: 0.55, blue: 0.21) // orange
        case .bgp: Color(red: 0.91, green: 0.31, blue: 0.51)          // pink
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
