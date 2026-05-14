import Foundation

/// Macro distribution preference. Mirrors `ProgramPreference` in the UI
/// layer but stays UI-free so the engine package doesn't import SwiftUI.
/// The main app's wizard maps `ProgramPreference -> DietPreference` at
/// the seam before calling into the distributor.
public enum DietPreference: String, Codable, Sendable, CaseIterable {
    /// 30% protein / 25% fat / 45% carbs, the existing TargetMacros
    /// default. Honors protein + fat floors.
    case balanced
    /// Fat capped at 20% of total kcal. Carbs absorb the surplus. Useful
    /// for users on a heart-health or older-style restriction.
    case lowFat
    /// Carbs capped at 25% of total kcal. Fat absorbs the surplus. The
    /// "low-carb but not keto" middle ground.
    case lowCarb
    /// Carbs capped at 10% of total kcal (≈ 50-100 g/day depending on
    /// target). Fat absorbs the surplus. Strict keto.
    case keto
}

/// The reshaped macro targets after applying a `DietPreference`.
public struct DistributedMacros: Equatable, Codable, Sendable {
    public let kcalTarget: Double
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    public let preference: DietPreference
    /// `true` when the preference's cap would have pushed fat or carbs
    /// below 5% of kcal. The distributor clamps to 5% instead and sets
    /// this flag so UI can surface "extreme distribution — review".
    public let clampApplied: Bool

    public init(
        kcalTarget: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        preference: DietPreference,
        clampApplied: Bool
    ) {
        self.kcalTarget = kcalTarget
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.preference = preference
        self.clampApplied = clampApplied
    }

    /// Convenience: macro-derived kcal. Should equal `kcalTarget` within rounding.
    public var macroKcal: Double {
        proteinG * 4 + fatG * 9 + carbsG * 4
    }
}

// MARK: - MacroDistributor

/// Reshapes `DailyPlan` macros according to a `DietPreference`.
///
/// Protein is treated as a hard floor and is never modified — it is
/// derived from lean body mass by `TargetMacros` and must be preserved.
/// Fat and carbs absorb the redistribution between themselves.
///
/// A 5% floor (of total kcal) is applied to both fat and carbs to guard
/// against degenerate inputs (e.g. very high protein floors that shrink
/// the fat+carb budget to near zero). When the floor fires, `clampApplied`
/// is set on the returned `DistributedMacros`.
public enum MacroDistributor {

    // MARK: - Constants

    /// Minimum share of total kcal for either fat or carbs after redistribution.
    private static let minFloorFraction: Double = 0.05

    // MARK: - Public API

    /// Reshape `base` macros according to `preference`.
    ///
    /// Protein is untouched — it is a hard floor set by `TargetMacros`.
    /// Fat and carbs absorb the constraint.
    ///
    /// - Parameters:
    ///   - base: macros computed by `TargetMacros.plan(...)`. The kcal
    ///     target and protein grams are preserved exactly.
    ///   - preference: how to redistribute the remaining kcal between
    ///     fat and carbs.
    /// - Returns: reshaped macros. `macroKcal` equals `kcalTarget` to
    ///   within floating-point rounding.
    public static func distribute(
        base: DailyPlan,
        preference: DietPreference
    ) -> DistributedMacros {
        let kcal = base.kcalTarget
        let proteinG = base.macros.proteinG
        let proteinKcal = proteinG * 4
        let remainingKcal = max(0, kcal - proteinKcal)

        // Per-preference split of the remaining (non-protein) kcal between
        // fat and carbs. Values are fractions of remainingKcal, not of total.
        let (fatPct, carbsPct): (Double, Double) = {
            switch preference {
            case .balanced: return (0.30, 0.70)
            case .lowFat:   return (0.20, 0.80)
            case .lowCarb:  return (0.75, 0.25)
            case .keto:     return (0.90, 0.10)
            }
        }()

        let fatFloorKcal   = kcal * minFloorFraction
        let carbsFloorKcal = kcal * minFloorFraction

        var fatKcal   = remainingKcal * fatPct
        var carbsKcal = remainingKcal * carbsPct
        var clampApplied = false

        if fatKcal < fatFloorKcal {
            let deficit = fatFloorKcal - fatKcal
            fatKcal   = fatFloorKcal
            carbsKcal = max(0, carbsKcal - deficit)
            clampApplied = true
        }

        if carbsKcal < carbsFloorKcal {
            let deficit = carbsFloorKcal - carbsKcal
            carbsKcal = carbsFloorKcal
            fatKcal   = max(0, fatKcal - deficit)
            clampApplied = true
        }

        return DistributedMacros(
            kcalTarget: kcal,
            proteinG: proteinG,
            fatG: fatKcal / 9,
            carbsG: carbsKcal / 4,
            preference: preference,
            clampApplied: clampApplied
        )
    }
}
