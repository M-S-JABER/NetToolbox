import SwiftUI

/// User's preferred colour scheme. `system` follows the device setting; the
/// others force light or dark regardless of the system.
enum AppearanceOption: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var labelKey: LocalizedStringResource {
        switch self {
        case .system: L10n("appearance.system")
        case .light: L10n("appearance.light")
        case .dark: L10n("appearance.dark")
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }
}
