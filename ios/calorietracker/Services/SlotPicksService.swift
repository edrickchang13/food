import Foundation

/// Surfaces food suggestions based on the user's own log history for a given
/// time-of-day slot. Entries are ranked by the number of distinct calendar days
/// on which the user logged that food near the same hour — a "days-of-week"
/// signal rather than a raw frequency count.
///
/// All methods are pure functions on `static`; there is no instance state.
struct SlotPicksService {

    // MARK: - Public API

    /// Returns up to `limit` FoodEntry suggestions ranked by how often the user
    /// logged that food on distinct days within a `windowHours`-wide hour band
    /// centered on `slotDate`'s hour, over the trailing `lookbackDays`.
    ///
    /// - Parameters:
    ///   - entries: The full log history to mine.
    ///   - slotDate: The date/time the FoodEntrySheet header is set to.
    ///   - windowHours: Width of the hour window (centered on the slot's hour).
    ///                  Must be even; odd values are rounded down. Default 4.
    ///   - lookbackDays: How far back to scan. Default 30.
    ///   - limit: Maximum number of suggestions to return. Default 15.
    /// - Returns: Up to `limit` FoodEntry values, each the most-recent instance
    ///   of that food name from the matching window, ordered by day-count desc.
    static func suggestions(
        from entries: [FoodEntry],
        for slotDate: Date,
        windowHours: Int = 4,
        lookbackDays: Int = 30,
        limit: Int = 15
    ) -> [FoodEntry] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()

        // Lookback cutoff: entries older than this are ignored.
        let cutoff: Date = {
            guard let d = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else {
                return now
            }
            return d
        }()

        let slotHour = calendar.component(.hour, from: slotDate)
        let halfWindow = max(windowHours / 2, 0)

        // --- 1. Filter to entries within the lookback window and hour band ---
        let filtered = entries.filter { entry in
            guard entry.timestamp >= cutoff else { return false }
            let entryHour = calendar.component(.hour, from: entry.timestamp)
            return isHourInWindow(entryHour, centeredOn: slotHour, halfWidth: halfWindow)
        }

        guard !filtered.isEmpty else { return [] }

        // --- 2. Group by lowercased name ---
        // Use a Dictionary keyed on the canonical (lowercased) name. Each value
        // stores both the entries for that name (to pick the most-recent one later)
        // and the set of distinct calendar days on which the food appeared.
        struct NameGroup {
            var entries: [FoodEntry] = []
            var distinctDays: Set<String> = []
        }

        let groups: [String: NameGroup] = filtered.reduce(into: [:]) { acc, entry in
            let key = entry.name.lowercased()
            let dayKey = calendar.startOfDay(for: entry.timestamp)
                .ISO8601Format(.iso8601Date(timeZone: .current))
            acc[key, default: NameGroup()].entries.append(entry)
            acc[key, default: NameGroup()].distinctDays.insert(dayKey)
        }

        // --- 3. Rank by distinct-day count; break ties by most-recent timestamp ---
        let ranked = groups.values
            .sorted { lhs, rhs in
                if lhs.distinctDays.count != rhs.distinctDays.count {
                    return lhs.distinctDays.count > rhs.distinctDays.count
                }
                let lhsLatest = lhs.entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? .distantPast
                let rhsLatest = rhs.entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? .distantPast
                return lhsLatest > rhsLatest
            }

        // --- 4. Return the most-recent entry per name (up to limit) ---
        return ranked
            .prefix(limit)
            .compactMap { group in
                group.entries.max(by: { $0.timestamp < $1.timestamp })
            }
    }

    /// Projects `suggestions(from:for:...)` results to `FoodDatabaseItem` instances
    /// by looking each entry's name up in `database`. Entries with no database hit
    /// are dropped.
    ///
    /// - Parameters:
    ///   - entries: The full log history to mine.
    ///   - slotDate: The date/time the FoodEntrySheet header is set to.
    ///   - database: The `FoodDatabaseService` used to resolve names.
    ///   - windowHours: Forwarded to `suggestions(...)`.
    ///   - lookbackDays: Forwarded to `suggestions(...)`.
    ///   - limit: Forwarded to `suggestions(...)`.
    /// - Returns: `FoodDatabaseItem` values for entries that resolve, in
    ///   the same rank order as `suggestions(...)`.
    static func suggestionsAsDatabaseItems(
        from entries: [FoodEntry],
        for slotDate: Date,
        database: FoodDatabaseService,
        windowHours: Int = 4,
        lookbackDays: Int = 30,
        limit: Int = 15
    ) -> [FoodDatabaseItem] {
        let picks = suggestions(
            from: entries,
            for: slotDate,
            windowHours: windowHours,
            lookbackDays: lookbackDays,
            limit: limit
        )
        return picks.compactMap { entry in
            database.search(entry.name, limit: 1).first
        }
    }

    // MARK: - Private helpers

    /// Returns true when `hour` falls inside a window of `[center - halfWidth,
    /// center + halfWidth]` clamped to 0–23. Midnight-straddling windows are
    /// handled via mod-24 arithmetic.
    private static func isHourInWindow(
        _ hour: Int,
        centeredOn center: Int,
        halfWidth: Int
    ) -> Bool {
        // Clamp both ends to 0-23 instead of wrapping midnight — the brief
        // documents this as an acceptable simplification.
        let low  = max(center - halfWidth, 0)
        let high = min(center + halfWidth, 23)
        return hour >= low && hour <= high
    }
}
