import XCTest
@testable import BulkAIEngine

final class LeanBodyMassTests: XCTestCase {

    // MARK: - 1. Standard derive

    func testDerive_standardInput_correctLBM() {
        // 80 kg × (1 − 0.20) = 64 kg
        let lbm = LeanBodyMass.derive(weightKg: 80, bodyFatFraction: 0.20)
        XCTAssertEqual(lbm, 64.0, accuracy: 1e-9)
    }

    // MARK: - 2. Clamps high BF (above 60%)

    func testDerive_veryHighBodyFat_clampedTo60Percent() {
        // BF 0.95 → clamped to 0.60 → LBM = 80 × 0.40 = 32 kg
        let lbm = LeanBodyMass.derive(weightKg: 80, bodyFatFraction: 0.95)
        XCTAssertEqual(lbm, 32.0, accuracy: 1e-9)
    }

    // MARK: - 3. Clamps low BF (below 3%)

    func testDerive_veryLowBodyFat_clampedTo3Percent() {
        // BF 0.01 → clamped to 0.03 → LBM = 80 × 0.97 = 77.6 kg
        let lbm = LeanBodyMass.derive(weightKg: 80, bodyFatFraction: 0.01)
        XCTAssertEqual(lbm, 77.6, accuracy: 1e-9)
    }

    // MARK: - 4. Estimate fallback (no BF measurement)

    func testEstimate_standardWeight_uses85PercentHeuristic() {
        // 80 × 0.85 = 68 kg
        let lbm = LeanBodyMass.estimate(weightKg: 80)
        XCTAssertEqual(lbm, 68.0, accuracy: 1e-9)
    }

    // MARK: - Additional bound guards

    func testDerive_resultClampedToMinimumLBM() {
        // Very low weight with maximum clamped BF: 25 × 0.40 = 10 kg → clamped to 20 kg
        let lbm = LeanBodyMass.derive(weightKg: 25, bodyFatFraction: 0.60)
        XCTAssertEqual(lbm, LeanBodyMass.minimumLBMKg, accuracy: 1e-9)
    }

    func testDerive_resultClampedToMaximumLBM() {
        // Implausibly large weight at minimum BF: 200 × 0.97 = 194 kg → clamped to 150 kg
        let lbm = LeanBodyMass.derive(weightKg: 200, bodyFatFraction: 0.03)
        XCTAssertEqual(lbm, LeanBodyMass.maximumLBMKg, accuracy: 1e-9)
    }

    func testEstimate_lowWeight_clampedToMinimumLBM() {
        // 20 × 0.85 = 17 kg → clamped to 20 kg
        let lbm = LeanBodyMass.estimate(weightKg: 20)
        XCTAssertEqual(lbm, LeanBodyMass.minimumLBMKg, accuracy: 1e-9)
    }
}
