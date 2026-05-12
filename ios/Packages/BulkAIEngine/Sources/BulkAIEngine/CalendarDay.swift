import Foundation

/// A calendar day in a specific calendar, independent of clock time and timezone-stable
/// for the calendar that produced it. The engine reasons about logs at day granularity,
/// so `Date` would invite off-by-one errors from DST transitions and timezone shifts.
public struct CalendarDay: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    /// Returns the start of this day (00:00) in the given calendar.
    public func startOfDay(in calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, in calendar: Calendar = .current) -> CalendarDay {
        let base = startOfDay(in: calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return CalendarDay(date: shifted, calendar: calendar)
    }

    /// Days from `other` to `self` (positive if self is later).
    public func daysSince(_ other: CalendarDay, in calendar: Calendar = .current) -> Int {
        let from = other.startOfDay(in: calendar)
        let to = self.startOfDay(in: calendar)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

extension CalendarDay: CustomStringConvertible {
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension Calendar {
    /// Gregorian / UTC calendar used by the engine. Deterministic and stable across timezones,
    /// so tests and the live app reason about days the same way regardless of the user's locale.
    public static let bulkAI: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()
}
