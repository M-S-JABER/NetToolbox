import SwiftUI

/// Semantic color tokens for the default look.
/// Views must never use raw colors — always go through `Theme` (which the
/// default theme maps to these tokens), so the whole app can be re-skinned
/// by swapping a single `Theme` value.
enum ColorTokens {
    // Dark-first palette: deep navy background with a calm teal accent.

    static let background = Color(
        light: Color(hex: 0xF4F6FA),
        dark: Color(hex: 0x0B1220)
    )

    static let surface = Color(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x121C2E)
    )

    static let surfaceElevated = Color(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x1A2740)
    )

    static let accent = Color(
        light: Color(hex: 0x0D9488),
        dark: Color(hex: 0x2DD4BF)
    )

    static let textPrimary = Color(
        light: Color(hex: 0x0F172A),
        dark: Color(hex: 0xE8EDF5)
    )

    static let textSecondary = Color(
        light: Color(hex: 0x5B6B82),
        dark: Color(hex: 0x93A1B5)
    )

    static let success = Color(
        light: Color(hex: 0x059669),
        dark: Color(hex: 0x34D399)
    )

    static let warning = Color(
        light: Color(hex: 0xB45309),
        dark: Color(hex: 0xFBBF24)
    )

    static let danger = Color(
        light: Color(hex: 0xDC2626),
        dark: Color(hex: 0xF87171)
    )

    /// Tint used for technical monospaced values (IPs, MACs, hex, ports).
    static let mono = Color(
        light: Color(hex: 0x0369A1),
        dark: Color(hex: 0x7DD3FC)
    )

    static let separator = Color(
        light: Color(hex: 0x0F172A, opacity: 0.08),
        dark: Color(hex: 0xE8EDF5, opacity: 0.08)
    )
}
