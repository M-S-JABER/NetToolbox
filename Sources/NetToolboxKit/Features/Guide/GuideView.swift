import SwiftUI

struct GuideTool: NetworkTool {
    let id = "guide"
    let titleKey = L10n("tool.guide.title")
    let subtitleKey = L10n("tool.guide.subtitle")
    let systemImage = "book"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(GuideView()) }
}

@MainActor
struct GuideView: View {
    @Environment(\.theme) private var theme

    private struct Section: Identifiable {
        let icon: String
        let title: String
        let body: String
        var id: String { title }
    }

    private let sections: [Section] = [
        Section(icon: "sparkles", title: "guide.intro.title", body: "guide.intro.body"),
        Section(icon: "house", title: "guide.home.title", body: "guide.home.body"),
        Section(icon: "magnifyingglass", title: "guide.tools.title", body: "guide.tools.body"),
        Section(icon: "wifi", title: "guide.wifi.title", body: "guide.wifi.body"),
        Section(icon: "lock.shield", title: "guide.permissions.title", body: "guide.permissions.body"),
        Section(icon: "network", title: "guide.localnet.title", body: "guide.localnet.body"),
        Section(icon: "terminal", title: "guide.pro.title", body: "guide.pro.body"),
        Section(icon: "exclamationmark.triangle", title: "guide.limits.title", body: "guide.limits.body"),
        Section(icon: "checkmark.seal", title: "guide.tests.title", body: "guide.tests.body"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(sections) { section in
                    SectionCard(title: L10n(section.title), systemImage: section.icon) {
                        Text(L10n(section.body))
                            .font(AppTypography.body)
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.guide.title")))
        .navigationBarTitleDisplayMode(.large)
    }
}
