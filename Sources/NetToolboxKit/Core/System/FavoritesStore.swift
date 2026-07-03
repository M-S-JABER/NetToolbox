import Foundation
import Observation

/// Persists the user's favourite tool IDs in `UserDefaults` (kept simple to
/// avoid SwiftData key-path concurrency warnings). Observable so the home
/// screen reacts instantly to stars being toggled.
@MainActor
@Observable
final class FavoritesStore {
    private let key = "nettoolbox.favorites"
    private(set) var ids: Set<String>

    init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        ids = Set(raw.split(separator: ",").map(String.init))
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: key)
    }
}
