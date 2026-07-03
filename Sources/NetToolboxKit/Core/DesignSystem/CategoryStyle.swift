import SwiftUI

/// Visual identity for each tool category: a distinct gradient and tint so
/// the home screen reads as a colour-coded system rather than a flat list.
extension ToolCategory {
    /// Two-stop gradient colours (light/dark aware) used for icon chips
    /// and section accents.
    var gradientColors: [Color] {
        switch self {
        case .calculators:
            [Color(hex: 0x2DD4BF), Color(hex: 0x0EA5E9)]   // teal → sky
        case .diagnostics:
            [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)]   // indigo → violet
        case .localNetwork:
            [Color(hex: 0x34D399), Color(hex: 0x10B981)]   // emerald
        case .professional:
            [Color(hex: 0xF472B6), Color(hex: 0xA855F7)]   // pink → purple
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Primary tint for the category (first gradient stop).
    var tint: Color { gradientColors.first ?? .accentColor }

    /// A short one-line description shown under the category title.
    var captionKey: LocalizedStringResource {
        switch self {
        case .calculators: "category.caption.calculators"
        case .diagnostics: "category.caption.diagnostics"
        case .localNetwork: "category.caption.localNetwork"
        case .professional: "category.caption.professional"
        }
    }
}
