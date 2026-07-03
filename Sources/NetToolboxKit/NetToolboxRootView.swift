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
    /// Optional hard override; when nil the user's chosen accent theme is used.
    private let themeOverride: (any Theme)?

    @AppStorage("nettoolbox.theme") private var themeSelection = ThemeOption.teal.rawValue
    @State private var status = NetworkStatusMonitor()
    @State private var favorites = FavoritesStore()

    /// - Parameter theme: pass a custom `Theme` to force one look and hide
    ///   the built-in theme picker's effect; omit to let the user choose.
    public init(theme: (any Theme)? = nil) {
        self.themeOverride = theme
    }

    private var activeTheme: any Theme {
        if let themeOverride { return themeOverride }
        return (ThemeOption(rawValue: themeSelection) ?? .teal).makeTheme()
    }

    public var body: some View {
        RootView(themeSelection: $themeSelection)
            .environment(\.theme, activeTheme)
            .environment(status)
            .environment(favorites)
            .tint(activeTheme.accent)
            // Dark-first design; both appearances are fully supported.
            .preferredColorScheme(.dark)
            .modelContainer(for: [HistoryEntry.self, SavedHost.self, Favorite.self])
            .task { status.start() }
    }
}
