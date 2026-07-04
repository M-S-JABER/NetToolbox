import Foundation
import Observation

/// A unified, cross-tool history. Any tool can log a run; the History tool
/// lists them and offers copy / share / clear. Persisted as JSON in
/// `UserDefaults` (no SwiftData key-path concurrency warnings).
@MainActor
@Observable
final class HistoryStore {
    struct Entry: Codable, Identifiable, Equatable, Sendable {
        var id = UUID()
        let toolID: String
        let input: String
        let summary: String
        let date: Date
    }

    private(set) var entries: [Entry] = []

    private let key = "nettoolbox.history.v1"
    private let maxEntries = 120

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    /// Records a run at the front of the list (most recent first).
    func log(toolID: String, input: String, summary: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        // Avoid consecutive duplicates for the same tool + input.
        if let first = entries.first, first.toolID == toolID, first.input == trimmedInput {
            return
        }
        entries.insert(Entry(toolID: toolID, input: trimmedInput, summary: summary, date: Date()), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// A plain-text export of the whole history.
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return entries.map { entry in
            let title = ToolRegistry.tool(withID: entry.toolID).map { String(localized: $0.titleKey) } ?? entry.toolID
            return "[\(formatter.string(from: entry.date))] \(title): \(entry.input) → \(entry.summary)"
        }.joined(separator: "\n")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
