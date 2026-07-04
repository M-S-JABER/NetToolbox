import Foundation
import Observation

/// Persists user-saved hosts (name + address + notes) as JSON in
/// `UserDefaults`. Observable so the manager updates instantly.
@MainActor
@Observable
final class SavedHostsStore {
    struct Host: Codable, Identifiable, Equatable, Sendable {
        var id = UUID()
        var name: String
        var address: String
        var notes: String
    }

    private(set) var hosts: [Host] = []
    private let key = "nettoolbox.hosts.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Host].self, from: data) {
            hosts = decoded
        }
    }

    func add(name: String, address: String, notes: String) {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let displayName = name.trimmingCharacters(in: .whitespaces)
        hosts.insert(
            Host(name: displayName.isEmpty ? trimmed : displayName, address: trimmed, notes: notes),
            at: 0
        )
        save()
    }

    func remove(_ host: Host) {
        hosts.removeAll { $0.id == host.id }
        save()
    }

    /// Replaces all hosts (used when restoring a backup).
    func replaceAll(_ hosts: [Host]) {
        self.hosts = hosts
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
