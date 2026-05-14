import Foundation

/// A continuous 0–100 score describing how much usable signal the engine
/// has from the user's recent logs.
///
/// Distinct from the binary `ExpenditureStatus.holding` flag — the Holding
/// flag answers "should the engine update its estimate?"; `DataQualityScore`
/// answers "how loudly should the app nudge the user to log more?"
public struct DataQualityScore: Equatable, Sendable, Codable {

    /// Overall score in 0...100.
    public let score: Int

    /// Discrete bucket for UI ("sparse / workable / solid / dense").
    public let bucket: DataQualityBucket

    /// Distinct food-log days in the scoring window. The UI can surface
    /// copy like "logged 4 / 7 days this week" from this value.
    public let foodLogDays: Int

    /// Distinct weight-log days in the window.
    public let weightLogDays: Int

    /// Distinct body-fat-log days in the window. Body-fat data is
    /// optional; users without any still get a "solid" score when
    /// food + weight are strong.
    public let bodyFatLogDays: Int

    /// The window in days this score covers (typically 7 or 30).
    public let windowDays: Int

    public init(
        score: Int,
        bucket: DataQualityBucket,
        foodLogDays: Int,
        weightLogDays: Int,
        bodyFatLogDays: Int,
        windowDays: Int
    ) {
        self.score = score
        self.bucket = bucket
        self.foodLogDays = foodLogDays
        self.weightLogDays = weightLogDays
        self.bodyFatLogDays = bodyFatLogDays
        self.windowDays = windowDays
    }
}

// MARK: - DataQualityBucket

/// Discrete tier derived from a raw 0–100 data-quality score.
public enum DataQualityBucket: String, Codable, Sendable {
    /// 0–39: barely any data. UI surfaces a prominent nudge.
    case sparse
    /// 40–69: engine has enough to update sometimes. UI surfaces a soft hint.
    case workable
    /// 70–89: comfortable. No nudges.
    case solid
    /// 90–100: data-rich. The engine's estimates are at their tightest.
    case dense

    /// Build the bucket from a raw score. Public so callers can re-bucket
    /// after applying their own score adjustments.
    public static func from(score: Int) -> DataQualityBucket {
        switch score {
        case ..<40:
            return .sparse
        case 40..<70:
            return .workable
        case 70..<90:
            return .solid
        default:
            return .dense
        }
    }
}

// MARK: - DataQualityInputs

/// Inputs to the data-quality scorer.
///
/// Uses `Set<CalendarDay>` (day-counts only) rather than full log value
/// types because the scorer only cares about coverage, not calorie values
/// or weight readings.
public struct DataQualityInputs: Sendable {

    /// Distinct days on which a food log was recorded.
    public let foodLogDays: Set<CalendarDay>

    /// Distinct days on which a weight log was recorded.
    public let weightLogDays: Set<CalendarDay>

    /// Distinct days on which a body-fat measurement was recorded.
    public let bodyFatLogDays: Set<CalendarDay>

    /// The "today" anchor. Days strictly after this day are excluded.
    public let referenceDay: CalendarDay

    /// Length of the rolling window in days (default: 7).
    public let windowDays: Int

    public init(
        foodLogDays: Set<CalendarDay>,
        weightLogDays: Set<CalendarDay>,
        bodyFatLogDays: Set<CalendarDay>,
        referenceDay: CalendarDay,
        windowDays: Int = 7
    ) {
        self.foodLogDays = foodLogDays
        self.weightLogDays = weightLogDays
        self.bodyFatLogDays = bodyFatLogDays
        self.referenceDay = referenceDay
        self.windowDays = windowDays
    }
}

// MARK: - DataQuality

/// Computes a continuous 0–100 data-quality score from recent log coverage.
///
/// ## Component weights
/// Food logs carry 55 points (the primary energy-balance signal), weight
/// logs carry 35 points (the trend signal), and body-fat logs carry 10
/// points (an optional quality-of-life sharpener). A user logging food
/// every day and weighing 3–4 times a week with no body-fat entries lands
/// around 85 → "solid".
public enum DataQuality {

    // MARK: Component maxima

    /// Maximum points awarded for food-log coverage. Food is the primary
    /// energy-balance signal.
    public static let foodComponentMax: Int = 55

    /// Maximum points awarded for weight-log coverage.
    public static let weightComponentMax: Int = 35

    /// Maximum points awarded for body-fat-log coverage. Body-fat data is
    /// optional and does not dominate the score.
    public static let bodyFatComponentMax: Int = 10

    // MARK: Public API

    /// Compute a 0–100 `DataQualityScore` from the given inputs.
    ///
    /// Each component scales linearly up to its full credit when every day
    /// in the window has a log entry. Days strictly outside
    /// `[referenceDay − (windowDays − 1), referenceDay]` are excluded.
    ///
    /// - Parameters:
    ///   - inputs: Day-count sets and window parameters.
    ///   - calendar: Calendar used for day arithmetic. Defaults to
    ///     `.bulkAI` (Gregorian/UTC).
    /// - Returns: A fully populated `DataQualityScore`.
    public static func compute(
        _ inputs: DataQualityInputs,
        calendar: Calendar = .bulkAI
    ) -> DataQualityScore {
        let inWindow: (CalendarDay) -> Bool = { day in
            let daysAgo = inputs.referenceDay.daysSince(day, in: calendar)
            return daysAgo >= 0 && daysAgo < inputs.windowDays
        }

        let foodInWindow = inputs.foodLogDays.filter(inWindow).count
        let weightInWindow = inputs.weightLogDays.filter(inWindow).count
        let bodyFatInWindow = inputs.bodyFatLogDays.filter(inWindow).count

        // Each component scales linearly: N logged days / windowDays × componentMax.
        // Integer division is intentional — fractional points have no UI meaning.
        let foodPoints = min(foodInWindow * foodComponentMax / inputs.windowDays, foodComponentMax)
        let weightPoints = min(weightInWindow * weightComponentMax / inputs.windowDays, weightComponentMax)
        let bodyFatPoints = min(bodyFatInWindow * bodyFatComponentMax / inputs.windowDays, bodyFatComponentMax)

        let raw = foodPoints + weightPoints + bodyFatPoints
        let clamped = min(max(raw, 0), 100)

        return DataQualityScore(
            score: clamped,
            bucket: .from(score: clamped),
            foodLogDays: foodInWindow,
            weightLogDays: weightInWindow,
            bodyFatLogDays: bodyFatInWindow,
            windowDays: inputs.windowDays
        )
    }
}
