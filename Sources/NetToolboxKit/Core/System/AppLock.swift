import SwiftUI
import LocalAuthentication

/// Optional Face ID / Touch ID / passcode gate for the whole app. When enabled,
/// the app starts locked and re-locks whenever it leaves the foreground, so a
/// glance at the device doesn't expose saved hosts, SSH profiles or cameras.
@MainActor
@Observable
final class AppLock {
    private let enabledKey = "nettoolbox.applock.enabled"

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    /// Set after a failed unlock so the lock screen can show a hint.
    private(set) var lastFailed = false

    init() {
        let enabled = UserDefaults.standard.bool(forKey: enabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    /// Whether the device can authenticate at all (biometrics or passcode).
    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// SF Symbol + label key describing the available biometry.
    var symbolName: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    /// Re-locks if the feature is on. Call when the app resigns active.
    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    /// Prompts for authentication and unlocks on success.
    func unlock() async {
        guard isLocked else { return }
        if await authenticate(reason: L10nString("applock.reason")) {
            isLocked = false
            lastFailed = false
        } else {
            lastFailed = true
        }
    }

    /// Turns the lock on (requires a successful auth first, so the user can't
    /// lock themselves out) or off.
    func setEnabled(_ on: Bool) async {
        if on {
            guard await authenticate(reason: L10nString("applock.enable.reason")) else { return }
            isEnabled = true
            UserDefaults.standard.set(true, forKey: enabledKey)
            isLocked = false
        } else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: enabledKey)
            isLocked = false
        }
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10nString("common.cancel")
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
