import XCTest
@testable import BulkAIEngine

final class DataQualityTests: XCTestCase {

    // MARK: - Helpers

    /// Reference day used across all tests: 2026-05-14.
    private let ref = CalendarDay(year: 2026, month: 5, day: 14)

    /// Build a `CalendarDay` that is `offset` days before the reference day.
    private func daysAgo(_ offset: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: 5, day: 14).adding(days: -offset, in: .bulkAI)
    }

    // MARK: - Test 1: Empty inputs → score 0, .sparse

    func testEmptyInputs_scoreZero_bucketSparse() {
        let inputs = DataQualityInputs(
            foodLogDays: [],
            weightLogDays: [],
            bodyFatLogDays: [],
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.bucket, .sparse)
        XCTAssertEqual(result.foodLogDays, 0)
        XCTAssertEqual(result.weightLogDays, 0)
        XCTAssertEqual(result.bodyFatLogDays, 0)
        XCTAssertEqual(result.windowDays, 7)
    }

    // MARK: - Test 2: Perfect 7-day week → score 100, .dense

    func testPerfectWeek_scoreHundred_bucketDense() {
        // All 7 days (0 through 6 days ago) have food + weight + body-fat logs.
        let allDays: Set<CalendarDay> = Set((0..<7).map { daysAgo($0) })
        let inputs = DataQualityInputs(
            foodLogDays: allDays,
            weightLogDays: allDays,
            bodyFatLogDays: allDays,
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        // 7/7 food → 55, 7/7 weight → 35, 7/7 body-fat → 10 = 100
        XCTAssertEqual(result.score, 100)
        XCTAssertEqual(result.bucket, .dense)
        XCTAssertEqual(result.foodLogDays, 7)
        XCTAssertEqual(result.weightLogDays, 7)
        XCTAssertEqual(result.bodyFatLogDays, 7)
    }

    // MARK: - Test 3: Food-only daily → score 55, .workable

    func testFoodOnlyEveryDay_score55_bucketWorkable() {
        // 7 food logs, 0 weight, 0 body-fat.
        let foodDays: Set<CalendarDay> = Set((0..<7).map { daysAgo($0) })
        let inputs = DataQualityInputs(
            foodLogDays: foodDays,
            weightLogDays: [],
            bodyFatLogDays: [],
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        // 7/7 food → 55, 0 weight → 0, 0 body-fat → 0 = 55
        XCTAssertEqual(result.score, 55)
        XCTAssertEqual(result.bucket, .workable)
        XCTAssertEqual(result.foodLogDays, 7)
        XCTAssertEqual(result.weightLogDays, 0)
    }

    // MARK: - Test 4: Food daily + weight 3x/week → score 70, .solid

    func testFoodDailyWeightThreeTimes_score70_bucketSolid() {
        // food every day (7), weight on 3 of 7 days, no body-fat.
        let foodDays: Set<CalendarDay> = Set((0..<7).map { daysAgo($0) })
        let weightDays: Set<CalendarDay> = [daysAgo(0), daysAgo(2), daysAgo(4)]
        let inputs = DataQualityInputs(
            foodLogDays: foodDays,
            weightLogDays: weightDays,
            bodyFatLogDays: [],
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        // 7/7 food → 55, 3/7 weight = 3*35/7 = 15, 0 body-fat → 0 = 70
        XCTAssertEqual(result.score, 70)
        XCTAssertEqual(result.bucket, .solid)
        XCTAssertEqual(result.weightLogDays, 3)
    }

    // MARK: - Test 5: Window boundary — windowDays-1 ago counts, windowDays ago does not

    func testWindowBoundary_oldestIncludedDayCountsNewestExcludedDayDoesNot() {
        // windowDays = 7: days 0–6 ago are in window; day 7 ago is NOT.
        let inWindowDay = daysAgo(6)   // exactly windowDays - 1 ago → included
        let outOfWindowDay = daysAgo(7) // exactly windowDays ago → excluded

        let inputs = DataQualityInputs(
            foodLogDays: [inWindowDay, outOfWindowDay],
            weightLogDays: [],
            bodyFatLogDays: [],
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        // Only inWindowDay should be counted.
        XCTAssertEqual(result.foodLogDays, 1)

        // 1/7 food → 1*55/7 = 7
        XCTAssertEqual(result.score, 7)
        XCTAssertEqual(result.bucket, .sparse)
    }

    // MARK: - Test 6: Future log day does NOT count

    func testFutureLogDay_doesNotCount() {
        // A log day after the reference day must be excluded.
        let futureDay = CalendarDay(year: 2026, month: 5, day: 15) // ref + 1
        let inputs = DataQualityInputs(
            foodLogDays: [futureDay],
            weightLogDays: [futureDay],
            bodyFatLogDays: [futureDay],
            referenceDay: ref
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        XCTAssertEqual(result.foodLogDays, 0)
        XCTAssertEqual(result.weightLogDays, 0)
        XCTAssertEqual(result.bodyFatLogDays, 0)
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.bucket, .sparse)
    }

    // MARK: - Test 7: 30-day window with same 7-day logs yields lower score

    func testThirtyDayWindow_sameSevenDayLogs_lowerScore() {
        // Same coverage as test 4 (7 food, 3 weight) but the window is 30 days,
        // so the proportional score is much lower.
        let foodDays: Set<CalendarDay> = Set((0..<7).map { daysAgo($0) })
        let weightDays: Set<CalendarDay> = [daysAgo(0), daysAgo(2), daysAgo(4)]
        let inputs = DataQualityInputs(
            foodLogDays: foodDays,
            weightLogDays: weightDays,
            bodyFatLogDays: [],
            referenceDay: ref,
            windowDays: 30
        )
        let result = DataQuality.compute(inputs, calendar: .bulkAI)

        // food: 7*55/30 = 385/30 = 12 (integer division)
        // weight: 3*35/30 = 105/30 = 3
        // body-fat: 0
        // total: 15
        XCTAssertEqual(result.foodLogDays, 7)
        XCTAssertEqual(result.weightLogDays, 3)
        XCTAssertEqual(result.score, 15)
        XCTAssertEqual(result.bucket, .sparse)
        XCTAssertEqual(result.windowDays, 30)
    }

    // MARK: - Bucket boundary tests

    func testBucketFrom_boundaries() {
        XCTAssertEqual(DataQualityBucket.from(score: 0), .sparse)
        XCTAssertEqual(DataQualityBucket.from(score: 39), .sparse)
        XCTAssertEqual(DataQualityBucket.from(score: 40), .workable)
        XCTAssertEqual(DataQualityBucket.from(score: 69), .workable)
        XCTAssertEqual(DataQualityBucket.from(score: 70), .solid)
        XCTAssertEqual(DataQualityBucket.from(score: 89), .solid)
        XCTAssertEqual(DataQualityBucket.from(score: 90), .dense)
        XCTAssertEqual(DataQualityBucket.from(score: 100), .dense)
    }

    // MARK: - Component weights sum check

    func testComponentMaxWeightsSumToHundred() {
        let total = DataQuality.foodComponentMax
            + DataQuality.weightComponentMax
            + DataQuality.bodyFatComponentMax
        XCTAssertEqual(total, 100)
    }
}
