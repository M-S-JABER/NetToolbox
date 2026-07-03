import SwiftUI

/// Registry entry for the Public IP / ISP info tool.
struct PublicIPTool: NetworkTool {
    let id = "public-ip"
    let titleKey = L10n("tool.publicip.title")
    let subtitleKey = L10n("tool.publicip.subtitle")
    let systemImage = "globe"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView {
        AnyView(PublicIPView())
    }
}
