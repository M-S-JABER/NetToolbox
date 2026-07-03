import Foundation
import SwiftData

/// A saved run of a tool (e.g. a subnet calculation or a MAC lookup),
/// shown as "recent history" inside the tool.
@Model
final class HistoryEntry {
    var toolID: String
    var input: String
    var summary: String
    var date: Date

    init(toolID: String, input: String, summary: String, date: Date = .now) {
        self.toolID = toolID
        self.input = input
        self.summary = summary
        self.date = date
    }
}

/// A host the user saved for quick reuse (Phase 2: ping/traceroute targets).
@Model
final class SavedHost {
    var name: String
    var address: String
    var notes: String
    var date: Date

    init(name: String, address: String, notes: String = "", date: Date = .now) {
        self.name = name
        self.address = address
        self.notes = notes
        self.date = date
    }
}

/// A favorited tool, for a future "favorites" strip on the home screen.
@Model
final class Favorite {
    var toolID: String
    var date: Date

    init(toolID: String, date: Date = .now) {
        self.toolID = toolID
        self.date = date
    }
}
