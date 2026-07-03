import SwiftUI

/// Registry entry for the Subnet Calculator.
struct SubnetCalculatorTool: NetworkTool {
    let id = "subnet-calculator"
    let titleKey = L10n("tool.subnet.title")
    let subtitleKey = L10n("tool.subnet.subtitle")
    let systemImage = "square.grid.3x3.square"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView {
        AnyView(SubnetCalculatorView())
    }
}
