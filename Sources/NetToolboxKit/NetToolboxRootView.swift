import SwiftUI
import SwiftData

/// The package's single public entry point: the complete NetToolbox UI,
/// ready to drop into a `WindowGroup`.
///
/// ```swift
/// import NetToolboxKit
///
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup { NetToolboxRootView() }
///     }
/// }
/// ```
public struct NetToolboxRootView: View {
    private let theme: any Theme

    /// - Parameter theme: swap the entire look by passing a custom `Theme`.
    public init(theme: any Theme = DefaultTheme()) {
        self.theme = theme
    }

    public var body: some View {
        RootView()
            .environment(\.theme, theme)
            .tint(theme.accent)
            // Dark-first design; both appearances are fully supported —
            // remove this line to follow the system appearance.
            .preferredColorScheme(.dark)
            .modelContainer(for: [HistoryEntry.self, SavedHost.self, Favorite.self])
    }
}
