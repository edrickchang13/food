import XCTest
@testable import BulkAIEngine

final class WeightTrendTests: XCTestCase {
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 1).adding(days: offset, in: .bulkAI)
    }

    func testEmptyLogs_returnsEmpty() {
        XCTAssertTrue(WeightTrend.compute(logs: []).isEmpty)
    }

    func testSingleLog_returnsSinglePoint_trendEqualsRaw() {
        let logs = [WeightLog(day: day(0), kg: 80)]
        let trend = WeightTrend.compute(logs: logs)
        XCTAssertEqual(trend.count, 1)
        XCTAssertEqual(trend[0].kg, 80, accuracy: 1e-9)
        XCTAssertEqual(trend[0].rawKg, 80)
        XCTAssertFalse(trend[0].isInterpolated)
    }

    func testTwoConsecutiveDays_appliesEWMA() {
        let logs = [
            WeightLog(day: day(0), kg: 80),
            WeightLog(day: day(1), kg: 79)
        ]
        let trend = WeightTrend.compute(logs: logs, alpha: 0.1)
        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(trend[0].kg, 80, accuracy: 1e-9)
        // trend[1] = 0.1 * 79 + 0.9 * 80 = 7.9 + 72 = 79.9
        XCTAssertEqual(trend[1].kg, 79.9, accuracy: 1e-9)
        XCTAssertFalse(trend[1].isInterpolated)
    }

    func testGapBetweenLogs_interpolatesLinearly_thenAppliesEWMA() {
        // PRD example: Monday 150, Wednesday 148 → Tuesday imputed as 149.
        let logs = [
            WeightLog(day: day(0), kg: 150),
            WeightLog(day: day(2), kg: 148)
        ]
        let trend = WeightTrend.compute(logs: logs, alpha: 0.1)
        XCTAssertEqual(trend.count, 3)
        // Day 1 raw is interpolated to 149.
        XCTAssertNil(trend[1].rawKg)
        XCTAssertTrue(trend[1].isInterpolated)
        // trend[1] = 0.1 * 149 + 0.9 * 150 = 14.9 + 135 = 149.9
        XCTAssertEqual(trend[1].kg, 149.9, accuracy: 1e-9)
        // trend[2] = 0.1 * 148 + 0.9 * 149.9 = 14.8 + 134.91 = 149.71
        XCTAssertEqual(trend[2].kg, 149.71, accuracy: 1e-9)
        XCTAssertFalse(trend[2].isInterpolated)
    }

    func testMultipleLogsSameDay_areAveraged() {
        let logs = [
            WeightLog(day: day(0), kg: 80),
            WeightLog(day: day(0), kg: 82)
        ]
        let trend = WeightTrend.compute(logs: logs)
        XCTAssertEqual(trend.count, 1)
        XCTAssertEqual(trend[0].kg, 81, accuracy: 1e-9)
    }

    func testConstantInput_converges() {
        let logs = (0..<30).map { WeightLog(day: day($0), kg: 75) }
        let trend = WeightTrend.compute(logs: logs, alpha: 0.1)
        XCTAssertEqual(trend.count, 30)
        XCTAssertEqual(trend.last!.kg, 75, accuracy: 1e-9)
    }

    func testLinearlyDecreasingInput_trendLagsButTracks() {
        // Drop 1 kg/day for 30 days starting at 100.
        let logs = (0..<30).map { WeightLog(day: day($0), kg: 100 - Double($0)) }
        let trend = WeightTrend.compute(logs: logs, alpha: 0.1)
        XCTAssertEqual(trend.count, 30)
        // After enough days the trend should be strictly between the latest raw and the start.
        XCTAssertLessThan(trend.last!.kg, 90)
        XCTAssertGreaterThan(trend.last!.kg, 71)
        // And monotonically decreasing — EWMA preserves monotonicity for monotonic input.
        for i in 1..<trend.count {
            XCTAssertLessThanOrEqual(trend[i].kg, trend[i - 1].kg + 1e-9)
        }
    }

    func testAlphaOne_trendEqualsRawForEachDay() {
        let logs = [
            WeightLog(day: day(0), kg: 80),
            WeightLog(day: day(1), kg: 78),
            WeightLog(day: day(2), kg: 79)
        ]
        let trend = WeightTrend.compute(logs: logs, alpha: 1.0)
        XCTAssertEqual(trend.map { $0.kg }, [80, 78, 79])
    }

    func testUnsortedInput_isHandled() {
        let logs = [
            WeightLog(day: day(2), kg: 78),
            WeightLog(day: day(0), kg: 80),
            WeightLog(day: day(1), kg: 79)
        ]
        let trend = WeightTrend.compute(logs: logs, alpha: 1.0)
        XCTAssertEqual(trend.map { $0.day }, [day(0), day(1), day(2)])
        XCTAssertEqual(trend.map { $0.kg }, [80, 79, 78])
    }
}
