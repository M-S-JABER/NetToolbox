import SwiftUI
import Observation

/// Retains tool view-models across navigation. Because a tool's view is torn
/// down when you switch tools in the split view, its `@State` view-model would
/// normally be destroyed — stopping any running operation. Holding the
/// view-models here (keyed by tool id) keeps a running ping/scan alive and its
/// per-tool history intact until you stop it yourself. Plain (non-Observable)
/// on purpose: the dictionary must not invalidate views when it mutates.
final class ToolSessions {
    private var storage: [String: AnyObject] = [:]

    /// Returns the retained view-model for `id`, creating it once on first use.
    func session<T: AnyObject>(_ id: String, _ make: () -> T) -> T {
        if let existing = storage[id] as? T { return existing }
        let created = make()
        storage[id] = created
        return created
    }
}

private struct ToolSessionsKey: EnvironmentKey {
    static let defaultValue = ToolSessions()
}

extension EnvironmentValues {
    var toolSessions: ToolSessions {
        get { self[ToolSessionsKey.self] }
        set { self[ToolSessionsKey.self] = newValue }
    }
}

/// App-wide set of tool ids that currently have a live operation, so the
/// sidebar can show a "running" badge on the tool.
@MainActor
@Observable
final class ActivityCenter {
    var running: Set<String> = []

    func start(_ id: String) { running.insert(id) }
    func stop(_ id: String) { running.remove(id) }
}
