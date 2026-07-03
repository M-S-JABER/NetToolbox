import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A technical value with a one-tap copy button and brief confirmation.
struct CopyableValue: View {
    @Environment(\.theme) private var theme

    let value: String
    var font: Font = AppTypography.monoBody

    @State private var justCopied = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(value)
                .font(font)
                .foregroundStyle(theme.mono)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // Keep IPs/MACs left-to-right in RTL locales.
                .environment(\.layoutDirection, .leftToRight)

            Button {
                copy()
            } label: {
                Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                    .font(.footnote)
                    .foregroundStyle(justCopied ? theme.success : theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(justCopied ? Text("common.copied") : Text("common.copy"))
        }
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
