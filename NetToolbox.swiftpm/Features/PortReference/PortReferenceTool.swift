import SwiftUI

/// Registry entry for the common ports reference.
struct PortReferenceTool: NetworkTool {
    let id = "port-reference"
    let titleKey: LocalizedStringResource = "tool.ports.title"
    let subtitleKey: LocalizedStringResource = "tool.ports.subtitle"
    let systemImage = "number.square"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView {
        AnyView(PortReferenceView())
    }
}
