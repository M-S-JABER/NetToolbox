import Foundation
import Observation

/// Saved SSH connection profiles (name, server, credentials) persisted as
/// JSON in `UserDefaults`, so a server can be reconnected in one tap. Stored
/// locally on the device only.
@MainActor
@Observable
final class SSHProfilesStore {
    struct Profile: Codable, Identifiable, Equatable, Sendable {
        var id = UUID()
        var name = ""
        var host = ""
        var port = "22"
        var username = ""
        var password = ""
        var usesKey = false
        var privateKey = ""

        /// Falls back to host:port when no name is given.
        var displayName: String {
            name.isEmpty ? "\(host):\(port)" : name
        }
    }

    private(set) var profiles: [Profile] = []
    private let key = "nettoolbox.sshprofiles.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data) else { return }
        // Passwords/keys live in the Keychain, not this JSON. Hydrate each
        // profile's secrets from it. If the JSON still carries inline secrets
        // (saved before the Keychain migration), keep them and re-persist so
        // they move into the Keychain and are stripped from UserDefaults.
        var needsMigration = false
        profiles = decoded.map { profile in
            var profile = profile
            if profile.password.isEmpty {
                profile.password = KeychainStore.get(service: .ssh, account: "\(profile.id).password") ?? ""
            } else {
                needsMigration = true
            }
            if profile.privateKey.isEmpty {
                profile.privateKey = KeychainStore.get(service: .ssh, account: "\(profile.id).privateKey") ?? ""
            } else {
                needsMigration = true
            }
            return profile
        }
        if needsMigration { persist() }
    }

    /// Inserts a new profile, or updates one with the same id.
    func save(_ profile: Profile) {
        guard !profile.host.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.insert(profile, at: 0)
        }
        persist()
    }

    func remove(_ profile: Profile) {
        KeychainStore.remove(service: .ssh, account: "\(profile.id).password")
        KeychainStore.remove(service: .ssh, account: "\(profile.id).privateKey")
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    /// Replaces all profiles (used when restoring a backup). Clears every
    /// previously stored secret first so none are orphaned.
    func replaceAll(_ profiles: [Profile]) {
        KeychainStore.removeAll(service: .ssh)
        self.profiles = profiles
        persist()
    }

    private func persist() {
        // Write secrets to the Keychain and strip them from the JSON copy.
        let redacted = profiles.map { profile -> Profile in
            KeychainStore.set(profile.password, service: .ssh, account: "\(profile.id).password")
            KeychainStore.set(profile.privateKey, service: .ssh, account: "\(profile.id).privateKey")
            var copy = profile
            copy.password = ""
            copy.privateKey = ""
            return copy
        }
        if let data = try? JSONEncoder().encode(redacted) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
