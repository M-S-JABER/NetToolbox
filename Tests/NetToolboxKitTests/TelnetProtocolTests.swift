import XCTest
@testable import NetToolboxKit

final class TelnetProtocolTests: XCTestCase {
    private let iac = TelnetProtocol.iac
    private let doo = TelnetProtocol.doo
    private let dont = TelnetProtocol.dont
    private let will = TelnetProtocol.will
    private let wont = TelnetProtocol.wont
    private let sb = TelnetProtocol.sb
    private let se = TelnetProtocol.se

    func testPlainTextPassesThrough() {
        let result = TelnetProtocol.process(Array("hi".utf8))
        XCTAssertEqual(result.text, "hi")
        XCTAssertTrue(result.reply.isEmpty)
    }

    func testEscapedIACLiteral() {
        // IAC IAC is a literal 0xFF data byte; it is consumed (not treated as a
        // command) and a following char survives. (0xFF alone isn't valid UTF-8,
        // so we assert on the trailing char and the absence of any reply.)
        let result = TelnetProtocol.process([iac, iac, 0x41])   // 0xFF literal then 'A'
        XCTAssertTrue(result.text.hasSuffix("A"))
        XCTAssertTrue(result.reply.isEmpty)
    }

    func testDoTerminalTypeAgrees() {
        let result = TelnetProtocol.process([iac, doo, TelnetProtocol.optTType])
        XCTAssertEqual(result.reply, [iac, will, TelnetProtocol.optTType])
    }

    func testDoWindowSizeAgreesAndSendsSize() {
        let result = TelnetProtocol.process([iac, doo, TelnetProtocol.optNAWS])
        XCTAssertEqual(result.reply, [
            iac, will, TelnetProtocol.optNAWS,
            iac, sb, TelnetProtocol.optNAWS, 0, 80, 0, 24, iac, se,
        ])
    }

    func testWillEchoAccepted() {
        let result = TelnetProtocol.process([iac, will, TelnetProtocol.optEcho])
        XCTAssertEqual(result.reply, [iac, doo, TelnetProtocol.optEcho])
    }

    func testUnknownDoRefused() {
        let result = TelnetProtocol.process([iac, doo, 99])
        XCTAssertEqual(result.reply, [iac, wont, 99])
    }

    func testUnknownWillRefused() {
        let result = TelnetProtocol.process([iac, will, 99])
        XCTAssertEqual(result.reply, [iac, dont, 99])
    }

    func testTerminalTypeSendAnsweredWithXterm() {
        let result = TelnetProtocol.process([iac, sb, TelnetProtocol.optTType, TelnetProtocol.sbSEND, iac, se])
        XCTAssertEqual(result.reply, [iac, sb, TelnetProtocol.optTType, TelnetProtocol.sbIS] + Array("xterm".utf8) + [iac, se])
    }

    func testDontIsNotAcknowledged() {
        // Acknowledging DONT/WONT would risk a negotiation loop.
        let result = TelnetProtocol.process([iac, dont, TelnetProtocol.optSGA])
        XCTAssertTrue(result.reply.isEmpty)
    }
}
