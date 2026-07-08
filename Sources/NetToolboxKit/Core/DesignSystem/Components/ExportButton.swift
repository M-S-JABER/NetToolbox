import SwiftUI

/// A small "Export" button that shares text (CSV/JSON) via the system share
/// sheet, so any tool can hand its results off to Files, Mail, etc.
@MainActor
struct ExportButton: View {
    /// The text to share (e.g. CSV rows).
    let content: String
    /// A short preview title shown in the share sheet.
    var title: LocalizedStringResource = L10n("common.export")

    var body: some View {
        ShareLink(item: content, preview: SharePreview(Text(title))) {
            Label(L10nString("common.export"), systemImage: "square.and.arrow.up")
                .font(AppTypography.footnote)
        }
        .buttonStyle(.bordered)
        .disabled(content.isEmpty)
    }
}

/// Helpers for building CSV safely (quotes fields containing separators).
enum CSV {
    static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func row(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",")
    }

    static func table(header: [String], rows: [[String]]) -> String {
        ([row(header)] + rows.map(row)).joined(separator: "\n")
    }
}
