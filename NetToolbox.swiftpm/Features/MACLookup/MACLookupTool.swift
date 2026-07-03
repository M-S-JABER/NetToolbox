import SwiftUI

/// Registry entry for the MAC / OUI vendor lookup.
struct MACLookupTool: NetworkTool {
    let id = "mac-lookup"
    let titleKey: LocalizedStringResource = "tool.mac.title"
    let subtitleKey: LocalizedStringResource = "tool.mac.subtitle"
    let systemImage = "barcode.viewfinder"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView {
        AnyView(MACLookupView())
    }
}
