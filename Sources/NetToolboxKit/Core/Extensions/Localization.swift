import Foundation

/// Resolves a localization key against this package's own string catalog.
///
/// SwiftUI's string-literal initializers (`Text("key")`,
/// `LocalizedStringResource` literals, ...) look keys up in `Bundle.main`,
/// which is the *host app's* bundle when NetToolboxKit is consumed as a
/// package dependency — so every key would fail to resolve. All UI strings
/// therefore go through these helpers, which pin the lookup to the
/// package's `Bundle.module`.
func L10n(_ key: String) -> LocalizedStringResource {
    LocalizedStringResource(
        String.LocalizationValue(key),
        bundle: .atURL(Bundle.module.bundleURL)
    )
}

/// `String` variant of `L10n` for APIs that take plain strings
/// (`TextField` titles, `Label` titles, `Button` titles, ...).
func L10nString(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}
