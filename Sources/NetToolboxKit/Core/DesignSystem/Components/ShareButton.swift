import SwiftUI

/// A small share button backed by `ShareLink`, for exporting a result as
/// text to the system share sheet.
struct ShareButton: View {
    @Environment(\.theme) private var theme

    let text: String
    var label: LocalizedStringResource = L10n("common.share")

    var body: some View {
        ShareLink(item: text) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: "square.and.arrow.up")
            }
            .font(AppTypography.footnote)
        }
        .buttonStyle(.bordered)
        .disabled(text.isEmpty)
    }
}
