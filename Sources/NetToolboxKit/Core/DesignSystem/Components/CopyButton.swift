import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A standalone "Copy" button with brief confirmation, for multi-line or
/// large values where `CopyableValue`'s single-line layout doesn't fit.
@MainActor
struct CopyButton: View {
    @Environment(\.theme) private var theme

    let value: String
    @State private var justCopied = false

    var body: some View {
        Button {
            copy()
        } label: {
            Label(
                justCopied ? L10nString("common.copied") : L10nString("common.copy"),
                systemImage: justCopied ? "checkmark" : "doc.on.doc"
            )
            .font(AppTypography.footnote)
            .foregroundStyle(justCopied ? theme.success : theme.accent)
        }
        .buttonStyle(.bordered)
        .disabled(value.isEmpty)
    }

    private func copy() {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #endif
        withAnimation { justCopied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { justCopied = false }
        }
    }
}
