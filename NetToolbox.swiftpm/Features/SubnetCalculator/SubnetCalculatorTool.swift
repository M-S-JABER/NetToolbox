import SwiftUI

/// Registry entry for the Subnet Calculator.
struct SubnetCalculatorTool: NetworkTool {
    let id = "subnet-calculator"
    let titleKey: LocalizedStringResource = "tool.subnet.title"
    let subtitleKey: LocalizedStringResource = "tool.subnet.subtitle"
    let systemImage = "square.grid.3x3.square"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView {
        AnyView(SubnetCalculatorView())
    }
}
