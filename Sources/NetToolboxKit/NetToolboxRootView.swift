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
@MainActor
public struct NetToolboxRootView: View {
    /// Optional hard override; when nil the user's chosen accent theme is used.
    private let themeOverride: (any Theme)?

    @AppStorage("nettoolbox.theme") private var themeSelection = ThemeOption.teal.rawValue
    @AppStorage("nettoolbox.appearance") private var appearanceSelection = AppearanceOption.system.rawValue
    @State private var status = NetworkStatusMonitor()
    @State private var favorites = FavoritesStore()
    @State private var recentTools = RecentToolsStore()
    @State private var hiddenTools = HiddenToolsStore()
    @State private var history = HistoryStore()
    @State private var savedHosts = SavedHostsStore()
    @State private var sshProfiles = SSHProfilesStore()
    @State private var cameras = CameraStore()
    @State private var speedHistory = SpeedHistoryStore()
    @State private var activity = ActivityCenter()
    @State private var appLock = AppLock()
    @State private var cloudSync = CloudSync()
    @State private var wifiInbox = WiFiShortcutInbox()
    @State private var knownHosts = KnownHostsStore()
    @State private var sshConnect = SSHConnectRequest()
    @Environment(\.scenePhase) private var scenePhase
    private let toolSessions = ToolSessions()

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
            .environment(recentTools)
            .environment(hiddenTools)
            .environment(history)
            .environment(savedHosts)
            .environment(sshProfiles)
            .environment(cameras)
            .environment(speedHistory)
            .environment(activity)
            .environment(appLock)
            .environment(cloudSync)
            .environment(wifiInbox)
            .environment(knownHosts)
            .environment(sshConnect)
            .environment(\.toolSessions, toolSessions)
            .tint(activeTheme.accent)
            // Follow the system appearance by default, or force light/dark.
            .preferredColorScheme((AppearanceOption(rawValue: appearanceSelection) ?? .system).colorScheme)
            .modelContainer(for: [HistoryEntry.self, SavedHost.self, Favorite.self])
            .task { status.start() }
            .task { cloudSync.start() }
            .task { favorites.seedStarterFavoritesIfNeeded() }
            // Biometric app lock: cover the UI while locked and re-lock when
            // the app leaves the foreground.
            .overlay {
                if appLock.isLocked {
                    LockView(lock: appLock)
                        .environment(\.theme, activeTheme)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: appLock.isLocked)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    appLock.lockIfEnabled()
                    cloudSync.pushAll()
                }
            }
    }
}
