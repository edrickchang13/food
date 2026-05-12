import Foundation

/// One menstrual cycle. PRD notes that period tracking helps the user contextualize
/// short-term spikes in trend weight from water retention.
struct PeriodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    /// First day of bleeding.
    var startDate: Date
    /// Last day of bleeding. Nil while the cycle is still in progress.
    var endDate: Date?
    var notes: String?

    init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil, notes: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    /// Days from start to end (inclusive). Nil if the cycle is still in progress.
    var periodLengthDays: Int? {
        guard let end = endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0
        return days + 1
    }

    /// Convenience for grid rendering: every day from start to end (or start if no end).
    func days(in calendar: Calendar = .current) -> [Date] {
        let end = endDate ?? startDate
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: end)
        while cursor <= lastDay {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
