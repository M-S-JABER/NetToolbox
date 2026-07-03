import Foundation
import Observation

/// Search + filter state over the offline port database.
@MainActor
@Observable
final class PortReferenceViewModel {
    enum ProtocolFilter: String, CaseIterable, Identifiable {
        case all
        case tcp
        case udp

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .all: "ports.filter.all"
            case .tcp: "ports.filter.tcp"
            case .udp: "ports.filter.udp"
            }
        }
    }

    var query = ""
    var filter: ProtocolFilter = .all

    var results: [PortEntry] {
        PortDatabase.all.filter { entry in
            let protocolMatch = switch filter {
            case .all: true
            case .tcp: entry.protocols.contains(.tcp)
            case .udp: entry.protocols.contains(.udp)
            }
            return protocolMatch && entry.matches(query: query)
        }
    }
}
