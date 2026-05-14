import Foundation

public struct DailyIntake: Equatable, Hashable, Codable, Sendable {
    public let day: CalendarDay
    public let kcal: Double

    public init(day: CalendarDay, kcal: Double) {
        self.day = day
        self.kcal = kcal
    }
}

public enum ExpenditureConfidence: String, Codable, Sendable {
    /// Below logging thresholds; the prior estimate is returned unchanged.
    case low
    /// Thresholds met but data is sparse.
    case medium
    /// Window is well-populated.
    case high
}

public struct ExpenditureEstimate: Equatable, Codable, Sendable {
    public let kcalPerDay: Double
    public let confidence: ExpenditureConfidence
    public let windowDays: Int
    public let foodLogDays: Int
    public let weightLogDays: Int
    public let priorKcalPerDay: Double
    /// Whether a guardrail clamp was applied (±15% adjustment cap or BMR floor/ceiling).
    public let clampApplied: Bool

    public init(
        kcalPerDay: Double,
        confidence: ExpenditureConfidence,
        windowDays: Int,
        foodLogDays: Int,
        weightLogDays: Int,
        priorKcalPerDay: Double,
        clampApplied: Bool
    ) {
        self.kcalPerDay = kcalPerDay
        self.confidence = confidence
        self.windowDays = windowDays
        self.foodLogDays = foodLogDays
        self.weightLogDays = weightLogDays
        self.priorKcalPerDay = priorKcalPerDay
        self.clampApplied = clampApplied
    }
}

public enum Expenditure {
    /// Energy equivalent of body mass: ~7700 kcal per kg of body weight change.
    public static let kcalPerKg: Double = 7700
    /// Required by spec: Holding-state evaluation window is exactly 7 days.
    public static let defaultWindowDays: Int = 7
    /// Required by spec: fewer than 3 days of nutrition data triggers Holding state.
    public static let minFoodLogs: Int = 3
    /// Required by spec: fewer than 1 day of weight data triggers Holding state.
    public static let minWeightLogs: Int = 1
    public static let highConfidenceFoodLogs: Int = 10
    public static let highConfidenceWeightLogs: Int = 7
    public static let maxWeeklyAdjustmentRatio: Double = 0.15
    public static let bmrFloorMultiplier: Double = 1.1
    public static let bmrCeilingMultiplier: Double = 2.5

    /// Estimates current TDEE using the energy-balance equation:
    /// `expenditure = avgIntake - (trendChangeKg * kcalPerKg) / windowDays`.
    ///
    /// Below logging thresholds the prior estimate is returned with `.low` confidence.
    /// Guardrails: result is clamped to ±15% of prior and into [1.1×BMR, 2.5×BMR].
    public static func estimate(
        intakeLogs: [DailyIntake],
        trend: [TrendPoint],
        priorKcalPerDay: Double,
        bmrKcalPerDay: Double,
        windowDays: Int = defaultWindowDays,
        referenceDay: CalendarDay,
        calendar: Calendar = .bulkAI
    ) -> ExpenditureEstimate {
        precondition(windowDays > 1, "windowDays must be > 1")
        precondition(bmrKcalPerDay > 0, "bmrKcalPerDay must be positive")

        let windowStart = referenceDay.adding(days: -(windowDays - 1), in: calendar)

        let intakeInWindow = intakeLogs.filter { $0.day >= windowStart && $0.day <= referenceDay }
        let trendInWindow = trend.filter { $0.day >= windowStart && $0.day <= referenceDay }
            .sorted { $0.day < $1.day }

        // Count unique days for both signals (defensive against duplicate logs per day).
        let foodLogDays = Set(intakeInWindow.map { $0.day }).count
        let weightLogDays = Set(trendInWindow.filter { !$0.isInterpolated }.map { $0.day }).count

        let belowThreshold = foodLogDays < minFoodLogs || weightLogDays < minWeightLogs
        let trendHasEndpoints = trendInWindow.count >= 2

        guard !belowThreshold, trendHasEndpoints else {
            return ExpenditureEstimate(
                kcalPerDay: priorKcalPerDay,
                confidence: .low,
                windowDays: windowDays,
                foodLogDays: foodLogDays,
                weightLogDays: weightLogDays,
                priorKcalPerDay: priorKcalPerDay,
                clampApplied: false
            )
        }

        let avgIntakeByDay = intakeInWindow.reduce(into: [CalendarDay: Double]()) { acc, log in
            // If multiple intake logs land on one day, sum them (multiple meals).
            acc[log.day, default: 0] += log.kcal
        }
        let avgIntake = avgIntakeByDay.values.reduce(0, +) / Double(foodLogDays)

        // Use trend values bracketing the window. If the window doesn't have a value on day 0,
        // use the earliest trend point inside the window — and account for the actual span.
        let firstTrend = trendInWindow.first!
        let lastTrend = trendInWindow.last!
        let trendSpanDays = max(1, lastTrend.day.daysSince(firstTrend.day, in: calendar))
        let trendChangeKg = lastTrend.kg - firstTrend.kg

        // Note: divide by the trend's actual span, not the nominal window, so partial-window
        // data doesn't bias the per-day energy. The intake average is already per logged day.
        let rawExpenditure = avgIntake - (trendChangeKg * kcalPerKg) / Double(trendSpanDays)

        let clampedToPrior = clampToAdjustmentLimit(rawExpenditure, prior: priorKcalPerDay)
        let clampedToBmr = clampToBmrBounds(clampedToPrior, bmr: bmrKcalPerDay)
        let clampApplied = clampedToBmr != rawExpenditure

        let confidence: ExpenditureConfidence =
            (foodLogDays >= highConfidenceFoodLogs && weightLogDays >= highConfidenceWeightLogs)
            ? .high : .medium

        return ExpenditureEstimate(
            kcalPerDay: clampedToBmr,
            confidence: confidence,
            windowDays: windowDays,
            foodLogDays: foodLogDays,
            weightLogDays: weightLogDays,
            priorKcalPerDay: priorKcalPerDay,
            clampApplied: clampApplied
        )
    }

    private static func clampToAdjustmentLimit(_ value: Double, prior: Double) -> Double {
        let lower = prior * (1 - maxWeeklyAdjustmentRatio)
        let upper = prior * (1 + maxWeeklyAdjustmentRatio)
        return min(max(value, lower), upper)
    }

    private static func clampToBmrBounds(_ value: Double, bmr: Double) -> Double {
        let floor = bmr * bmrFloorMultiplier
        let ceiling = bmr * bmrCeilingMultiplier
        return min(max(value, floor), ceiling)
    }
}

/// Mifflin-St Jeor BMR formula. Used both for onboarding seeds and as the floor/ceiling anchor.
public enum BMR {
    public enum BiologicalSex: String, Codable, Sendable, CaseIterable {
        case male, female
    }

    /// Returns kcal/day.
    public static func mifflinStJeor(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        sex: BiologicalSex
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        return sex == .male ? base + 5 : base - 161
    }
}

