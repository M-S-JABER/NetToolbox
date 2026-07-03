import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Creates a color that resolves differently for light and dark appearance.
    /// The app is dark-first, so the dark variant is the primary design value.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = dark
        #endif
    }

    /// Creates a color from a 24-bit RGB hex value, e.g. `Color(hex: 0x2DD4BF)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
