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
