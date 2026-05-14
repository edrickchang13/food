import XCTest
@testable import BulkAIEngine

// MARK: - ProjectionTests

final class ProjectionTests: XCTestCase {

    // MARK: - Test Helpers

    /// Fixed reference date: 2026-05-14T00:00:00Z.
    private var today: Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 14
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Convenience: build a `WeightTrendSlope` without boilerplate.
    private func slope(
        kgPerWeek: Double,
        rSquared: Double = 0.9,
        standardError: Double = 0.02,
        sampleSize: Int = 14
    ) -> WeightTrendSlope {
        WeightTrendSlope(
            kgPerWeek: kgPerWeek,
            rSquared: rSquared,
            standardError: standardError,
            sampleSize: sampleSize
        )
    }

    // MARK: - Test 1: No slope → insufficientData

    func testNilSlope_returnsInsufficientData() throws {
        let result = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: nil,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .insufficientData)
        XCTAssertNil(result.projectedDate)
        XCTAssertNil(result.weeksToGoal)
        XCTAssertNil(result.confidenceLowerDate)
        XCTAssertNil(result.confidenceUpperDate)
        let reason = try XCTUnwrap(result.reason)
        XCTAssertTrue(
            reason.lowercased().contains("weight log") || reason.lowercased().contains("weight logs"),
            "Reason should mention weight logs; got: \(reason)"
        )
    }

    // MARK: - Test 2: At goal → goalReached

    func testAtGoal_withinThreshold_returnsGoalReached() {
        // 75.0 vs 75.05 → delta 0.05, which is within the 0.1 kg threshold.
        let result = GoalProjection.project(
            currentWeightKg: 75.0,
            goalWeightKg: 75.05,
            slope: slope(kgPerWeek: -0.3),
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .goalReached)
        XCTAssertEqual(result.projectedDate, today)
        XCTAssertNil(result.weeksToGoal)
        XCTAssertNil(result.confidenceLowerDate)
        XCTAssertNil(result.confidenceUpperDate)
    }

    // MARK: - Test 3: Stalled (cut direction)

    func testStalled_slopeFlat_returnsStalled() {
        // slope 0.01 kg/week is below the 0.05 threshold.
        let result = GoalProjection.project(
            currentWeightKg: 85,
            goalWeightKg: 75,
            slope: slope(kgPerWeek: 0.01),
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .stalled)
        XCTAssertNil(result.projectedDate)
        XCTAssertNil(result.weeksToGoal)
    }

    // MARK: - Test 4: Trending away — trying to gain while losing

    func testTrendingAway_losingWhileTryingToGain_returnsTrendingAway() {
        // current 70, goal 80 → needs to gain. slope -0.3 = losing.
        let result = GoalProjection.project(
            currentWeightKg: 70,
            goalWeightKg: 80,
            slope: slope(kgPerWeek: -0.3),
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .trendingAway)
        XCTAssertNil(result.projectedDate)
        XCTAssertNotNil(result.reason)
    }

    // MARK: - Test 5: Trending away — trying to lose while gaining

    func testTrendingAway_gainingWhileTryingToLose_returnsTrendingAway() {
        // current 80, goal 70 → needs to lose. slope +0.3 = gaining.
        let result = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 70,
            slope: slope(kgPerWeek: 0.3),
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .trendingAway)
        XCTAssertNil(result.projectedDate)
        XCTAssertNotNil(result.reason)
    }

    // MARK: - Test 6: Clean projection — losing toward goal

    func testProjection_losingTowardGoal_correctWeeksAndDate() throws {
        // current 80, goal 75, slope -0.5 kg/week → 10 weeks = 70 days.
        let result = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: slope(kgPerWeek: -0.5),
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .projected)
        let weeksToGoal = try XCTUnwrap(result.weeksToGoal)
        XCTAssertEqual(weeksToGoal, 10.0, accuracy: 0.001)

        let projectedDate = try XCTUnwrap(result.projectedDate)
        let expectedDate = calendar.date(byAdding: .day, value: 70, to: today)!
        let diffSeconds = abs(projectedDate.timeIntervalSince(expectedDate))
        // Tolerance: ±1 day = 86400 seconds.
        XCTAssertLessThanOrEqual(diffSeconds, 86_400, "projectedDate should be within 1 day of today+70")
    }

    // MARK: - Test 7: Clean projection — gaining toward goal, CI bounds populated

    func testProjection_gainingTowardGoal_boundsSet_lowerEarlierThanProjected() throws {
        // current 70, goal 75, slope +0.5 kg/week → 10 weeks.
        let testSlope = WeightTrendSlope(
            kgPerWeek: 0.5,
            rSquared: 0.95,
            standardError: 0.02,
            sampleSize: 14
        )
        let result = GoalProjection.project(
            currentWeightKg: 70,
            goalWeightKg: 75,
            slope: testSlope,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.status, .projected)

        let projected = try XCTUnwrap(result.projectedDate)
        let lower = try XCTUnwrap(result.confidenceLowerDate)
        let upper = try XCTUnwrap(result.confidenceUpperDate)
        let weeksToGoal = try XCTUnwrap(result.weeksToGoal)

        XCTAssertEqual(weeksToGoal, 10.0, accuracy: 0.001)
        // Lower bound is a faster slope → arrives earlier.
        XCTAssertLessThanOrEqual(
            lower.timeIntervalSinceReferenceDate,
            projected.timeIntervalSinceReferenceDate,
            "confidenceLowerDate should be on or before projectedDate"
        )
        // Upper bound is a slower slope → arrives later.
        XCTAssertGreaterThanOrEqual(
            upper.timeIntervalSinceReferenceDate,
            projected.timeIntervalSinceReferenceDate,
            "confidenceUpperDate should be on or after projectedDate"
        )
    }

    // MARK: - Test 8: High variance widens CI

    func testHighVariance_producesWiderCIThanLowVariance() throws {
        // Both scenarios: current 80, goal 75, slope -0.5 kg/week.
        // Low SE (test 6 baseline): SE = 0.02.
        // High SE: SE = 0.2 — large relative to slope magnitude.

        let narrowSlope = WeightTrendSlope(
            kgPerWeek: -0.5,
            rSquared: 0.95,
            standardError: 0.02,
            sampleSize: 14
        )
        let wideSlope = WeightTrendSlope(
            kgPerWeek: -0.5,
            rSquared: 0.6,
            standardError: 0.2,
            sampleSize: 14
        )

        let narrowResult = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: narrowSlope,
            today: today,
            calendar: calendar
        )
        let wideResult = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: wideSlope,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(narrowResult.status, .projected)
        XCTAssertEqual(wideResult.status, .projected)

        let narrowLower = try XCTUnwrap(narrowResult.confidenceLowerDate)
        let narrowUpper = try XCTUnwrap(narrowResult.confidenceUpperDate)
        let wideLower = try XCTUnwrap(wideResult.confidenceLowerDate)
        let wideUpper = try XCTUnwrap(wideResult.confidenceUpperDate)

        let narrowWindow = narrowUpper.timeIntervalSince(narrowLower)
        let wideWindow = wideUpper.timeIntervalSince(wideLower)

        XCTAssertGreaterThan(
            wideWindow,
            narrowWindow,
            "High-variance slope should produce a wider CI window than low-variance slope"
        )
    }

    // MARK: - Threshold boundary: exactly at flatSlopeThreshold is stalled

    func testExactlyAtFlatThreshold_isStalled() {
        let result = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: slope(kgPerWeek: -GoalProjection.flatSlopeThresholdKgPerWeek),
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(result.status, .stalled)
    }

    // MARK: - Threshold boundary: just above flatSlopeThreshold is projected

    func testJustAboveFlatThreshold_isProjected() {
        let justAbove = GoalProjection.flatSlopeThresholdKgPerWeek + 0.001
        let result = GoalProjection.project(
            currentWeightKg: 80,
            goalWeightKg: 75,
            slope: slope(kgPerWeek: -justAbove),
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(result.status, .projected)
    }
}
