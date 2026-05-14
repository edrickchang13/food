import Foundation

// MARK: - LeanBodyMass

/// Derives or estimates lean body mass (LBM) from weight and body-fat data.
///
/// Two code paths exist:
/// - `derive`: used when the user has an actual body-fat measurement. Preferred.
/// - `estimate`: fallback when only weight is available; uses the same 0.85
///   heuristic that `TargetMacros.estimateLBM` has historically applied.
///
/// Both outputs are clamped to 20–150 kg to guard downstream macro math
/// against data-entry errors (e.g., a miskeyed 95% body fat fraction).
public enum LeanBodyMass {

    // MARK: - Bounds

    /// Lower bound of the clamped body-fat fraction (3%). Values below this
    /// are almost certainly a data-entry error or impedance-scale glitch.
    public static let minimumBodyFatFraction: Double = 0.03
    /// Upper bound of the clamped body-fat fraction (60%). Values above this
    /// are outside the physiologically plausible range for a living adult.
    public static let maximumBodyFatFraction: Double = 0.60
    /// Minimum LBM output in kg. Covers the smallest realistic adult.
    public static let minimumLBMKg: Double = 20
    /// Maximum LBM output in kg. Covers an elite heavyweight.
    public static let maximumLBMKg: Double = 150

    // MARK: - Public API

    /// Derives lean body mass from a weight and body-fat fraction pair.
    ///
    /// Formula: `LBM = weightKg × (1 − bodyFatFraction)`
    ///
    /// The body-fat fraction is clamped to [3%, 60%] before the calculation,
    /// and the result is further clamped to [20, 150] kg so a pathological
    /// input cannot produce a nonsensical value that crashes downstream macro
    /// math.
    ///
    /// - Parameters:
    ///   - weightKg: Total body weight in kilograms. Should be positive.
    ///   - bodyFatFraction: Body fat as a fraction of total weight, e.g.
    ///     0.20 for 20%. Values outside [0.03, 0.60] are clamped silently.
    /// - Returns: Lean body mass in kg, clamped to [20, 150].
    public static func derive(weightKg: Double, bodyFatFraction: Double) -> Double {
        let clampedBF = min(max(bodyFatFraction, minimumBodyFatFraction), maximumBodyFatFraction)
        let raw = weightKg * (1 - clampedBF)
        return min(max(raw, minimumLBMKg), maximumLBMKg)
    }

    /// Estimates lean body mass when no body-fat measurement is available.
    ///
    /// Uses the same heuristic `TargetMacros.estimateLBM` has applied
    /// historically: `LBM ≈ weightKg × 0.85`. The UI should still surface
    /// a "Enter body fat for a better protein target" prompt when only this
    /// code path is reachable.
    ///
    /// - Parameter weightKg: Total body weight in kilograms.
    /// - Returns: Estimated lean body mass in kg, clamped to [20, 150].
    public static func estimate(weightKg: Double) -> Double {
        let raw = weightKg * 0.85
        return min(max(raw, minimumLBMKg), maximumLBMKg)
    }
}
