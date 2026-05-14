import Foundation

// MARK: - ProjectionStatus

/// Status of a goal-weight projection. Mirrors the Holding-state pattern
/// from Expenditure — when the math can't honestly answer, say so
/// instead of returning a misleading number.
public enum ProjectionStatus: String, Codable, Sendable {
    /// Projection is meaningful: trend is moving toward the goal with
    /// enough signal to estimate when the user crosses the line.
    case projected
    /// User is already at or past their goal weight. No projection needed.
    case goalReached
    /// Trend slope is too flat to project (within `GoalProjection.flatSlopeThresholdKgPerWeek`).
    /// Caller should surface "your trend is flat — no projection".
    case stalled
    /// Trend slope sign disagrees with the goal direction. User is gaining
    /// while trying to lose, or vice versa. Caller should surface this
    /// honestly rather than show a date thousands of days away.
    case trendingAway
    /// Not enough trend data for `WeightTrend.slope(...)` to return non-nil.
    case insufficientData
}

// MARK: - Projection

/// The result of a goal-weight projection computation.
///
/// When `status == .projected` all date and week fields are populated.
/// For every other status only `reason` is meaningful; all other fields are `nil`
/// except `projectedDate` on `.goalReached` (set to today).
public struct Projection: Equatable, Codable, Sendable {
    /// The outcome of the projection computation.
    public let status: ProjectionStatus

    /// Projected date the user hits `goalWeightKg`. `nil` for every status
    /// except `.projected` and `.goalReached` (where `projectedDate == today`).
    public let projectedDate: Date?

    /// Weeks remaining until the projected date. `nil` outside `.projected`.
    public let weeksToGoal: Double?

    /// Lower bound on the projected date (95% CI using `slope.standardError`).
    /// Closer-in-time than `projectedDate`. `nil` outside `.projected`.
    public let confidenceLowerDate: Date?

    /// Upper bound on the projected date. Farther-out than `projectedDate`.
    /// `nil` outside `.projected`.
    public let confidenceUpperDate: Date?

    /// Short human-readable reason, mainly for the non-projected statuses.
    public let reason: String?

    public init(
        status: ProjectionStatus,
        projectedDate: Date? = nil,
        weeksToGoal: Double? = nil,
        confidenceLowerDate: Date? = nil,
        confidenceUpperDate: Date? = nil,
        reason: String? = nil
    ) {
        self.status = status
        self.projectedDate = projectedDate
        self.weeksToGoal = weeksToGoal
        self.confidenceLowerDate = confidenceLowerDate
        self.confidenceUpperDate = confidenceUpperDate
        self.reason = reason
    }
}

// MARK: - GoalProjection

/// Stateless projection engine. Given a current trend weight, a goal weight,
/// and a regression slope, computes the date the user is projected to cross
/// their goal line — or explains why no honest projection is possible.
public enum GoalProjection {
    /// Slopes below this magnitude (kg/week) are treated as `.stalled`.
    /// Roughly 0.05 kg/week, which is well within trend-noise on most
    /// people's scales.
    public static let flatSlopeThresholdKgPerWeek: Double = 0.05

    /// Within ±100 g of goal weight the user is considered to have reached it.
    private static let goalReachedThresholdKg: Double = 0.1

    /// Z-score for a 95% confidence interval.
    private static let z: Double = 1.96

    /// Minimum safe slope magnitude used when computing CI bounds, so that
    /// a near-zero CI bound (from a wide standard error) doesn't flip sign
    /// and produce a nonsense date.
    private static let safeFloor: Double = flatSlopeThresholdKgPerWeek * 0.5

