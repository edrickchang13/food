import XCTest
@testable import BulkAIEngine

// MARK: - Helpers

private func makePlan(kcal: Double, proteinG: Double, fatG: Double, carbsG: Double) -> DailyPlan {
    DailyPlan(
        kcalTarget: kcal,
        macros: MacroTargets(proteinG: proteinG, fatG: fatG, carbsG: carbsG),
        floorApplied: false
    )
}

// MARK: - MacroDistributorTests

final class MacroDistributorTests: XCTestCase {

    // MARK: - Standard base used by tests 1-5

    /// 2400 kcal, 180g protein (720 kcal), remaining = 1680 kcal.
    private let standardBase = makePlan(kcal: 2400, proteinG: 180, fatG: 80, carbsG: 220)

    // MARK: - Test 1: Balanced reshape

    func testBalanced_reshapesMacros() {
        // remaining = 2400 - 720 = 1680 kcal
        // fat  = 30% * 1680 = 504 kcal → 56g
        // carbs = 70% * 1680 = 1176 kcal → 294g
        let result = MacroDistributor.distribute(base: standardBase, preference: .balanced)

        XCTAssertEqual(result.proteinG, 180, accuracy: 1e-9)
        XCTAssertEqual(result.fatG, 56, accuracy: 1e-6)
        XCTAssertEqual(result.carbsG, 294, accuracy: 1e-6)
        XCTAssertFalse(result.clampApplied)
        XCTAssertEqual(result.preference, .balanced)
    }

    // MARK: - Test 2: Low-fat reshape

    func testLowFat_cappsFatAtTwentyPercent() {
        // fat  = 20% * 1680 = 336 kcal → 37.333...g
        // carbs = 80% * 1680 = 1344 kcal → 336g
        let result = MacroDistributor.distribute(base: standardBase, preference: .lowFat)

        XCTAssertEqual(result.proteinG, 180, accuracy: 1e-9)
        XCTAssertEqual(result.fatG,   336.0 / 9.0, accuracy: 1e-6)
        XCTAssertEqual(result.carbsG, 1344.0 / 4.0, accuracy: 1e-6)
        XCTAssertFalse(result.clampApplied)
    }

    // MARK: - Test 3: Low-carb reshape

    func testLowCarb_capsCarbs() {
        // fat  = 75% * 1680 = 1260 kcal → 140g
        // carbs = 25% * 1680 = 420 kcal → 105g
        let result = MacroDistributor.distribute(base: standardBase, preference: .lowCarb)

        XCTAssertEqual(result.proteinG, 180, accuracy: 1e-9)
        XCTAssertEqual(result.fatG,   1260.0 / 9.0, accuracy: 1e-6)
        XCTAssertEqual(result.carbsG, 420.0 / 4.0, accuracy: 1e-6)
        XCTAssertFalse(result.clampApplied)
    }

    // MARK: - Test 4: Keto reshape

    func testKeto_capsCarbs() {
        // fat  = 90% * 1680 = 1512 kcal → 168g
        // carbs = 10% * 1680 = 168 kcal → 42g
        let result = MacroDistributor.distribute(base: standardBase, preference: .keto)

        XCTAssertEqual(result.proteinG, 180, accuracy: 1e-9)
        XCTAssertEqual(result.fatG,   1512.0 / 9.0, accuracy: 1e-6)
        XCTAssertEqual(result.carbsG, 168.0 / 4.0, accuracy: 1e-6)
        XCTAssertFalse(result.clampApplied)
    }

    // MARK: - Test 5: Sum invariant across all preferences

    func testSumInvariant_macroKcalEqualsTarget_allPreferences() {
        for preference in DietPreference.allCases {
            let result = MacroDistributor.distribute(base: standardBase, preference: preference)
            XCTAssertEqual(
                result.macroKcal,
                result.kcalTarget,
                accuracy: 5,
                "Sum failed for preference \(preference)"
            )
        }
    }

    // MARK: - Test 6: Floor clamp triggers

    func testFloorClamp_triggersWhenCarbsBelowFivePercent() {
        // 1500 kcal, 200g protein → 800 kcal protein, remaining = 700 kcal
        // keto: carbs = 10% * 700 = 70 kcal < 5% * 1500 = 75 kcal → clamp fires
        let base = makePlan(kcal: 1500, proteinG: 200, fatG: 50, carbsG: 100)
        let result = MacroDistributor.distribute(base: base, preference: .keto)

        XCTAssertTrue(result.clampApplied)
        // Carbs should be at the 5% floor: 75 kcal / 4 = 18.75g
        XCTAssertEqual(result.carbsG, 75.0 / 4.0, accuracy: 1e-6)
        XCTAssertGreaterThanOrEqual(result.fatG, 0)
    }

    // MARK: - Test 7: High protein, low remainder doesn't crash

    func testHighProtein_lowRemainder_noNegativeMacros() {
        // 1200 kcal, 200g protein → 800 kcal protein, remaining = 400 kcal
        // balanced: fat = 30% * 400 = 120 kcal, carbs = 70% * 400 = 280 kcal
        // floors: 5% * 1200 = 60 kcal — both are above floor, no clamp
        let base = makePlan(kcal: 1200, proteinG: 200, fatG: 30, carbsG: 50)
        let result = MacroDistributor.distribute(base: base, preference: .balanced)

        XCTAssertGreaterThanOrEqual(result.fatG, 0)
        XCTAssertGreaterThanOrEqual(result.carbsG, 0)
        XCTAssertFalse(result.clampApplied)
        XCTAssertEqual(result.fatG,   120.0 / 9.0, accuracy: 1e-6)
        XCTAssertEqual(result.carbsG, 280.0 / 4.0, accuracy: 1e-6)
    }
}
