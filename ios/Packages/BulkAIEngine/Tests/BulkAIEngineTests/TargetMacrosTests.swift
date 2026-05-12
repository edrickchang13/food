import XCTest
@testable import BulkAIEngine

final class TargetMacrosTests: XCTestCase {
    func testMaintain_targetEqualsExpenditure() {
        let raw = TargetMacros.rawCalorieTarget(
            expenditure: 2500,
            weightKg: 80,
            target: .maintain
        )
        XCTAssertEqual(raw, 2500, accuracy: 1e-9)
    }

    func testLose_halfPercentPerWeekAtEightyKg() {
        // weeklyDelta = 80 * 0.005 * 7700 = 3080. dailyAdj = 440. target = 2500 - 440 = 2060.
        let raw = TargetMacros.rawCalorieTarget(
            expenditure: 2500,
            weightKg: 80,
            target: WeeklyTarget(goal: .lose, weeklyRateAsFractionOfBodyweight: 0.005)
        )
        XCTAssertEqual(raw, 2060, accuracy: 1e-9)
    }

    func testGain_halfPercentPerWeekAtEightyKg() {
        let raw = TargetMacros.rawCalorieTarget(
            expenditure: 2500,
            weightKg: 80,
            target: WeeklyTarget(goal: .gain, weeklyRateAsFractionOfBodyweight: 0.005)
        )
        XCTAssertEqual(raw, 2940, accuracy: 1e-9)
    }

    func testMacroComposition_loseGoalAtKnownInputs() {
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: 2500,
            weightKg: 80,
            leanBodyMassKg: 70,
            target: WeeklyTarget(goal: .lose, weeklyRateAsFractionOfBodyweight: 0.005)
        )
        // Target 2060 kcal. Protein 2.0 * 70 = 140g (560). Fat 0.6 * 80 = 48g (432).
        // Carbs = (2060 - 560 - 432) / 4 = 1068 / 4 = 267g.
        XCTAssertEqual(plan.kcalTarget, 2060, accuracy: 1e-9)
        XCTAssertEqual(plan.macros.proteinG, 140, accuracy: 1e-9)
        XCTAssertEqual(plan.macros.fatG, 48, accuracy: 1e-9)
        XCTAssertEqual(plan.macros.carbsG, 267, accuracy: 1e-9)
        XCTAssertFalse(plan.floorApplied)
        // Macros sum back to the target.
        XCTAssertEqual(plan.macros.totalKcal, 2060, accuracy: 1e-6)
    }

    func testGainUsesLowerProteinPerKgLBM() {
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: 3000,
            weightKg: 80,
            leanBodyMassKg: 70,
            target: WeeklyTarget(goal: .gain, weeklyRateAsFractionOfBodyweight: 0.005)
        )
        // Gain protein per kg LBM = 1.8 → 1.8 * 70 = 126g.
        XCTAssertEqual(plan.macros.proteinG, 126, accuracy: 1e-9)
    }

    func testLBMEstimated_whenNotProvided() {
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: 2500,
            weightKg: 80,
            leanBodyMassKg: nil,
            target: .maintain
        )
        // Default estimate: 80 * 0.85 = 68. Protein = 2.0 * 68 = 136g.
        XCTAssertEqual(plan.macros.proteinG, 136, accuracy: 1e-9)
    }

    func testFloorApplied_whenTargetTooLow() {
        // 80 kg, LBM 70, lose. Protein 560 + Fat 432 + 50 floor = 1042 kcal.
        // Force target way below floor with extremely aggressive rate.
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: 1200,
            weightKg: 80,
            leanBodyMassKg: 70,
            target: WeeklyTarget(goal: .lose, weeklyRateAsFractionOfBodyweight: 0.02)  // 2%/wk, way too fast
        )
        // Raw = 1200 - (80*0.02*7700)/7 = 1200 - 1760 = -560. Floor bumps to 1042.
        XCTAssertEqual(plan.kcalTarget, 1042, accuracy: 1e-9)
        XCTAssertTrue(plan.floorApplied)
        // Carbs minimal but non-negative.
        XCTAssertGreaterThanOrEqual(plan.macros.carbsG, 0)
        XCTAssertEqual(plan.macros.carbsG, 50.0 / 4.0, accuracy: 1e-9)
    }

    func testFatFloorScalesWithBodyweight() {
        let lightPlan = TargetMacros.plan(
            expenditureKcalPerDay: 2000,
            weightKg: 60,
            leanBodyMassKg: 50,
            target: .maintain
        )
        let heavyPlan = TargetMacros.plan(
            expenditureKcalPerDay: 2500,
            weightKg: 100,
            leanBodyMassKg: 85,
            target: .maintain
        )
        XCTAssertEqual(lightPlan.macros.fatG, 36, accuracy: 1e-9)   // 0.6 * 60
        XCTAssertEqual(heavyPlan.macros.fatG, 60, accuracy: 1e-9)   // 0.6 * 100
    }
}
