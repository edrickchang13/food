import XCTest
@testable import BulkAIEngine

final class WeeklyCheckInTests: XCTestCase {
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 1).adding(days: offset, in: .bulkAI)
    }

    func testNotDue_whenLessThanSevenDaysSinceOnboarding_andNoPriorCheckIn() {
        XCTAssertFalse(WeeklyCheckIn.isDue(
            lastCheckInDay: nil,
            onboardingDay: day(0),
            today: day(6)
        ))
    }

    func testDue_whenSevenDaysSinceOnboarding_andNoPriorCheckIn() {
        XCTAssertTrue(WeeklyCheckIn.isDue(
            lastCheckInDay: nil,
            onboardingDay: day(0),
            today: day(7)
        ))
    }

    func testNotDue_whenFewerThanSevenDaysSinceLastCheckIn() {
        XCTAssertFalse(WeeklyCheckIn.isDue(
            lastCheckInDay: day(0),
            onboardingDay: day(-30),
            today: day(6)
        ))
    }

    func testDue_whenSevenDaysSinceLastCheckIn() {
        XCTAssertTrue(WeeklyCheckIn.isDue(
            lastCheckInDay: day(0),
            onboardingDay: day(-30),
            today: day(7)
        ))
    }

    func testProposal_packsExpectedFields() {
        let expenditure = ExpenditureEstimate(
            kcalPerDay: 2600,
            confidence: .high,
            windowDays: 14,
            foodLogDays: 14,
            weightLogDays: 10,
            priorKcalPerDay: 2500,
            clampApplied: false
        )
        let trend = [
            TrendPoint(day: day(0), kg: 80, rawKg: 80),
            TrendPoint(day: day(7), kg: 79.5, rawKg: 79.5),
            TrendPoint(day: day(14), kg: 79.0, rawKg: 79.0)
        ]
        let proposal = WeeklyCheckIn.makeProposal(
            today: day(14),
            priorExpenditureKcalPerDay: 2500,
            newExpenditure: expenditure,
            weightKg: 79,
            leanBodyMassKg: 67,
            target: WeeklyTarget(goal: .lose, weeklyRateAsFractionOfBodyweight: 0.005),
            trend: trend
        )
        XCTAssertEqual(proposal.day, day(14))
        XCTAssertEqual(proposal.priorExpenditureKcalPerDay, 2500)
        XCTAssertEqual(proposal.newExpenditure.kcalPerDay, 2600)
        XCTAssertEqual(proposal.trendDeltaKg ?? .nan, -0.5, accuracy: 1e-9)  // day 14 - day 7
        // Plan uses the new expenditure for kcal target calc.
        // weeklyDelta = 79 * 0.005 * 7700 = 3041.5, daily = 434.5, target = 2600 - 434.5 = 2165.5
        XCTAssertEqual(proposal.proposedPlan.kcalTarget, 2165.5, accuracy: 0.01)
    }

    func testRecordDecision_accepted_appliesProposedPlan() {
        let proposal = makeProposalFixture()
        let record = WeeklyCheckIn.recordDecision(proposal: proposal, decision: .accepted)
        XCTAssertEqual(record.decision, .accepted)
        XCTAssertEqual(record.appliedPlan, proposal.proposedPlan)
    }

    func testRecordDecision_adjusted_appliesAdjustedPlan() {
        let proposal = makeProposalFixture()
        let adjusted = DailyPlan(
            kcalTarget: 2100,
            macros: MacroTargets(proteinG: 150, fatG: 50, carbsG: 230),
            floorApplied: false
        )
        let record = WeeklyCheckIn.recordDecision(
            proposal: proposal,
            decision: .adjusted,
            adjustedPlan: adjusted
        )
        XCTAssertEqual(record.appliedPlan, adjusted)
    }

    func testRecordDecision_skipped_leavesAppliedNil() {
        let proposal = makeProposalFixture()
        let record = WeeklyCheckIn.recordDecision(proposal: proposal, decision: .skipped)
        XCTAssertEqual(record.decision, .skipped)
        XCTAssertNil(record.appliedPlan)
    }

    // MARK: - Helpers

    private func makeProposalFixture() -> CheckInProposal {
        let expenditure = ExpenditureEstimate(
            kcalPerDay: 2600,
            confidence: .high,
            windowDays: 14,
            foodLogDays: 14,
            weightLogDays: 10,
            priorKcalPerDay: 2500,
            clampApplied: false
        )
        return WeeklyCheckIn.makeProposal(
            today: day(14),
            priorExpenditureKcalPerDay: 2500,
            newExpenditure: expenditure,
            weightKg: 79,
            leanBodyMassKg: 67,
            target: WeeklyTarget(goal: .lose, weeklyRateAsFractionOfBodyweight: 0.005),
            trend: []
        )
    }
}
