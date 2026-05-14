import Foundation

// MARK: - BodyFatLog

/// A single body-fat measurement. Mirrors `WeightLog` in shape so
/// the EWMA smoother can be parameterized identically.
public struct BodyFatLog: Equatable, Codable, Sendable {
    public let day: CalendarDay
    /// Body-fat fraction, in [0, 1]. 0.20 == 20% body fat.
    public let bodyFatFraction: Double

    public init(day: CalendarDay, bodyFatFraction: Double) {
        self.day = day
        self.bodyFatFraction = bodyFatFraction
    }
}

// MARK: - BodyFatTrendPoint

/// Smoothed body-fat reading. `isInterpolated == true` means there was no
/// measurement on `day`; the value was carried forward via EWMA from the
/// prior real reading. Callers can dim or hide interpolated values in charts.
public struct BodyFatTrendPoint: Equatable, Codable, Sendable {
    public let day: CalendarDay
    /// Smoothed body-fat fraction in [0, 1].
    public let bodyFatFraction: Double
    /// `true` when no `BodyFatLog` existed for this day and the value is
    /// a pure carry-forward from the previous real reading.
    public let isInterpolated: Bool

    public init(day: CalendarDay, bodyFatFraction: Double, isInterpolated: Bool) {
        self.day = day
        self.bodyFatFraction = bodyFatFraction
        self.isInterpolated = isInterpolated
    }
}

// MARK: - BodyFatTrend

/// EWMA smoother for sparse body-fat measurement series.
///
/// Body-fat readings are meaningfully sparser than weight logs — most people
/// measure weekly at most. The smoother uses a high α (0.5) on real readings
/// to quickly incorporate new data and a very low α (0.05) on gap days so a
/// multi-week measurement gap does not flat-line the curve.
public enum BodyFatTrend {
    /// EWMA alpha applied on days that have a real `BodyFatLog`. Higher value
    /// makes the trend more responsive to a new reading.
    public static let alphaReal: Double = 0.5
    /// EWMA alpha applied on days with no reading — pure carry-forward at
    /// negligible decay to preserve the last known value across long gaps.
    public static let alphaInterpolated: Double = 0.05

    /// Computes a smoothed body-fat trend series from sparse raw logs.
    ///
    /// - Days with a real log: smoothed = α × reading + (1 − α) × previousSmoothed.
    /// - Gap days: value is carried forward unchanged (effectively α = 0 so no
    ///   artificial pull toward any target).
    /// - The first day's smoothed value is seeded to the first reading with no
    ///   warm-up bias.
    /// - Logs may arrive in any order; the function sorts them internally.
    ///
    /// - Parameters:
    ///   - logs: Raw body-fat measurements. May be unsorted. Duplicate days are
    ///     averaged before smoothing.
    ///   - today: If provided and greater than the last log day, the output is
    ///     extended to `today` using interpolated carry-forward points.
    ///   - calendar: Defaults to `.bulkAI` (Gregorian/UTC) for deterministic
    ///     day arithmetic.
    /// - Returns: One `BodyFatTrendPoint` per calendar day from the first log
    ///   day through `today ?? last log day`. Returns `[]` when `logs` is empty.
    public static func compute(
        logs: [BodyFatLog],
        today: CalendarDay? = nil,
        calendar: Calendar = .bulkAI
    ) -> [BodyFatTrendPoint] {
        guard !logs.isEmpty else { return [] }

        let perDayMean = groupedByDayMean(logs)
        let sortedDays = perDayMean.keys.sorted()

        guard let firstDay = sortedDays.first, let lastLogDay = sortedDays.last else {
            return []
        }

        let lastDay: CalendarDay
        if let today, today > lastLogDay {
            lastDay = today
        } else {
            lastDay = lastLogDay
        }

        let capacity = max(1, lastDay.daysSince(firstDay, in: calendar) + 1)
        var output: [BodyFatTrendPoint] = []
        output.reserveCapacity(capacity)

        var previousSmoothed = perDayMean[firstDay]!
        output.append(BodyFatTrendPoint(
            day: firstDay,
            bodyFatFraction: previousSmoothed,
            isInterpolated: false
        ))

        var cursor = firstDay
        while cursor < lastDay {
            cursor = cursor.adding(days: 1, in: calendar)
            if let reading = perDayMean[cursor] {
                let smoothed = alphaReal * reading + (1 - alphaReal) * previousSmoothed
                output.append(BodyFatTrendPoint(
                    day: cursor,
                    bodyFatFraction: smoothed,
                    isInterpolated: false
                ))
                previousSmoothed = smoothed
            } else {
                // Pure carry-forward — no pull toward any anchor during gaps.
                output.append(BodyFatTrendPoint(
                    day: cursor,
                    bodyFatFraction: previousSmoothed,
                    isInterpolated: true
                ))
                // previousSmoothed unchanged; gap days do not move the trend.
            }
        }

        return output
    }

    // MARK: - Private helpers

    private static func groupedByDayMean(_ logs: [BodyFatLog]) -> [CalendarDay: Double] {
        var sums: [CalendarDay: Double] = [:]
        var counts: [CalendarDay: Int] = [:]
        for log in logs {
            sums[log.day, default: 0] += log.bodyFatFraction
            counts[log.day, default: 0] += 1
        }
        var result: [CalendarDay: Double] = [:]
        for (day, sum) in sums {
            result[day] = sum / Double(counts[day] ?? 1)
        }
        return result
    }
}
