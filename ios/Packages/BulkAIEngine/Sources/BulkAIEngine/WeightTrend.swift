import Foundation

public struct WeightLog: Equatable, Hashable, Codable, Sendable {
    public let day: CalendarDay
    public let kg: Double

    public init(day: CalendarDay, kg: Double) {
        self.day = day
        self.kg = kg
    }
}

public struct TrendPoint: Equatable, Hashable, Codable, Sendable {
    public let day: CalendarDay
    /// Smoothed (EWMA) trend value in kg.
    public let kg: Double
    /// Raw weight value used as input for this day, or `nil` if interpolated.
    public let rawKg: Double?
    /// Whether the raw value was synthesized via linear interpolation.
    public var isInterpolated: Bool { rawKg == nil }

    public init(day: CalendarDay, kg: Double, rawKg: Double?) {
        self.day = day
        self.kg = kg
        self.rawKg = rawKg
    }
}

public enum WeightTrend {
    /// EWMA smoothing factor. Default 0.1 ≈ 10-day half-life. Higher = more responsive, less smooth.
    public static let defaultAlpha: Double = 0.1

    /// Computes a smoothed trend series from raw weight logs.
    ///
    /// - Multiple logs on the same day are averaged.
    /// - Missing days within the [earliest, latest] span are linearly interpolated.
    /// - Days outside the span are not extrapolated.
    /// - The first day's trend is seeded to its raw value (no warm-up bias).
    public static func compute(
        logs: [WeightLog],
        alpha: Double = defaultAlpha,
        calendar: Calendar = .bulkAI
    ) -> [TrendPoint] {
        precondition(alpha > 0 && alpha <= 1, "alpha must be in (0, 1]")
        guard !logs.isEmpty else { return [] }

        let perDayMean = groupedByDayMean(logs)
        let sortedDays = perDayMean.keys.sorted()
        guard let first = sortedDays.first, let last = sortedDays.last else { return [] }

        var output: [TrendPoint] = []
        output.reserveCapacity(max(1, last.daysSince(first, in: calendar) + 1))

        var previousTrend = perDayMean[first]!
        var cursor = first
        output.append(TrendPoint(day: cursor, kg: previousTrend, rawKg: perDayMean[first]))

        while cursor < last {
            cursor = cursor.adding(days: 1, in: calendar)
            let raw: Double
            let rawForOutput: Double?
            if let logged = perDayMean[cursor] {
                raw = logged
                rawForOutput = logged
            } else {
                raw = interpolate(at: cursor, between: perDayMean, sortedDays: sortedDays, calendar: calendar)
                rawForOutput = nil
            }
            let trend = alpha * raw + (1 - alpha) * previousTrend
            output.append(TrendPoint(day: cursor, kg: trend, rawKg: rawForOutput))
            previousTrend = trend
        }
        return output
    }

    /// Returns the most recent trend kg, or nil if no logs.
    public static func currentTrend(_ trend: [TrendPoint]) -> Double? {
        trend.last?.kg
    }

    // MARK: - Private helpers

    private static func groupedByDayMean(_ logs: [WeightLog]) -> [CalendarDay: Double] {
        var sums: [CalendarDay: Double] = [:]
        var counts: [CalendarDay: Int] = [:]
        for log in logs {
            sums[log.day, default: 0] += log.kg
            counts[log.day, default: 0] += 1
        }
        var result: [CalendarDay: Double] = [:]
        for (day, sum) in sums {
            result[day] = sum / Double(counts[day] ?? 1)
        }
        return result
    }

    private static func interpolate(
        at target: CalendarDay,
        between values: [CalendarDay: Double],
        sortedDays: [CalendarDay],
        calendar: Calendar
    ) -> Double {
        var lower: CalendarDay = sortedDays.first!
        var upper: CalendarDay = sortedDays.last!
        for day in sortedDays {
            if day <= target { lower = day }
            if day >= target { upper = day; break }
        }
        if lower == upper { return values[lower]! }
        let span = upper.daysSince(lower, in: calendar)
        guard span > 0 else { return values[lower]! }
        let position = target.daysSince(lower, in: calendar)
        let lowVal = values[lower]!
        let highVal = values[upper]!
        let fraction = Double(position) / Double(span)
        return lowVal + (highVal - lowVal) * fraction
    }
}

