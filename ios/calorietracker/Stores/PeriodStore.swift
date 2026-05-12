import Foundation
import SwiftUI

@Observable
final class PeriodStore {
    private(set) var entries: [PeriodEntry] = []
    private let storageKey = "periodEntries"

    init() {
        load()
    }

    var sortedNewestFirst: [PeriodEntry] {
        entries.sorted { $0.startDate > $1.startDate }
    }

    /// Whether the most recent cycle has no end date set — i.e. user is currently on their period.
    var hasOpenCycle: Bool {
        sortedNewestFirst.first?.endDate == nil && !entries.isEmpty
    }

    /// Average cycle length (start-to-start) over the most recent N closed cycles.
    func averageCycleLengthDays(over count: Int = 6) -> Int? {
        let starts = sortedNewestFirst.map { $0.startDate }
        guard starts.count >= 2 else { return nil }
        let pairs = zip(starts.dropLast(), starts.dropFirst())
        let lengths = pairs.compactMap { newer, older -> Int? in
            Calendar.current.dateComponents([.day], from: older, to: newer).day
        }
        let sample = Array(lengths.prefix(count))
        guard !sample.isEmpty else { return nil }
        return sample.reduce(0, +) / sample.count
    }

    func add(_ entry: PeriodEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: PeriodEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        save()
    }

    func delete(_ entry: PeriodEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PeriodEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
