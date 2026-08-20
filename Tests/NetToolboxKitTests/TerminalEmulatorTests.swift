import XCTest
@testable import NetToolboxKit

final class TerminalEmulatorTests: XCTestCase {

    func testPlainTextAndNewlines() {
        let term = TerminalEmulator()
        term.feed("hello\nworld")
        XCTAssertEqual(term.plainText, "hello\nworld")
    }

    func testCarriageReturnOverwrites() {
        let term = TerminalEmulator()
        term.feed("abc\rX")
        XCTAssertEqual(term.plainText, "Xbc")
    }

    func testBackspace() {
        let term = TerminalEmulator()
        term.feed("abc\u{08} ")   // backspace then space overwrites 'c'
        // The overwriting space is a trailing blank, so it trims away: the
        // point is that 'c' is gone (a broken backspace would leave "abc").
        XCTAssertEqual(term.plainText, "ab")
    }

    func testSGRIsStrippedFromTextButColoursTheCell() {
        let term = TerminalEmulator()
        term.feed("\u{1B}[31mred\u{1B}[0m")
        XCTAssertEqual(term.plainText, "red")
        let firstCell = term.displayLines[0][0]
        XCTAssertEqual(firstCell.style.foreground, .indexed(1))   // red
    }

    func testEraseLineFromCursor() {
        let term = TerminalEmulator()
        term.feed("abcdef\r\u{1B}[Kxyz")   // CR home, erase to EOL, then xyz
        XCTAssertEqual(term.plainText, "xyz")
    }

    func testCursorPositionAndClear() {
        let term = TerminalEmulator()
        term.feed("\u{1B}[2J\u{1B}[1;1HAB\u{1B}[1;1HX")
        XCTAssertEqual(term.plainText, "XB")
    }

    func testAutoWrap() {
        let term = TerminalEmulator(rows: 24, columns: 80)
        term.feed(String(repeating: "a", count: 81))
        let lines = term.plainText.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, 80)
        XCTAssertEqual(lines[1], "a")
    }

    func testScrollPushesIntoScrollback() {
        let term = TerminalEmulator(rows: 3, columns: 80)
        term.feed("l1\nl2\nl3\nl4")   // 4 lines into a 3-row screen → l1 scrolls
        XCTAssertEqual(term.plainText, "l1\nl2\nl3\nl4")
    }

    func testUnknownCSIIgnored() {
        let term = TerminalEmulator()
        term.feed("a\u{1B}[6nb")   // device-status-report request is ignored
        XCTAssertEqual(term.plainText, "ab")
    }
}