// MARK: - WeightTrendSlope

/// The result of a least-squares linear regression over a smoothed weight trend series.
///
/// Use `WeightTrend.slope(trend:minPoints:)` to derive this from a `[TrendPoint]` array.
/// The slope is expressed in kg per week so callers don't need to reason about per-day
/// denominators. `rSquared` and `standardError` feed directly into P23-B's confidence
/// interval calculations.
public struct WeightTrendSlope: Equatable, Sendable, Codable {
    /// Slope in kg per week. Positive = trending up, negative = trending down.
    public let kgPerWeek: Double
    /// Coefficient of determination (R²) — how well the linear fit explains
    /// the smoothed series. 0 = no relationship, 1 = perfect line. UI can
    /// use this to badge "high confidence" vs "noisy trend".
    public let rSquared: Double
    /// Standard error of the slope estimate, in kg/week. Used by P23-B
    /// (Projection) to build confidence intervals around the projected end date.
    public let standardError: Double
    /// Number of trend points used in the fit.
    public let sampleSize: Int

    public init(kgPerWeek: Double, rSquared: Double, standardError: Double, sampleSize: Int) {
        self.kgPerWeek = kgPerWeek
        self.rSquared = rSquared
        self.standardError = standardError
        self.sampleSize = sampleSize
    }
}

// MARK: - Slope derivation

extension WeightTrend {
    /// Computes the linear regression slope over the smoothed trend via ordinary
    /// least squares (OLS).
    ///
    /// The x axis is integer day indices (0, 1, 2, …) so the fit is independent of
    /// any calendar details. The resulting slope is scaled from per-day to per-week
    /// before it is stored in `WeightTrendSlope.kgPerWeek`.
    ///
    /// Returns `nil` when fewer than `minPoints` trend points are available; the
    /// caller is expected to surface a "not enough data" state in that case.
    ///
    /// - Parameters:
    ///   - trend: Smoothed trend series produced by `WeightTrend.compute(logs:)`.
    ///   - minPoints: Minimum number of points required to attempt a fit. Defaults
    ///     to 7 (one week of daily smoothing). Must be ≥ 3 because residual variance
    ///     divides by `n - 2`.
    /// - Returns: A `WeightTrendSlope` on success, `nil` when there is insufficient data.
    public static func slope(
        trend: [TrendPoint],
        minPoints: Int = 7
    ) -> WeightTrendSlope? {
        let n = trend.count
        guard n >= max(minPoints, 3) else { return nil }

        let xs = trend.indices.map { Double($0) }
        let ys = trend.map(\.kg)

        let xMean = xs.reduce(0.0, +) / Double(n)
        let yMean = ys.reduce(0.0, +) / Double(n)

        let ssxy = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let ssxx = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }

        guard ssxx > 0 else { return nil }

        let slopePerDay = ssxy / ssxx
        let intercept = yMean - slopePerDay * xMean

        let residuals = zip(xs, ys).map { $1 - (intercept + slopePerDay * $0) }
        let sse = residuals.reduce(0.0) { $0 + $1 * $1 }
        let sst = ys.reduce(0.0) { $0 + ($1 - yMean) * ($1 - yMean) }

        let rSquared = sst > 0 ? max(0.0, 1.0 - sse / sst) : 0.0
        let residualVariance = sse / Double(n - 2)
        let standardErrorPerDay = (residualVariance / ssxx).squareRoot()

        return WeightTrendSlope(
            kgPerWeek: slopePerDay * 7,
            rSquared: rSquared,
            standardError: standardErrorPerDay * 7,
            sampleSize: n
        )
    }
}
