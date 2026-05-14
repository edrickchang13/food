import XCTest
@testable import BulkAIEngine

final class ExpenditureEdgeCaseTests: XCTestCase {
    // Base anchor: 2026-05-15 (mid-month, leaves room for negative offsets into April
    // and positive offsets into June, exercising cross-month calendar arithmetic).
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 15).adding(days: offset, in: .bulkAI)
    }

    // Builds a fully-real (non-interpolated) linear trend spanning `days` days.
    private func linearTrend(startKg: Double, endKg: Double, days: Int = 14) -> [TrendPoint] {
        guard days > 1 else {
            return [TrendPoint(day: day(0), kg: startKg, rawKg: startKg)]
        }
        let step = (endKg - startKg) / Double(days - 1)
        return (0..<days).map { i in
            let kg = startKg + step * Double(i)
            return TrendPoint(day: day(i), kg: kg, rawKg: kg)
        }
    }

    // MARK: - Case 1: All-zero intake (user fasted for entire window)

    func testAllZeroIntake_fastingUser_bmrFloorApplied() {
        // 14 days of zero intake, stable weight → raw expenditure = 0 kcal/day.
        // ±15% clamp against prior 2000: lower = 1700. BMR floor = 1.1 × 1600 = 1760.
        // 1700 < 1760 so BMR floor wins → 1760.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 0) }
        let trend = linearTrend(startKg: 80, endKg: 80)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2000,
            bmrKcalPerDay: 1600,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 1760, accuracy: 0.5)
        XCTAssertTrue(est.clampApplied)
    }

    // MARK: - Case 2: Mix of zero and non-zero intake days

    func testMixedZeroAndNonZeroIntake_averagesOverLoggedDaysNotAllDays() {
        // 4 logged days: 0, 2000, 2000, 2000 kcal.
        // Average over those 4 days = (0+2000+2000+2000)/4 = 1500.
        // Stable weight → expenditure = 1500.
        let intake = [
            DailyIntake(day: day(0), kcal: 0),
            DailyIntake(day: day(1), kcal: 2000),
            DailyIntake(day: day(2), kcal: 2000),
            DailyIntake(day: day(3), kcal: 2000)
        ]
        let trend = linearTrend(startKg: 80, endKg: 80)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 1600,
            bmrKcalPerDay: 1200,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.foodLogDays, 4)
        // Within ±15% of 1600 (1360–1840) and above BMR floor (1320) → no clamp.
        XCTAssertEqual(est.kcalPerDay, 1500, accuracy: 1)
        XCTAssertFalse(est.clampApplied)
    }

    // MARK: - Case 3: Multiple intake entries on the same day (sum per day, then average)

    func testMultipleIntakeEntriesSameDay_summedWithinDayThenAveragedAcrossDays() {
        // Day 0: two meals (800 + 700 = 1500). Days 1-3: 2000 each.
        // Per-day totals: 1500, 2000, 2000, 2000 → average = 7500/4 = 1875.
        let intake = [
            DailyIntake(day: day(0), kcal: 800),
            DailyIntake(day: day(0), kcal: 700),
            DailyIntake(day: day(1), kcal: 2000),
            DailyIntake(day: day(2), kcal: 2000),
            DailyIntake(day: day(3), kcal: 2000)
        ]
        let trend = linearTrend(startKg: 80, endKg: 80)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 1900,
            bmrKcalPerDay: 1400,
            referenceDay: day(13)
        )
        // Unique food-log days = 4 (two entries on day 0 collapse to one day).
        XCTAssertEqual(est.foodLogDays, 4)
        // Stable weight → expenditure = average intake = 1875.
        XCTAssertEqual(est.kcalPerDay, 1875, accuracy: 1)
    }

    // MARK: - Case 4: All trend points in window are interpolated (zero real weight logs)

    func testOnlyInterpolatedWeightPointsInWindow_returnsLowConfidence() {
        // 10 food logs satisfy the food threshold, but every trend point has rawKg == nil.
        // weightLogDays = 0 < minWeightLogs (3) → should return prior with .low confidence.
        let intake = (0..<10).map { DailyIntake(day: day($0), kcal: 2200) }
        let allInterpolated = (0..<14).map { i in
            TrendPoint(day: day(i), kg: 80.0, rawKg: nil)
        }
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: allInterpolated,
            priorKcalPerDay: 2400,
            bmrKcalPerDay: 1600,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.confidence, .low)
        XCTAssertEqual(est.kcalPerDay, 2400)
        XCTAssertEqual(est.weightLogDays, 0)
    }

    // MARK: - Case 5: Reference day in the future (window extends beyond available data)

    func testReferenceDayInFuture_logsOutsideWindowNotCounted() {
        // Logs exist on days 0-13. Reference day is day(27): window = day(14)..day(27).
        // No logs fall inside that window → below thresholds → .low.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = linearTrend(startKg: 80, endKg: 79)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2700,
            bmrKcalPerDay: 1600,
            referenceDay: day(27)
        )
        XCTAssertEqual(est.confidence, .low)
        XCTAssertEqual(est.kcalPerDay, 2700)
        XCTAssertEqual(est.foodLogDays, 0)
        XCTAssertEqual(est.weightLogDays, 0)
    }

    // MARK: - Case 6: Reference day before any data exists

    func testReferenceDayBeforeAnyData_returnsLowConfidence() {
        // All logs start at day(10). Reference day is day(0): window = day(-13)..day(0).
        // No logs fall inside → .low.
        let intake = (10..<24).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = (10..<24).map { i in
            TrendPoint(day: day(i), kg: 80.0, rawKg: 80.0)
        }
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1600,
            referenceDay: day(0)
        )
        XCTAssertEqual(est.confidence, .low)
        XCTAssertEqual(est.kcalPerDay, 2500)
    }

    // MARK: - Case 7: trendSpanDays = 1 (first and last trend points one day apart)

    func testTrendSpanOfOneDay_formulaDoesNotCrashOrNaN() {
        // Trend has 3 real points at days 0, 1, 2; food logs cover days 0-3.
        // The window is wide (windowDays=14, referenceDay=day(13)) but the trend only
        // covers days 0-2 → trendSpanDays = 2, trendChangeKg = -1.5 kg.
        // Raw expenditure = 2500 − (−1.5 × 7700)/2 = 2500 + 5775 = 8275.
        // Prior upper clamp: 2500 × 1.15 = 2875. BMR ceiling: 1400 × 2.5 = 3500.
        // 2875 < 3500, so result = 2875.
        let intake = [
            DailyIntake(day: day(0), kcal: 2500),
            DailyIntake(day: day(1), kcal: 2500),
            DailyIntake(day: day(2), kcal: 2500),
            DailyIntake(day: day(3), kcal: 2500)
        ]
        let trend = [
            TrendPoint(day: day(0), kg: 80.0, rawKg: 80.0),
            TrendPoint(day: day(1), kg: 79.0, rawKg: 79.0),
            TrendPoint(day: day(2), kg: 78.5, rawKg: 78.5)
        ]
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1400,
            referenceDay: day(13)
        )
        XCTAssertFalse(est.kcalPerDay.isNaN)
        XCTAssertFalse(est.kcalPerDay.isInfinite)
        XCTAssertEqual(est.kcalPerDay, 2875, accuracy: 0.5)
        XCTAssertTrue(est.clampApplied)
    }

    // MARK: - Case 8: Degenerate window (windowDays = 2, only 1 logged day) → .low

    func testDegenerateWindowTwoDays_singleLoggedDay_returnsLowConfidence() {
        // Minimum legal window (windowDays = 2). Only one food log day and two real weight
        // points → both below their respective minimums → .low confidence, returns prior.
        let intake = [DailyIntake(day: day(1), kcal: 2500)]
        let trend = [
            TrendPoint(day: day(0), kg: 80.0, rawKg: 80.0),
            TrendPoint(day: day(1), kg: 79.9, rawKg: 79.9)
        ]
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1600,
            windowDays: 2,
            referenceDay: day(1)
        )
        XCTAssertEqual(est.confidence, .low)
        XCTAssertEqual(est.kcalPerDay, 2500)
        XCTAssertEqual(est.foodLogDays, 1)  // 1 < minFoodLogs (4)
    }

    // MARK: - Case 9: Heavy weight loss → BMR ceiling prevents absurd expenditure

    func testHeavyWeightLoss_bmrCeilingApplied() {
        // 500 kcal/day for 14 days, 5 kg loss over 13 days.
        // Raw = 500 + (5 × 7700)/13 ≈ 500 + 2961.5 = 3461.5.
        // Prior upper = 6000 × 1.15 = 6900 → no prior clamp.
        // BMR ceiling = 1400 × 2.5 = 3500 → 3461.5 < 3500, no ceiling clamp either.
        // So clampApplied = false in this specific setup.
        // Verify result is finite and ≤ ceiling regardless.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 500) }
        let trend = linearTrend(startKg: 100, endKg: 95)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 6000,
            bmrKcalPerDay: 1400,
            referenceDay: day(13)
        )
        XCTAssertLessThanOrEqual(est.kcalPerDay, 1400 * 2.5 + 0.1)
        XCTAssertFalse(est.kcalPerDay.isNaN)
        XCTAssertFalse(est.kcalPerDay.isInfinite)
        // More extreme scenario: 15 kg loss forces BMR ceiling clamp.
        let trendExtreme = linearTrend(startKg: 100, endKg: 85)
        let estExtreme = Expenditure.estimate(
            intakeLogs: intake,
            trend: trendExtreme,
            priorKcalPerDay: 20000,
            bmrKcalPerDay: 1400,
            referenceDay: day(13)
        )
        XCTAssertEqual(estExtreme.kcalPerDay, 1400 * 2.5, accuracy: 0.5)
        XCTAssertTrue(estExtreme.clampApplied)
    }

    // MARK: - Case 10: Prior expenditure of 0 — clamp math must not produce NaN

    func testZeroPriorExpenditure_doesNotProduceNaN() {
        // priorKcalPerDay = 0. ±15% clamp: lower = 0, upper = 0.
        // Any raw expenditure is clamped to 0, then BMR floor = 1.1 × 1600 = 1760 lifts it.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = linearTrend(startKg: 80, endKg: 80)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 0,
            bmrKcalPerDay: 1600,
            referenceDay: day(13)
        )
        XCTAssertFalse(est.kcalPerDay.isNaN)
        XCTAssertFalse(est.kcalPerDay.isInfinite)
        XCTAssertEqual(est.kcalPerDay, 1760, accuracy: 0.5)
        XCTAssertTrue(est.clampApplied)
    }

    // MARK: - Case 11: Cross-month window boundary (April → May)

    func testCrossMonthWindowBoundary_calendarArithmeticIsCorrect() {
        // Anchor on 2026-05-05; window back 13 days reaches 2026-04-22.
        let anchor = CalendarDay(year: 2026, month: 5, day: 5)
        let windowStart = anchor.adding(days: -13, in: .bulkAI)

        XCTAssertEqual(windowStart.year, 2026)
        XCTAssertEqual(windowStart.month, 4)
        XCTAssertEqual(windowStart.day, 22)

        let intake = (0..<14).map { i in
            DailyIntake(day: anchor.adding(days: i - 13, in: .bulkAI), kcal: 2400)
        }
        let trend = (0..<14).map { i -> TrendPoint in
            let d = anchor.adding(days: i - 13, in: .bulkAI)
            return TrendPoint(day: d, kg: 80.0, rawKg: 80.0)
        }
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2400,
            bmrKcalPerDay: 1600,
            referenceDay: anchor
        )
        // Stable weight → expenditure = average intake = 2400.
        XCTAssertEqual(est.kcalPerDay, 2400, accuracy: 1)
        XCTAssertEqual(est.foodLogDays, 14)
        XCTAssertEqual(est.weightLogDays, 14)
    }

    // MARK: - Case 11b: Cross-year window boundary (December → January)

    func testCrossYearWindowBoundary_calendarArithmeticIsCorrect() {
        // Anchor on 2027-01-10; window back 13 days reaches 2026-12-28.
        let anchor = CalendarDay(year: 2027, month: 1, day: 10)
        let windowStart = anchor.adding(days: -13, in: .bulkAI)

        XCTAssertEqual(windowStart.year, 2026)
        XCTAssertEqual(windowStart.month, 12)
        XCTAssertEqual(windowStart.day, 28)

        let intake = (0..<14).map { i in
            DailyIntake(day: anchor.adding(days: i - 13, in: .bulkAI), kcal: 2600)
        }
        let trend = (0..<14).map { i -> TrendPoint in
            let d = anchor.adding(days: i - 13, in: .bulkAI)
            return TrendPoint(day: d, kg: 75.0, rawKg: 75.0)
        }
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2600,
            bmrKcalPerDay: 1500,
            referenceDay: anchor
        )
        XCTAssertEqual(est.kcalPerDay, 2600, accuracy: 1)
        XCTAssertEqual(est.foodLogDays, 14)
        XCTAssertEqual(est.weightLogDays, 14)
    }

    // MARK: - Case 12: Constant intake + stable weight → expenditure equals that intake

    func testConstantIntakeStableWeight_expenditureEqualsIntake() {
        // 14 days of exactly 2200 kcal, flat weight at 77 kg.
        // trendChangeKg = 0 → expenditure = avgIntake − 0 = 2200.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2200) }
        let trend = linearTrend(startKg: 77, endKg: 77)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2200,
            bmrKcalPerDay: 1500,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2200, accuracy: 1)
        XCTAssertFalse(est.clampApplied)
        XCTAssertEqual(est.confidence, .high)
    }
}
