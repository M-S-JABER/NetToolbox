import Foundation

/// A colour in the terminal palette. `default` means "use the view's default
/// foreground/background"; `indexed` is the 16-colour ANSI palette (0–15);
/// `rgb` is a 24-bit truecolour value.
enum TerminalColor: Equatable, Sendable {
    case `default`
    case indexed(Int)
    case rgb(UInt8, UInt8, UInt8)
}

/// The rendition of a single cell.
struct TerminalStyle: Equatable, Sendable {
    var foreground: TerminalColor = .default
    var background: TerminalColor = .default
    var bold = false
    var inverse = false
}

/// One character cell on the screen.
struct TerminalCell: Equatable, Sendable {
    var character: Character = " "
    var style = TerminalStyle()
}

/// A compact VT100/ANSI terminal emulator: it consumes the raw byte stream a
/// shell produces (colours, cursor movement, line/screen erase) and maintains a
/// fixed `rows × columns` screen plus a capped scrollback, so a SwiftUI view can
/// render real terminal output instead of raw escape bytes.
///
/// Scope is deliberately the common interactive-shell subset — SGR colours,
/// cursor addressing, erase, wrap and scroll. Full-screen alt-buffer apps
/// (vi, htop) that rely on the private alt-screen and every DEC mode aren't
/// fully modelled, but ordinary prompts, coloured `ls`, `git`, pagers and
/// `clear` render correctly. Pure and unit-tested; no UIKit/SwiftUI here.
final class TerminalEmulator {
    let rows: Int
    let columns: Int
    private let maxScrollback: Int

    private var screen: [[TerminalCell]]
    private var scrollback: [[TerminalCell]] = []
    private var cursorRow = 0
    private var cursorCol = 0
    private var style = TerminalStyle()

    private enum State {
        case normal
        case escape
        case csi
        case osc          // ESC ] … (BEL | ST)-terminated — skipped
        case oscEscape    // saw ESC inside OSC, waiting for '\' (ST)
        case charset      // ESC ( / ) / # — consume one more byte
    }
    private var state: State = .normal
    private var params = ""

