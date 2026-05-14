import Testing
@testable import BulkAIEngine

// MARK: - Holding-State and Active-State threshold tests
//
// Spec: the engine enters Holding state (returning the prior estimate with .low
// confidence) when EITHER of these conditions is true within a 7-day window:
//   • fewer than 3 days of nutrition data  (minFoodLogs = 3)
//   • fewer than 1 day of weight data      (minWeightLogs = 1)

@Suite("Expenditure Holding State")
struct ExpenditureHoldingStateTests {

    // MARK: - Helpers

    /// Base anchor: 2026-05-14. Day offsets are relative to this date.
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 14).adding(days: offset, in: .bulkAI)
    }

    /// Builds N consecutive DailyIntake entries starting at day(0), each at 2000 kcal.
    private func intakeLogs(days n: Int, from startOffset: Int = 0) -> [DailyIntake] {
        (0..<n).map { DailyIntake(day: day(startOffset + $0), kcal: 2000) }
    }

    /// Builds a linear trend from startKg to endKg across `n` consecutive days from day(0).
    /// All points are real weigh-ins (rawKg non-nil, isInterpolated = false).
    private func realTrend(startKg: Double, endKg: Double, days n: Int, from startOffset: Int = 0) -> [TrendPoint] {
        guard n > 1 else {
            return [TrendPoint(day: day(startOffset), kg: startKg, rawKg: startKg)]
        }
        let step = (endKg - startKg) / Double(n - 1)
        return (0..<n).map { i in
            let kg = startKg + step * Double(i)
            return TrendPoint(day: day(startOffset + i), kg: kg, rawKg: kg)
        }
    }

    // MARK: - Holding state: insufficient food logs

    @Test("Holding: returns prior with .low confidence when fewer than 3 food-log days")
    func holdingState_insufficientFoodLogs() {
        // 2 food log days in the 7-day window (days 0 and 1).
        // 3 real weight log days in the same window; weight threshold is met.
        // Because 2 < minFoodLogs (3), engine must enter Holding state.
        let intake = intakeLogs(days: 2)                               // days 0–1
        let trend = realTrend(startKg: 80, endKg: 79.5, days: 3)      // days 0–2

        let result = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1700,
            windowDays: 7,
            referenceDay: day(6)
        )

        #expect(result.kcalPerDay == 2500)
        #expect(result.confidence == .low)
        #expect(result.foodLogDays == 2)
    }

    // MARK: - Holding state: zero weight-log days

    @Test("Holding: returns prior with .low confidence when zero weight-log days")
    func holdingState_zeroWeightLogs() {
        // 5 food log days in the 7-day window; food threshold is met.
        // All trend points have rawKg == nil (interpolated) so weightLogDays = 0.
        // Because 0 < minWeightLogs (1), engine must enter Holding state.
        let intake = intakeLogs(days: 5)                               // days 0–4
        let trend = (0..<7).map { i in
            TrendPoint(day: day(i), kg: 80.0, rawKg: nil)             // all interpolated
        }

        let result = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1700,
            windowDays: 7,
            referenceDay: day(6)
        )

        #expect(result.kcalPerDay == 2500)
        #expect(result.confidence == .low)
        #expect(result.weightLogDays == 0)
    }

    // MARK: - Active state: both thresholds met, non-trivial trend change

    @Test("Active: computes new estimate when both thresholds met")
    func activeState_thresholdsMet() {
        // 4 food log days (>= minFoodLogs 3) and 2 real weight log days (>= minWeightLogs 1).
        // Weight drops from 80 to 79.5 kg across the 2-point trend (span = 6 calendar days,
        // day 0 to day 6). trendChange = -0.5 kg.
        // avgIntake = 2000 kcal (4 identical logs).
        // Raw expenditure = 2000 - (-0.5 × 7700)/6 ≈ 2641.7
        // Prior = 2500; upper clamp = 2500 × 1.15 = 2875 (no clamp).
        // BMR bounds: floor = 1700 × 1.1 = 1870, ceiling = 1700 × 2.5 = 4250 (no clamp).
        // Result should differ from prior and carry .medium confidence (4 < highConfidenceFoodLogs 10).
        let intake = intakeLogs(days: 4)
        let trend = [
            TrendPoint(day: day(0), kg: 80.0,  rawKg: 80.0),
            TrendPoint(day: day(6), kg: 79.5,  rawKg: 79.5)
        ]

        let result = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1700,
            windowDays: 7,
            referenceDay: day(6)
        )

        #expect(result.kcalPerDay != 2500)
        #expect(result.confidence == .medium)
        // Sanity-check the approximate value (trendSpan = 6 days).
        let expected = 2000 - (-0.5 * 7700) / 6   // ≈ 2641.7
        #expect(abs(result.kcalPerDay - expected) < 1)
    }

    // MARK: - Active state: high-confidence thresholds met

    @Test("Active high-confidence: 10 food log days + 7 weight log days yields .high")
    func activeState_highConfidence() {
        // Use a 14-day window so we can accumulate 10 food log days and 7 real weight
        // log days, both at or above the high-confidence thresholds
        // (highConfidenceFoodLogs = 10, highConfidenceWeightLogs = 7).
        //
        // Weight drops mildly: 80 → 79.5 kg over 13 calendar days (day 0 to day 13).
        // trendChange = -0.5 kg, trendSpan = 13 days.
        // avgIntake = 2000 kcal (10 identical logs across days 0–9).
        // Raw expenditure = 2000 - (-0.5 × 7700)/13 ≈ 2296.2
        // Prior = 2500; lower clamp = 2500 × 0.85 = 2125 (not triggered).
        // BMR bounds: floor = 1700 × 1.1 = 1870, ceiling = 1700 × 2.5 = 4250 (not triggered).
        let intake = intakeLogs(days: 10)       // 10 food log days (days 0–9)
        let weightLogs: [TrendPoint] = (0..<7).map { i in
            // 7 evenly-spaced real weigh-ins across the 14-day window (days 0, 2, 4, 6, 8, 10, 12).
            let kg = 80.0 - (0.5 / 6.0) * Double(i * 2)
            return TrendPoint(day: day(i * 2), kg: kg, rawKg: kg)
        }

        let result = Expenditure.estimate(
            intakeLogs: intake,
            trend: weightLogs,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1700,
            windowDays: 14,
            referenceDay: day(13)
        )

        #expect(result.confidence == .high)
        #expect(result.foodLogDays == 10)
        #expect(result.weightLogDays == 7)
        #expect(result.kcalPerDay != 2500)
    }
}
