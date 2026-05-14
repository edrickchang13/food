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
        // PRD example: Monday 150, Wednesday 148 -> Tuesday imputed as 149.
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
        // And monotonically decreasing -- EWMA preserves monotonicity for monotonic input.
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

    // MARK: - slope(trend:minPoints:) tests

    private func trendPoints(from kgs: [Double]) -> [TrendPoint] {
        kgs.enumerated().map { i, kg in
            TrendPoint(day: day(i), kg: kg, rawKg: kg)
        }
    }

    func testSlope_insufficientData_returnsNil() {
        // 5 points is below the default minPoints of 7
        let trend = trendPoints(from: [75, 75, 75, 75, 75])
        XCTAssertNil(WeightTrend.slope(trend: trend))
    }

    func testSlope_perfectlyFlat_slopeAndSEAreZero() {
        let trend = trendPoints(from: Array(repeating: 75.0, count: 10))
        guard let result = WeightTrend.slope(trend: trend) else {
            return XCTFail("Expected non-nil slope for 10 flat points")
        }
        XCTAssertEqual(result.kgPerWeek, 0.0, accuracy: 1e-9)
        // SST = 0 when all ys are identical; rSquared is defined as 0 in that branch.
        XCTAssertEqual(result.rSquared, 0.0, accuracy: 1e-9)
        XCTAssertEqual(result.standardError, 0.0, accuracy: 1e-9)
        XCTAssertEqual(result.sampleSize, 10)
    }

    func testSlope_linearRampUp_slopeAndRSquaredNearPerfect() {
        // +0.1 kg/day for 10 days => slope ~0.7 kg/week, R^2 ~1
        let kgs = (0..<10).map { 75.0 + 0.1 * Double($0) }
        let trend = trendPoints(from: kgs)
        guard let result = WeightTrend.slope(trend: trend) else {
            return XCTFail("Expected non-nil slope")
        }
        XCTAssertEqual(result.kgPerWeek, 0.7, accuracy: 0.01)
        XCTAssertEqual(result.rSquared, 1.0, accuracy: 1e-6)
        XCTAssertLessThan(result.standardError, 1e-6)
        XCTAssertEqual(result.sampleSize, 10)
    }

    func testSlope_linearRampDown_negativeSlope() {
        // -0.05 kg/day for 10 days => slope ~-0.35 kg/week
        let kgs = (0..<10).map { 80.0 - 0.05 * Double($0) }
        let trend = trendPoints(from: kgs)
        guard let result = WeightTrend.slope(trend: trend) else {
            return XCTFail("Expected non-nil slope")
        }
        XCTAssertEqual(result.kgPerWeek, -0.35, accuracy: 0.01)
        XCTAssertEqual(result.rSquared, 1.0, accuracy: 1e-6)
        XCTAssertLessThan(result.standardError, 1e-6)
    }

    func testSlope_noisyRamp_slopeWithinToleranceAndRSquaredInRange() {
        // Underlying +0.05 kg/day trend over 14 days with repeating small noise.
        let noise: [Double] = [0.1, -0.1, 0.05, -0.05, 0.08, -0.08, 0.03]
        let kgs = (0..<14).map { i in 70.0 + 0.05 * Double(i) + noise[i % noise.count] }
        let trend = trendPoints(from: kgs)
        guard let result = WeightTrend.slope(trend: trend) else {
            return XCTFail("Expected non-nil slope")
        }
        // Generous tolerance given the noise
        XCTAssertEqual(result.kgPerWeek, 0.35, accuracy: 0.15)
        XCTAssertGreaterThan(result.rSquared, 0.3)
        XCTAssertLessThan(result.rSquared, 1.0)
        XCTAssertGreaterThan(result.standardError, 0.0)
        XCTAssertEqual(result.sampleSize, 14)
    }
}
