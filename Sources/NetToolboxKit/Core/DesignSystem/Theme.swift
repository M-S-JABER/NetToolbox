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

/// A theme whose surfaces come from `ColorTokens` but whose accent and mono
/// tints are configurable — the basis for the selectable theme catalogue.
public struct AppTheme: Theme {
    public var background = ColorTokens.background
    public var surface = ColorTokens.surface
    public var surfaceElevated = ColorTokens.surfaceElevated
    public var accent: Color
    public var textPrimary = ColorTokens.textPrimary
    public var textSecondary = ColorTokens.textSecondary
    public var success = ColorTokens.success
    public var warning = ColorTokens.warning
    public var danger = ColorTokens.danger
    public var mono: Color
    public var separator = ColorTokens.separator

    public init(accent: Color, mono: Color) {
        self.accent = accent
        self.mono = mono
    }
}

/// The built-in, user-selectable accent themes. Dark-first, all with the
/// same calm surfaces so only the accent personality changes.
public enum ThemeOption: String, CaseIterable, Identifiable, Sendable {
    case teal, indigo, emerald, sunset, rose, graphite

    public var id: String { rawValue }
    var nameKey: String { "theme.\(rawValue)" }

    /// Swatch colour for the picker.
    var swatch: Color { makeTheme().accent }

    public func makeTheme() -> AppTheme {
        switch self {
        case .teal:
            AppTheme(
                accent: Color(light: Color(hex: 0x0D9488), dark: Color(hex: 0x2DD4BF)),
                mono: Color(light: Color(hex: 0x0369A1), dark: Color(hex: 0x7DD3FC))
            )
        case .indigo:
            AppTheme(
                accent: Color(light: Color(hex: 0x4F46E5), dark: Color(hex: 0x818CF8)),
                mono: Color(light: Color(hex: 0x4338CA), dark: Color(hex: 0xA5B4FC))
            )
        case .emerald:
            AppTheme(
                accent: Color(light: Color(hex: 0x059669), dark: Color(hex: 0x34D399)),
                mono: Color(light: Color(hex: 0x047857), dark: Color(hex: 0x6EE7B7))
            )
        case .sunset:
            AppTheme(
                accent: Color(light: Color(hex: 0xEA580C), dark: Color(hex: 0xFB923C)),
                mono: Color(light: Color(hex: 0xB45309), dark: Color(hex: 0xFCD34D))
            )
        case .rose:
            AppTheme(
                accent: Color(light: Color(hex: 0xE11D48), dark: Color(hex: 0xFB7185)),
                mono: Color(light: Color(hex: 0xBE185D), dark: Color(hex: 0xF9A8D4))
            )
        case .graphite:
            AppTheme(
                accent: Color(light: Color(hex: 0x52525B), dark: Color(hex: 0xA1A1AA)),
                mono: Color(light: Color(hex: 0x3F3F46), dark: Color(hex: 0xD4D4D8))
            )
        }
    }
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
