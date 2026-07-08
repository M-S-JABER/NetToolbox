import Foundation
import Observation

/// Tracks the tools the user opened most recently (newest first), persisted in
/// `UserDefaults`. Powers the "Recent" row on the dashboard so frequently used
/// tools are one tap away out of the 45.
@MainActor
@Observable
final class RecentToolsStore {
    private let key = "nettoolbox.recentTools"
    private let limit = 8
    private(set) var ids: [String]

    init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        ids = raw.split(separator: ",").map(String.init)
    }

    /// Moves `id` to the front, trimming to the most recent `limit`.
    func record(_ id: String) {
        guard !id.isEmpty else { return }
        var next = ids.filter { $0 != id }
        next.insert(id, at: 0)
        if next.count > limit { next = Array(next.prefix(limit)) }
        ids = next
        UserDefaults.standard.set(next.joined(separator: ","), forKey: key)
    }

    func clear() {
        ids = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
