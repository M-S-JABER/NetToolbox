import SwiftUI

/// Categories shown as sections in the sidebar and on the home grid.
enum ToolCategory: String, CaseIterable, Identifiable, Hashable {
    case calculators
    case diagnostics
    case dns
    case security
    case localNetwork
    case professional
    case bgp

    var id: String { rawValue }

    var titleKey: LocalizedStringResource {
        switch self {
        case .calculators: L10n("category.calculators")
        case .diagnostics: L10n("category.diagnostics")
        case .dns: L10n("category.dns")
        case .security: L10n("category.security")
        case .localNetwork: L10n("category.localNetwork")
        case .professional: L10n("category.professional")
        case .bgp: L10n("category.bgp")
        }
    }

    var systemImage: String {
        switch self {
        case .calculators: "function"
        case .diagnostics: "waveform.path.ecg"
        case .dns: "globe"
        case .security: "lock.shield"
        case .localNetwork: "wifi.router"
        case .professional: "terminal"
        case .bgp: "arrow.triangle.branch"
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
