import SwiftUI

/// Renders a terminal buffer (rows of styled cells from `TerminalEmulator`) as
/// coloured, monospaced text. Consecutive cells that share a style are merged
/// into one attributed run, so `ls --color`, prompts and `git` output show
/// their real colours instead of raw escape codes.
@MainActor
struct TerminalView: View {
    @Environment(\.theme) private var theme

    let lines: [[TerminalCell]]
    /// Cap the rendered tail so a long scrollback stays smooth.
    var maxLines = 400
    var minHeight: CGFloat = 120

    var body: some View {
        Text(attributed)
            .font(AppTypography.monoCaption)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .environment(\.layoutDirection, .leftToRight)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(theme.background)
            )
    }

    private var attributed: AttributedString {
        let visible = lines.suffix(maxLines)
        var output = AttributedString()
        for (index, line) in visible.enumerated() {
            output += runs(for: line)
            if index < visible.count - 1 { output += AttributedString("\n") }
        }
        if output.characters.isEmpty { output = AttributedString(" ") }
        return output
    }

    /// Merges neighbouring same-style cells into attributed runs.
    private func runs(for line: [TerminalCell]) -> AttributedString {
        var result = AttributedString()
        var index = 0
        while index < line.count {
            let style = line[index].style
            var text = ""
            while index < line.count, line[index].style == style {
                text.append(line[index].character)
                index += 1
            }
            var run = AttributedString(text)
            let baseForeground = resolve(style.foreground, fallback: theme.success)
            let baseBackground: Color? = {
                if case .default = style.background { return nil }
                return resolve(style.background, fallback: theme.background)
            }()
            if style.inverse {
                // Swap: text takes the background colour, cell takes the text colour.
                run.foregroundColor = baseBackground ?? theme.background
                run.backgroundColor = baseForeground
            } else {
                run.foregroundColor = baseForeground
                if let baseBackground { run.backgroundColor = baseBackground }
            }
            if style.bold { run.font = AppTypography.monoCaption.weight(.bold) }
            result += run
        }
        return result
    }

    /// Maps a terminal colour to a SwiftUI colour.
    private func resolve(_ color: TerminalColor, fallback: Color) -> Color {
        switch color {
        case .default: return fallback
        case .rgb(let r, let g, let b):
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        case .indexed(let n):
            return Self.palette[max(0, min(n, Self.palette.count - 1))]
        }
    }

    /// xterm-style 16-colour palette (0–7 normal, 8–15 bright), tuned to stay
    /// legible on both light and dark themed backgrounds.
    private static let palette: [Color] = [
        Color(hex: 0x3B3B3B), // black
        Color(hex: 0xD64541), // red
        Color(hex: 0x2E9E52), // green
        Color(hex: 0xB8860B), // yellow
        Color(hex: 0x3B7DD8), // blue
        Color(hex: 0x9B59B6), // magenta
        Color(hex: 0x1F9EA6), // cyan
        Color(hex: 0xB0B0B0), // white
        Color(hex: 0x6B6B6B), // bright black
        Color(hex: 0xF05B5B), // bright red
        Color(hex: 0x3FBF6A), // bright green
        Color(hex: 0xE0A93B), // bright yellow
        Color(hex: 0x5A9BF0), // bright blue
        Color(hex: 0xC07AD8), // bright magenta
        Color(hex: 0x38C3CC), // bright cyan
        Color(hex: 0xEDEDED), // bright white
    ]
}
