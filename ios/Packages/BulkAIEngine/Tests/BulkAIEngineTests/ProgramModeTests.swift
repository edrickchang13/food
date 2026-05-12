import XCTest
@testable import BulkAIEngine

final class ProgramModeTests: XCTestCase {
    func testCoachedCapabilities() {
        XCTAssertTrue(ProgramMode.coached.autoAdjustsTargets)
        XCTAssertTrue(ProgramMode.coached.promptsWeeklyCheckIn)
        XCTAssertFalse(ProgramMode.coached.allowsManualDailyDistribution)
    }

    func testCollaborativeCapabilities() {
        XCTAssertTrue(ProgramMode.collaborative.autoAdjustsTargets)
        XCTAssertTrue(ProgramMode.collaborative.promptsWeeklyCheckIn)
        XCTAssertTrue(ProgramMode.collaborative.allowsManualDailyDistribution)
    }

    func testManualCapabilities() {
        XCTAssertFalse(ProgramMode.manual.autoAdjustsTargets)
        XCTAssertFalse(ProgramMode.manual.promptsWeeklyCheckIn)
        XCTAssertFalse(ProgramMode.manual.allowsManualDailyDistribution)
    }

    func testAllCasesCoveredByPolicyFunctions() {
        // Defensive: if a future case is added, this fails until policies are updated.
        for mode in ProgramMode.allCases {
            _ = mode.autoAdjustsTargets
            _ = mode.promptsWeeklyCheckIn
            _ = mode.allowsManualDailyDistribution
        }
        XCTAssertEqual(ProgramMode.allCases.count, 3)
    }
}
