import SwiftUI
import SwiftData

@main
struct NetToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Swap the entire look of the app by replacing this theme.
                .environment(\.theme, DefaultTheme())
                .tint(ColorTokens.accent)
                // Dark-first design; both appearances are fully supported,
                // remove this line to follow the system appearance.
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [HistoryEntry.self, SavedHost.self, Favorite.self])
    }
}
