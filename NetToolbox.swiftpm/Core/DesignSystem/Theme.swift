import SwiftUI

/// A complete semantic palette for the app.
///
/// Every view reads colors exclusively through `@Environment(\.theme)`,
/// so swapping the entire look is a one-line change at the app root:
/// `.environment(\.theme, MyCustomTheme())`.
protocol Theme: Sendable {
    var background: Color { get }
    var surface: Color { get }
    var surfaceElevated: Color { get }
    var accent: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var success: Color { get }
    var warning: Color { get }
    var danger: Color { get }
    /// Tint for technical monospaced values (IP, MAC, hex, ports).
    var mono: Color { get }
    var separator: Color { get }
}

/// The built-in dark-first theme backed by `ColorTokens`.
struct DefaultTheme: Theme {
    var background: Color { ColorTokens.background }
    var surface: Color { ColorTokens.surface }
    var surfaceElevated: Color { ColorTokens.surfaceElevated }
    var accent: Color { ColorTokens.accent }
    var textPrimary: Color { ColorTokens.textPrimary }
    var textSecondary: Color { ColorTokens.textSecondary }
    var success: Color { ColorTokens.success }
    var warning: Color { ColorTokens.warning }
    var danger: Color { ColorTokens.danger }
    var mono: Color { ColorTokens.mono }
    var separator: Color { ColorTokens.separator }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = DefaultTheme()
}

extension EnvironmentValues {
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
