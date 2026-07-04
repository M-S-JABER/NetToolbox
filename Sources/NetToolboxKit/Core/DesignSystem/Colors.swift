import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Semantic color tokens for the app's look.
///
/// The design language is **native iOS**: surfaces map onto the system
/// grouped-background family and text onto the system label colors, so every
/// screen matches the Settings app and adapts automatically to Light/Dark and
/// accessibility contrast. Views must never use raw colors — always go
/// through `Theme` (which maps to these tokens), so the whole app can still be
/// re-skinned by swapping a single `Theme` value.
enum ColorTokens {
    #if canImport(UIKit)
    /// The grouped table background behind cards and list sections.
    static let background = Color(uiColor: .systemGroupedBackground)
    /// The card / row surface that sits on the grouped background.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    /// A slightly raised inset surface (e.g. terminals, code blocks).
    static let surfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    #else
    static let background = Color(hex: 0xF2F2F7)
    static let surface = Color.white
    static let surfaceElevated = Color(hex: 0xF2F2F7)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let separator = Color.gray.opacity(0.3)
    #endif

    /// Calm teal accent used by the default theme; the selectable themes
    /// override this with their own accent.
    static let accent = Color(
        light: Color(hex: 0x0D9488),
        dark: Color(hex: 0x2DD4BF)
    )

    static let success = Color(
        light: Color(hex: 0x34C759, opacity: 1),
        dark: Color(hex: 0x30D158)
    )

    static let warning = Color(
        light: Color(hex: 0xFF9500),
        dark: Color(hex: 0xFF9F0A)
    )

    static let danger = Color(
        light: Color(hex: 0xFF3B30),
        dark: Color(hex: 0xFF453A)
    )

    /// Tint used for technical monospaced values (IPs, MACs, hex, ports).
    static let mono = Color(
        light: Color(hex: 0x007AFF),
        dark: Color(hex: 0x64D2FF)
    )
}
