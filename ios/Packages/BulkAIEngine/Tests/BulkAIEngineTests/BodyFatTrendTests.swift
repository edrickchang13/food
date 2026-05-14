import XCTest
@testable import BulkAIEngine

final class BodyFatTrendTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a CalendarDay offset from 2026-01-01 by `offset` days.
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 1, day: 1).adding(days: offset, in: .bulkAI)
    }

    // MARK: - 1. Empty logs → empty result

    func testEmptyLogs_returnsEmpty() {
        let result = BodyFatTrend.compute(logs: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 2. Single log → single emitted point matching the input

    func testSingleLog_returnsSinglePoint_matchingInput() {
        let logs = [BodyFatLog(day: day(0), bodyFatFraction: 0.20)]
        let result = BodyFatTrend.compute(logs: logs)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].day, day(0))
        XCTAssertEqual(result[0].bodyFatFraction, 0.20, accuracy: 1e-9)
        XCTAssertFalse(result[0].isInterpolated)
    }

    // MARK: - 3. Two consecutive days — EWMA on day 1

    func testTwoConsecutiveDays_appliesEWMA() {
        // Day 0: seed = 0.20 (no prior, seeded to the reading).
        // Day 1: smoothed = 0.5 × 0.25 + 0.5 × 0.20 = 0.225
        let logs = [
            BodyFatLog(day: day(0), bodyFatFraction: 0.20),
            BodyFatLog(day: day(1), bodyFatFraction: 0.25)
        ]
        let result = BodyFatTrend.compute(logs: logs)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].bodyFatFraction, 0.20, accuracy: 1e-9)
        XCTAssertFalse(result[0].isInterpolated)
        XCTAssertEqual(result[1].bodyFatFraction, 0.225, accuracy: 1e-9)
        XCTAssertFalse(result[1].isInterpolated)
    }

    // MARK: - 4. One-week gap — days 1-6 carry forward, day 7 is a real reading

    func testOneWeekGap_interpolatesCarryForward_thenAppliesRealAlpha() {
        // Day 0: seed = 0.20.
        // Days 1-6: no log — carry-forward at 0.20, all isInterpolated = true.
        // Day 7: smoothed = 0.5 × 0.18 + 0.5 × 0.20 = 0.19.
        let logs = [
            BodyFatLog(day: day(0), bodyFatFraction: 0.20),
            BodyFatLog(day: day(7), bodyFatFraction: 0.18)
        ]
        let result = BodyFatTrend.compute(logs: logs)
        XCTAssertEqual(result.count, 8)

        // Day 0
        XCTAssertEqual(result[0].bodyFatFraction, 0.20, accuracy: 1e-9)
        XCTAssertFalse(result[0].isInterpolated)

        // Days 1-6 are carry-forward
        for i in 1...6 {
            XCTAssertTrue(result[i].isInterpolated, "day \(i) should be interpolated")
            XCTAssertEqual(result[i].bodyFatFraction, 0.20, accuracy: 1e-9)
        }

        // Day 7: real reading smoothed with prior = 0.20
        XCTAssertFalse(result[7].isInterpolated)
        XCTAssertEqual(result[7].bodyFatFraction, 0.19, accuracy: 1e-9)
    }

    // MARK: - 5. Out-of-order input → same result as sorted input

    func testOutOfOrderInput_producedSameResultAsSorted() {
        let sortedLogs = [
            BodyFatLog(day: day(0), bodyFatFraction: 0.20),
            BodyFatLog(day: day(3), bodyFatFraction: 0.21),
            BodyFatLog(day: day(5), bodyFatFraction: 0.19)
        ]
        let unsortedLogs = [
            BodyFatLog(day: day(5), bodyFatFraction: 0.19),
            BodyFatLog(day: day(0), bodyFatFraction: 0.20),
            BodyFatLog(day: day(3), bodyFatFraction: 0.21)
        ]

        let sortedResult = BodyFatTrend.compute(logs: sortedLogs)
        let unsortedResult = BodyFatTrend.compute(logs: unsortedLogs)

        XCTAssertEqual(sortedResult.count, unsortedResult.count)
        for (a, b) in zip(sortedResult, unsortedResult) {
            XCTAssertEqual(a.day, b.day)
            XCTAssertEqual(a.bodyFatFraction, b.bodyFatFraction, accuracy: 1e-9)
            XCTAssertEqual(a.isInterpolated, b.isInterpolated)
        }
    }

    // MARK: - 6. `today` parameter extends output past last log

    func testTodayParameter_extendsOutputBeyondLastLog() {
        // Last log on day 3, today = day 10. Expect days 0-10 → 11 points.
        let logs = [
            BodyFatLog(day: day(0), bodyFatFraction: 0.20),
            BodyFatLog(day: day(3), bodyFatFraction: 0.22)
        ]
        let result = BodyFatTrend.compute(logs: logs, today: day(10))
        XCTAssertEqual(result.count, 11)

        // Days 4-10 must all be interpolated carry-forwards.
        for i in 4...10 {
            XCTAssertTrue(result[i].isInterpolated, "day \(i) should be interpolated")
        }

        // All carry-forward values equal the smoothed value at day 3.
        let valueAtDay3 = result[3].bodyFatFraction
        for i in 4...10 {
            XCTAssertEqual(result[i].bodyFatFraction, valueAtDay3, accuracy: 1e-9)
        }
    }
}
