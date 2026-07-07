import XCTest
@testable import NetToolboxKit

/// Runs the whole on-device `EngineTestSuite` under XCTest, so CI verifies every
/// pure-logic self-test (and, by building the module for iOS, compiles the
/// entire app). Mirrors what Diagnostics → Engine Self-Tests runs on device.
final class EngineSelfTests: XCTestCase {
    @MainActor
    func testAllEngineSelfTestsPass() {
        let outcomes = EngineTestSuite.runAll()
        XCTAssertFalse(outcomes.isEmpty, "No self-tests ran")
        for outcome in outcomes {
            XCTAssertNil(outcome.failureMessage, "\(outcome.name): \(outcome.failureMessage ?? "")")
        }
    }
}
