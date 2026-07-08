import Foundation
import Observation

extension Notification.Name {
    /// Posted after iCloud values are pulled into `UserDefaults`, so stores
    /// backed by those keys can reload.
    static let cloudSyncDidPull = Notification.Name("nettoolbox.cloudsync.didPull")
}

/// Optional iCloud sync for **non-secret** settings only, via the user's own
/// `NSUbiquitousKeyValueStore`. Theme, saved hosts and speed-test history sync
/// across the user's devices; SSH/camera secrets stay in the local Keychain and
/// never leave the device, so the app still collects no data off-device.
///
/// Last-writer-wins: local state is pushed when the app backgrounds, and remote
/// changes are pulled on launch and whenever iCloud reports an external change.
@MainActor
@Observable
final class CloudSync {
    private let enabledKey = "nettoolbox.cloudsync.enabled"
    /// Only non-secret keys are ever synced.
    private let syncedKeys = [
        "nettoolbox.theme",
        "nettoolbox.hosts.v1",
        "nettoolbox.speedhistory.v1",
    ]

    private(set) var isEnabled: Bool
    private var observer: NSObjectProtocol?

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Starts syncing if enabled: registers for external changes and pulls.
    func start() {
        guard isEnabled else { return }
        registerObserver()
        NSUbiquitousKeyValueStore.default.synchronize()
        pull()
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        UserDefaults.standard.set(on, forKey: enabledKey)
        if on {
            registerObserver()
            pushAll()
            NSUbiquitousKeyValueStore.default.synchronize()
            pull()
        } else {
            removeObserver()
        }
    }

    /// Pushes the current local values to iCloud. Call when the app backgrounds.
    func pushAll() {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default
        for key in syncedKeys {
            if let data = defaults.data(forKey: key) {
                store.set(data, forKey: key)
            } else if let string = defaults.string(forKey: key) {
                store.set(string, forKey: key)
            }
        }
        store.synchronize()
    }

    // MARK: - Private

    private func pull() {
        let defaults = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default
        var changed = false
        for key in syncedKeys {
            if let data = store.data(forKey: key) {
                defaults.set(data, forKey: key)
                changed = true
            } else if let string = store.string(forKey: key) {
                defaults.set(string, forKey: key)
                changed = true
            }
        }
        if changed {
            NotificationCenter.default.post(name: .cloudSyncDidPull, object: nil)
        }
    }

    private func registerObserver() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }
    }

    private func removeObserver() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