    init(rows: Int = 24, columns: Int = 80, maxScrollback: Int = 1000) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.maxScrollback = max(0, maxScrollback)
        self.screen = Array(repeating: Self.blankRow(columns), count: self.rows)
    }

    private static func blankRow(_ columns: Int) -> [TerminalCell] {
        Array(repeating: TerminalCell(), count: columns)
    }

    // MARK: - Feeding

    func feed(_ text: String) {
        for character in text { process(character) }
    }

    func reset() {
        screen = Array(repeating: Self.blankRow(columns), count: rows)
        scrollback.removeAll()
        cursorRow = 0; cursorCol = 0
        style = TerminalStyle()
        state = .normal; params = ""
    }

    private func process(_ character: Character) {
        switch state {
        case .normal:      processNormal(character)
        case .escape:      processEscape(character)
        case .csi:         processCSI(character)
        case .osc:         processOSC(character)
        case .oscEscape:   state = (character == "\\") ? .normal : .osc
        case .charset:     state = .normal   // consume the charset designator
        }
    }

    private func processNormal(_ character: Character) {
        switch character {
        case "\u{1B}": state = .escape
        case "\n", "\u{0B}", "\u{0C}": lineFeed()
        case "\r": cursorCol = 0
        case "\u{08}": if cursorCol > 0 { cursorCol -= 1 }
        case "\t": cursorCol = min(columns - 1, ((cursorCol / 8) + 1) * 8)
        case "\u{07}": break   // bell
        default:
            guard !character.isASCII || character.asciiValue.map({ $0 >= 0x20 }) ?? true else { return }
            putCharacter(character)
        }
    }

    private func processEscape(_ character: Character) {
        switch character {
        case "[": state = .csi; params = ""
        case "]": state = .osc
        case "(", ")", "#", "*", "+": state = .charset
        case "c": reset()                 // RIS — full reset
        default: state = .normal          // ignore other 2-byte escapes
        }
    }

    private func processOSC(_ character: Character) {
        if character == "\u{07}" { state = .normal }          // BEL terminates
        else if character == "\u{1B}" { state = .oscEscape }  // maybe ST (ESC \)
    }

    private func processCSI(_ character: Character) {
        guard let ascii = character.asciiValue else { state = .normal; return }
        if ascii >= 0x40 && ascii <= 0x7E {   // final byte
            executeCSI(final: character)
            state = .normal
        } else {
            params.append(character)          // parameter / intermediate bytes
        }
    }

    // MARK: - Screen operations

    private func putCharacter(_ character: Character) {
        if cursorCol >= columns {   // auto-wrap
            cursorCol = 0
            lineFeed()
        }
        screen[cursorRow][cursorCol] = TerminalCell(character: character, style: style)
        cursorCol += 1
    }

    private func lineFeed() {
        // Treat LF as newline (line-down + carriage-return). Interactive shells
        // send CRLF, and the extra CR here is harmless for them; it also makes
        // plain output that uses bare "\n" start each line at column 0 instead
        // of drifting right (LF-only would keep the column).
        cursorCol = 0
        if cursorRow >= rows - 1 {
            // Scroll: the top line rolls into scrollback, a blank line appears
            // at the bottom.
            scrollback.append(screen[0])
            if scrollback.count > maxScrollback { scrollback.removeFirst(scrollback.count - maxScrollback) }
            screen.removeFirst()
            screen.append(Self.blankRow(columns))
        } else {
            cursorRow += 1
        }
    }

    private func numericParams() -> [Int] {
        params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }

    private func executeCSI(final: Character) {
        // Private-mode sequences (ESC [ ? … h/l) — DEC modes we don't model.
        if params.hasPrefix("?") { return }
        let values = numericParams()
        func value(_ index: Int, default def: Int = 0) -> Int {
            index < values.count ? values[index] : def
        }

        switch final {
        case "m":
            applySGR(values.isEmpty ? [0] : values)
        case "H", "f":   // cursor position (1-based row;col)
            cursorRow = min(max(value(0, default: 1) - 1, 0), rows - 1)
            cursorCol = min(max(value(1, default: 1) - 1, 0), columns - 1)
        case "A": cursorRow = max(0, cursorRow - max(1, value(0, default: 1)))
        case "B": cursorRow = min(rows - 1, cursorRow + max(1, value(0, default: 1)))
        case "C": cursorCol = min(columns - 1, cursorCol + max(1, value(0, default: 1)))
        case "D": cursorCol = max(0, cursorCol - max(1, value(0, default: 1)))
        case "G": cursorCol = min(max(value(0, default: 1) - 1, 0), columns - 1)   // CHA
        case "d": cursorRow = min(max(value(0, default: 1) - 1, 0), rows - 1)      // VPA
        case "J": eraseInDisplay(value(0))
        case "K": eraseInLine(value(0))
        default: break   // unsupported CSI — safely ignored
        }
    }

    private func eraseInLine(_ mode: Int) {
        switch mode {
        case 0: for col in cursorCol..<columns { screen[cursorRow][col] = blankCell() }
        case 1: for col in 0...min(cursorCol, columns - 1) { screen[cursorRow][col] = blankCell() }
        case 2: screen[cursorRow] = Self.blankRow(columns).map { _ in blankCell() }
        default: break
        }
    }

    private func eraseInDisplay(_ mode: Int) {
        switch mode {
        case 0:
            eraseInLine(0)
            if cursorRow + 1 < rows { for row in (cursorRow + 1)..<rows { screen[row] = blankScreenRow() } }
        case 1:
            eraseInLine(1)
            if cursorRow > 0 { for row in 0..<cursorRow { screen[row] = blankScreenRow() } }
        case 2, 3:
            screen = Array(repeating: blankScreenRow(), count: rows)
            cursorRow = 0; cursorCol = 0
        default: break
        }
    }

    /// A blank cell carries the current background so erases fill with it.
    private func blankCell() -> TerminalCell {
        var cell = TerminalCell()
        cell.style.background = style.background
        return cell
    }

    private func blankScreenRow() -> [TerminalCell] {
        Array(repeating: blankCell(), count: columns)
    }

    // MARK: - SGR (colours / attributes)

    private func applySGR(_ codes: [Int]) {
        var index = 0
        while index < codes.count {
            let code = codes[index]
            switch code {
            case 0: style = TerminalStyle()
            case 1: style.bold = true
            case 22: style.bold = false
            case 7: style.inverse = true
            case 27: style.inverse = false
            case 30...37: style.foreground = .indexed(code - 30)
            case 90...97: style.foreground = .indexed(code - 90 + 8)
            case 39: style.foreground = .default
            case 40...47: style.background = .indexed(code - 40)
            case 100...107: style.background = .indexed(code - 100 + 8)
            case 49: style.background = .default
            case 38, 48:
                // Extended colour: 38;5;n (indexed) or 38;2;r;g;b (truecolour).
                let isForeground = code == 38
                if index + 1 < codes.count, codes[index + 1] == 5, index + 2 < codes.count {
                    let color = TerminalColor.indexed(codes[index + 2])
                    if isForeground { style.foreground = color } else { style.background = color }
                    index += 2
                } else if index + 1 < codes.count, codes[index + 1] == 2, index + 4 < codes.count {
                    let color = TerminalColor.rgb(UInt8(clamping: codes[index + 2]), UInt8(clamping: codes[index + 3]), UInt8(clamping: codes[index + 4]))
                    if isForeground { style.foreground = color } else { style.background = color }
                    index += 4
                }
            default: break
            }
            index += 1
        }
    }

    // MARK: - Output

    /// Every line currently on screen (scrollback first, then the live screen),
    /// with trailing blank cells on each line trimmed.
    var displayLines: [[TerminalCell]] {
        (scrollback + screen).map { row in
            var line = row
            while let last = line.last, last.character == " ", last.style.background == .default, !last.style.inverse {
                line.removeLast()
            }
            return line
        }
    }

    /// Plain text of the whole buffer (scrollback + screen), trailing blank
    /// lines trimmed. Used by tests and copy/share.
    var plainText: String {
        var lines = displayLines.map { String($0.map(\.character)) }
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
