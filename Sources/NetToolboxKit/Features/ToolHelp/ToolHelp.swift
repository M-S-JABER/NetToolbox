import Foundation

/// A short piece of help text in both languages the app ships. The help
/// content lives in Swift (not the `.strings` catalog) on purpose: 84 tools ×
/// four sections would add 600+ fragile parity-checked keys, and keeping each
/// tool's Arabic and English side by side makes the copy easy to maintain.
struct LocalizedText: Sendable {
    let en: String
    let ar: String

    func value(arabic: Bool) -> String { arabic ? ar : en }
}

/// Structured in-app help for one tool, shown by `ToolHelpView` when the user
/// taps the "?" button in that tool's navigation bar.
struct ToolHelpContent: Sendable {
    let overview: LocalizedText
    let howItWorks: LocalizedText
    let example: LocalizedText
    let notes: LocalizedText
}

/// Central registry of per-tool help. The per-category dictionaries are defined
/// in the `ToolHelp+*.swift` files and merged here, so each category's content
/// is self-contained and easy to extend.
enum ToolHelp {
    static let all: [String: ToolHelpContent] = {
        var merged = calculatorsHelp
        for (key, value) in diagnosticsHelpA { merged[key] = value }
        for (key, value) in diagnosticsHelpB { merged[key] = value }
        for (key, value) in localNetworkHelp { merged[key] = value }
        for (key, value) in professionalHelp { merged[key] = value }
        for (key, value) in bgpHelp { merged[key] = value }
        return merged
    }()

    static func entry(for id: String) -> ToolHelpContent? { all[id] }

    /// True when the package is currently presenting its Arabic localization,
    /// so the help sheet can pick the matching text. Defaults to English.
    static var isArabic: Bool {
        (Bundle.module.preferredLocalizations.first ?? "en").hasPrefix("ar")
    }
}
