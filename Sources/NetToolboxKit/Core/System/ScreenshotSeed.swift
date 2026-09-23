#if DEBUG
import Foundation

/// Debug-only hooks for generating App Store screenshots on the simulator,
/// driven by launch arguments (read through the UserDefaults argument domain):
///   `-NTShotTool <id>`    open a tool (`__sidebar__` shows the tool list)
///   `-NTShotInput <text>` pre-fill that tool's input and run it once
/// Never compiled into Release builds.
enum ScreenshotSeed {
    static var tool: String? { UserDefaults.standard.string(forKey: "NTShotTool") }
    static var input: String? { UserDefaults.standard.string(forKey: "NTShotInput") }
}
#endif
