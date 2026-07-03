import Foundation

/// Value-based navigation routes.
/// Tools are routed by their registry ID so navigation stays decoupled
/// from concrete tool types.
enum AppRoute: Hashable {
    case tool(id: String)
}
