import XCTest
@testable import BulkAIEngine

final class ExpenditureTests: XCTestCase {
    private func day(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 1).adding(days: offset, in: .bulkAI)
    }

    // Build a 14-day synthetic trend that interpolates linearly from startKg to endKg.
    // The intake side reasons about kcalIn so the trend's day-by-day curve doesn't matter
    // for the formula — only the endpoints do.
    private func linearTrend(startKg: Double, endKg: Double, days: Int = 14) -> [TrendPoint] {
        guard days > 1 else {
            return [TrendPoint(day: day(0), kg: startKg, rawKg: startKg)]
        }
        let step = (endKg - startKg) / Double(days - 1)
        return (0..<days).map { i in
            TrendPoint(day: day(i), kg: startKg + step * Double(i), rawKg: startKg + step * Double(i))
        }
    }

    func testBelowFoodLogThreshold_returnsPriorWithLowConfidence() {
        // Spec threshold is `minFoodLogs = 3`. Fewer than 3 days must hold the
        // prior estimate. Two intake days satisfies "below threshold."
        let intake = [
            DailyIntake(day: day(0), kcal: 2500),
            DailyIntake(day: day(1), kcal: 2500)
        ]
        let trend = linearTrend(startKg: 80, endKg: 79)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2700,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2700)
        XCTAssertEqual(est.confidence, .low)
    }

    func testBelowWeightLogThreshold_returnsPriorWithLowConfidence() {
        // Spec threshold is `minWeightLogs = 1`. Zero RAW weigh-ins (only
        // interpolated trend points) puts us below the threshold even when
        // food intake is amply logged.
        let intake = (0..<10).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = [
            // `isInterpolated` is computed from `rawKg == nil`; passing
            // `rawKg: nil` is sufficient to mark these as interpolated.
            TrendPoint(day: day(0), kg: 80, rawKg: nil),
            TrendPoint(day: day(13), kg: 79, rawKg: nil)
        ]
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2700,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.confidence, .low)
        XCTAssertEqual(est.kcalPerDay, 2700)
    }

    func testStableWeight_expenditureEqualsAverageIntake() {
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = linearTrend(startKg: 80, endKg: 80)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2500, accuracy: 1)
        XCTAssertFalse(est.clampApplied)
    }

    func testWeightDroppingOneKgPerTwoWeeks_atTwentyFiveHundred_yieldsAboutThirtyHundred() {
        // 1 kg drop over 14 days at 2500 intake → expenditure = 2500 + 7700/14 = 2500 + 550 = 3050
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = linearTrend(startKg: 80, endKg: 79)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 3000,  // close to expected, no clamp
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        // Trend spans 13 days (day 0 to day 13), not 14. trendChange = -1, span = 13.
        // expenditure = 2500 - (-1 * 7700)/13 = 2500 + 592.3 ≈ 3092.3
        XCTAssertEqual(est.kcalPerDay, 3092.3, accuracy: 1)
        XCTAssertFalse(est.clampApplied)
        XCTAssertEqual(est.confidence, .high)
    }

    func testWeightGaining_intakeDownwardEstimate() {
        // 1 kg gain over 14 days at 3000 intake → expenditure ≈ 3000 - 7700/13 ≈ 2407.7
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 3000) }
        let trend = linearTrend(startKg: 80, endKg: 81)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2500,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2407.7, accuracy: 1)
    }

    func testFifteenPercentUpperClampApplied() {
        // Real formula wants 3092, prior is 2000 → upper clamp at 2300.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 2500) }
        let trend = linearTrend(startKg: 80, endKg: 79)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 2000,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2300, accuracy: 0.5)  // 2000 * 1.15
        XCTAssertTrue(est.clampApplied)
    }

    func testFifteenPercentLowerClampApplied() {
        // 1kg gain on 3000 intake → ~2407. Prior 3000 → lower clamp at 2550.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 3000) }
        let trend = linearTrend(startKg: 80, endKg: 81)
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 3000,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertEqual(est.kcalPerDay, 2550, accuracy: 0.5)  // 3000 * 0.85
        XCTAssertTrue(est.clampApplied)
    }

    func testBMRFloorEnforced() {
        // Cook up a scenario that would naturally produce a tiny number; floor at 1.1×BMR.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 1000) }
        let trend = linearTrend(startKg: 80, endKg: 82)  // gaining 2 kg
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 1500,
            bmrKcalPerDay: 1500,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertGreaterThanOrEqual(est.kcalPerDay, 1500 * 1.1)
        XCTAssertTrue(est.clampApplied)
    }

    func testBMRCeilingEnforced() {
        // Huge intake with heavy weight loss → unreasonably high TDEE. Ceiling at 2.5×BMR.
        let intake = (0..<14).map { DailyIntake(day: day($0), kcal: 6000) }
        let trend = linearTrend(startKg: 80, endKg: 76)  // loss of 4 kg in 14 days, very aggressive
        let est = Expenditure.estimate(
            intakeLogs: intake,
            trend: trend,
            priorKcalPerDay: 5000,
            bmrKcalPerDay: 1600,
            windowDays: 14,
            referenceDay: day(13)
        )
        XCTAssertLessThanOrEqual(est.kcalPerDay, 1600 * 2.5)
        XCTAssertTrue(est.clampApplied)
    }

    func testMifflinStJeor_male() {
        // 80 kg, 180 cm, 30 yr, male → 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let bmr = BMR.mifflinStJeor(weightKg: 80, heightCm: 180, ageYears: 30, sex: .male)
        XCTAssertEqual(bmr, 1780, accuracy: 0.01)
    }

    func testMifflinStJeor_female() {
        // 65 kg, 165 cm, 30 yr, female → 10*65 + 6.25*165 - 5*30 - 161 = 650 + 1031.25 - 150 - 161 = 1370.25
        let bmr = BMR.mifflinStJeor(weightKg: 65, heightCm: 165, ageYears: 30, sex: .female)
        XCTAssertEqual(bmr, 1370.25, accuracy: 0.01)
    }
}