    /// Projects the date the user reaches `goalWeightKg`.
    ///
    /// - Parameters:
    ///   - currentWeightKg: Today's smoothed trend weight (use `trend.last?.kg`).
    ///   - goalWeightKg: Target weight from the user's profile.
    ///   - slope: Regression result from `WeightTrend.slope(trend:minPoints:)`.
    ///     Pass `nil` when insufficient data is available.
    ///   - today: Reference date for all date arithmetic. Defaults to `Date()`;
    ///     injectable for deterministic tests.
    ///   - calendar: Calendar used for date offset arithmetic. Defaults to
    ///     `.current`; injectable for deterministic tests.
    /// - Returns: A `Projection` whose `status` describes the outcome and whose
    ///   date fields are populated only when a meaningful estimate is possible.
    public static func project(
        currentWeightKg: Double,
        goalWeightKg: Double,
        slope: WeightTrendSlope?,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Projection {
        guard let slope else {
            return Projection(
                status: .insufficientData,
                reason: "Need more weight logs to project a date"
            )
        }

        let deltaKg = goalWeightKg - currentWeightKg

        if abs(deltaKg) <= goalReachedThresholdKg {
            return Projection(
                status: .goalReached,
                projectedDate: today,
                reason: "You're at your goal weight"
            )
        }

        if abs(slope.kgPerWeek) <= flatSlopeThresholdKgPerWeek {
            return Projection(
                status: .stalled,
                reason: "Trend is flat — no projection"
            )
        }

        // Sign check: trending toward or away?
        let signsAgree = (deltaKg > 0 && slope.kgPerWeek > 0) ||
                         (deltaKg < 0 && slope.kgPerWeek < 0)
        guard signsAgree else {
            let direction = deltaKg > 0 ? "gain" : "lose"
            return Projection(
                status: .trendingAway,
                reason: "Trying to \(direction) but trending the other way"
            )
        }

        // Both signs match, so weeksToGoal is positive.
        let weeksToGoal = deltaKg / slope.kgPerWeek
        let projectedDays = weeksToGoal * 7
        let projectedDate = calendar.date(
            byAdding: .second,
            value: Int(projectedDays * 86_400),
            to: today
        ) ?? today

        // 95% CI bounds: ± 1.96 × standardError on slope.
        // A faster slope yields a closer (lower) date;
        // a slower slope yields a farther (upper) date.
        let slopeLower = slope.kgPerWeek - z * slope.standardError
        let slopeUpper = slope.kgPerWeek + z * slope.standardError

        // Clamp each bound so it stays on the correct side of zero,
        // preventing a sign flip from producing a nonsense past date.
        let slopeLowerSafe: Double
        let slopeUpperSafe: Double
        if slope.kgPerWeek > 0 {
            slopeLowerSafe = max(slopeLower, safeFloor)
            slopeUpperSafe = max(slopeUpper, safeFloor)
        } else {
            slopeLowerSafe = min(slopeLower, -safeFloor)
            slopeUpperSafe = min(slopeUpper, -safeFloor)
        }

        // Faster slope (larger absolute value) → fewer weeks → closer date (lowerBound).
        // Slower slope (smaller absolute value) → more weeks → farther date (upperBound).
        let fasterSlope = abs(slopeLowerSafe) >= abs(slopeUpperSafe) ? slopeLowerSafe : slopeUpperSafe
        let slowerSlope = abs(slopeLowerSafe) < abs(slopeUpperSafe) ? slopeLowerSafe : slopeUpperSafe

        let weeksFast = deltaKg / fasterSlope
        let weeksSlow = deltaKg / slowerSlope

        let lowerBound = calendar.date(
            byAdding: .second,
            value: Int(weeksFast * 7 * 86_400),
            to: today
        ) ?? projectedDate
        let upperBound = calendar.date(
            byAdding: .second,
            value: Int(weeksSlow * 7 * 86_400),
            to: today
        ) ?? projectedDate

        return Projection(
            status: .projected,
            projectedDate: projectedDate,
            weeksToGoal: weeksToGoal,
            confidenceLowerDate: lowerBound,
            confidenceUpperDate: upperBound
        )
    }
}
