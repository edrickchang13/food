import Foundation

public enum Goal: String, Codable, Sendable, CaseIterable {
    case lose
    case maintain
    case gain
}

public struct WeeklyTarget: Equatable, Codable, Sendable {
    public let goal: Goal
    /// Rate as a fraction of bodyweight per week. e.g. 0.005 = 0.5%/week.
    public let weeklyRateAsFractionOfBodyweight: Double

    public init(goal: Goal, weeklyRateAsFractionOfBodyweight: Double) {
        self.goal = goal
        self.weeklyRateAsFractionOfBodyweight = weeklyRateAsFractionOfBodyweight
    }

    public static let maintain = WeeklyTarget(goal: .maintain, weeklyRateAsFractionOfBodyweight: 0)
}

public struct MacroTargets: Equatable, Codable, Sendable {
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double

    public var totalKcal: Double {
        proteinG * 4 + fatG * 9 + carbsG * 4
    }
}

public struct DailyPlan: Equatable, Codable, Sendable {
    public let kcalTarget: Double
    public let macros: MacroTargets
    /// True if the protein+fat floor forced the kcal target up from the user's chosen rate.
    public let floorApplied: Bool

    public init(kcalTarget: Double, macros: MacroTargets, floorApplied: Bool) {
        self.kcalTarget = kcalTarget
        self.macros = macros
        self.floorApplied = floorApplied
    }
}

public enum TargetMacros {
    /// Protein per kg of lean body mass, by goal.
    public static let proteinGPerKgLBM_loseOrMaintain: Double = 2.0
    public static let proteinGPerKgLBM_gain: Double = 1.8
    /// Fat floor as a fraction of bodyweight in kg.
    public static let fatFloorGPerKgBodyweight: Double = 0.6
    /// Minimum carb budget in kcal after protein + fat floors are honored.
    public static let minimumCarbBudgetKcal: Double = 50

    /// Computes the day's calorie + macro target.
    ///
    /// Sequence:
    /// 1. Apply the user's chosen rate of change to derive a raw kcal target from expenditure.
    /// 2. Compute protein from LBM (or estimated LBM) and fat from bodyweight.
    /// 3. If protein+fat+minimum-carbs exceeds the raw target, raise the target to honor the floors
    ///    (the engine never silently shaves protein or fat). `floorApplied = true` in that case.
    /// 4. Carbs fill the remainder.
    public static func plan(
        expenditureKcalPerDay: Double,
        weightKg: Double,
        leanBodyMassKg: Double?,
        target: WeeklyTarget
    ) -> DailyPlan {
        precondition(weightKg > 0, "weightKg must be positive")

        let lbm = leanBodyMassKg ?? estimateLBM(weightKg: weightKg)
        let proteinG = proteinTarget(leanBodyMassKg: lbm, goal: target.goal)
        let fatG = fatFloorGPerKgBodyweight * weightKg

        let proteinKcal = proteinG * 4
        let fatKcal = fatG * 9
        let floorKcal = proteinKcal + fatKcal + minimumCarbBudgetKcal

        let rawTarget = rawCalorieTarget(
            expenditure: expenditureKcalPerDay,
            weightKg: weightKg,
            target: target
        )

        let floorApplied = rawTarget < floorKcal
        let kcalTarget = max(rawTarget, floorKcal)
        let carbsKcal = max(0, kcalTarget - proteinKcal - fatKcal)
        let carbsG = carbsKcal / 4

        return DailyPlan(
            kcalTarget: kcalTarget,
            macros: MacroTargets(proteinG: proteinG, fatG: fatG, carbsG: carbsG),
            floorApplied: floorApplied
        )
    }

    /// Raw target before macro floors are enforced. Exposed for diagnostics.
    public static func rawCalorieTarget(
        expenditure: Double,
        weightKg: Double,
        target: WeeklyTarget
    ) -> Double {
        let weeklyDeltaKcal = weightKg * target.weeklyRateAsFractionOfBodyweight * Expenditure.kcalPerKg
        let dailyAdjustment = weeklyDeltaKcal / 7
        switch target.goal {
        case .lose: return expenditure - dailyAdjustment
        case .gain: return expenditure + dailyAdjustment
        case .maintain: return expenditure
        }
    }

    public static func proteinTarget(leanBodyMassKg: Double, goal: Goal) -> Double {
        switch goal {
        case .lose, .maintain: return proteinGPerKgLBM_loseOrMaintain * leanBodyMassKg
        case .gain: return proteinGPerKgLBM_gain * leanBodyMassKg
        }
    }

    /// Rough LBM estimate when body fat % isn't logged. Conservative defaults; the engine
    /// will refine itself as the user logs body fat or other measurements.
    public static func estimateLBM(weightKg: Double, activeAdjustment: Bool = false) -> Double {
        let leanFraction = activeAdjustment ? 0.90 : 0.85
        return weightKg * leanFraction
    }
}
