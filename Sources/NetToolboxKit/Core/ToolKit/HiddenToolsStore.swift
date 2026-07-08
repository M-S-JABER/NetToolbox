import Foundation
import Observation

/// Persists tool IDs the user has hidden from the sidebar, so a big toolbox can
/// be trimmed to the tools they actually use. Hidden tools stay reachable via
/// search and can be revealed with a Settings toggle.
@MainActor
@Observable
final class HiddenToolsStore {
    private let key = "nettoolbox.hiddenTools"
    private(set) var ids: Set<String>

    init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        ids = Set(raw.split(separator: ",").map(String.init))
    }

    func isHidden(_ id: String) -> Bool { ids.contains(id) }
    var hasHidden: Bool { !ids.isEmpty }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        persist()
    }

    func show(_ id: String) {
        guard ids.contains(id) else { return }
        ids.remove(id)
        persist()
    }

    func showAll() {
        ids = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: key)
    }
}
