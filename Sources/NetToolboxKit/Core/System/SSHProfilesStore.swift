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
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
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
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    /// Replaces all profiles (used when restoring a backup).
    func replaceAll(_ profiles: [Profile]) {
        self.profiles = profiles
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
