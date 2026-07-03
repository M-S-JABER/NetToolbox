import SwiftUI

/// Type scale for the app. Technical values always use the monospaced fonts
/// so digits align and addresses stay readable.
/// All fonts are Dynamic Type friendly (built on semantic text styles).
enum AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption)
    static let footnote = Font.system(.footnote)

    /// Monospaced fonts for IPs, MACs, hex dumps, ports and CLI commands.
    static let monoLarge = Font.system(.title3, design: .monospaced).weight(.semibold)
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoCaption = Font.system(.caption, design: .monospaced)
}
