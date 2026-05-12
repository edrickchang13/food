import Foundation
import SwiftUI

@Observable
final class MeasurementStore {
    private(set) var entries: [BodyMeasurementEntry] = []
    private let storageKey = "bodyMeasurementEntries"

    init() {
        load()
    }

    func entries(for site: BodyMeasurementSite) -> [BodyMeasurementEntry] {
        entries
            .filter { $0.site == site }
            .sorted { $0.date > $1.date }
    }

    func latest(for site: BodyMeasurementSite) -> BodyMeasurementEntry? {
        entries(for: site).first
    }

    func add(_ entry: BodyMeasurementEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: BodyMeasurementEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        save()
    }

    func delete(_ entry: BodyMeasurementEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BodyMeasurementEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
