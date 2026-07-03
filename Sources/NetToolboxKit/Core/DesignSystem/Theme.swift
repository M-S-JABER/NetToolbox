import SwiftUI

/// A complete semantic palette for the app.
///
/// Every view reads colors exclusively through `@Environment(\.theme)`,
/// so swapping the entire look is a one-line change at the app root:
/// `.environment(\.theme, MyCustomTheme())`.
public protocol Theme: Sendable {
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
public struct DefaultTheme: Theme {
    public init() {}

    public var background: Color { ColorTokens.background }
    public var surface: Color { ColorTokens.surface }
    public var surfaceElevated: Color { ColorTokens.surfaceElevated }
    public var accent: Color { ColorTokens.accent }
    public var textPrimary: Color { ColorTokens.textPrimary }
    public var textSecondary: Color { ColorTokens.textSecondary }
    public var success: Color { ColorTokens.success }
    public var warning: Color { ColorTokens.warning }
    public var danger: Color { ColorTokens.danger }
    public var mono: Color { ColorTokens.mono }
    public var separator: Color { ColorTokens.separator }
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
