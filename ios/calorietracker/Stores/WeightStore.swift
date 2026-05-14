import Foundation
import SwiftData
import SwiftUI

// MARK: - Model ↔ Value-type converters (file-private)

private extension WeightEntryModel {
    convenience init(from entry: WeightEntry) {
        self.init(id: entry.id, date: entry.date, weightKg: entry.weightKg)
    }
}

private extension WeightEntry {
    init(from model: WeightEntryModel) {
        self.init(id: model.id, date: model.date, weightKg: model.weightKg)
    }
}

// MARK: - WeightStore

/// Persistent store for the user's weight history.
///
/// Backend: SwiftData (`WeightEntryModel` via `BulkAISchemaV1`). Migrated
/// from the legacy `"weightEntries"` UserDefaults blob on first launch by
/// `SwiftDataMigration.runIfNeeded(into:)`.
///
/// Public API is byte-for-byte identical to the prior UserDefaults
/// implementation so all callers — views, `EngineState`, `HealthKitManager` —
/// need zero changes.
@Observable
@MainActor
final class WeightStore {

    // MARK: - Public API

    private(set) var entries: [WeightEntry] = []

    var onEntryAdded:   ((WeightEntry) -> Void)?
    var onEntryDeleted: ((UUID) -> Void)?

    // MARK: - Private state

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // MARK: - Init

    init(container: ModelContainer = SwiftDataContainer.makeContainer()) {
        self.container = container
        if !SwiftDataMigration.hasMigrated {
            _ = SwiftDataMigration.runIfNeeded(into: container)
        }
        rebuild()
    }

    // MARK: - Derived

    var latestEntry: WeightEntry? {
        entries.sorted { $0.date > $1.date }.first
    }

    func entries(in range: ClosedRange<Date>) -> [WeightEntry] {
        entries
            .filter { range.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Mutations

    /// Add the first WeightEntry from the user's onboarding-set profile weight.
    /// Safe to call multiple times — no-op if any entries already exist, so subsequent
    /// scene-active firings or re-onboarding paths can't duplicate.
    func seedInitialWeightFromProfileIfEmpty(_ weightKg: Double) {
        guard entries.isEmpty else { return }
        addEntry(WeightEntry(date: .now, weightKg: weightKg))
    }

    func addEntry(_ entry: WeightEntry) {
        let previousLatest = entries.sorted { $0.date > $1.date }.first
        let model = WeightEntryModel(from: entry)
        context.insert(model)
        try? context.save()
        rebuild()
        onEntryAdded?(entry)

        syncProfileWeightToLatest()

        // Detect goal-weight crossing — fire only on the transition, not on every weight past goal.
        if let profile = UserProfile.load(), let goalKg = profile.goalWeightKg, let previous = previousLatest {
            let crossed: Bool
            switch profile.goal {
            case .lose:     crossed = previous.weightKg > goalKg && entry.weightKg <= goalKg
            case .gain:     crossed = previous.weightKg < goalKg && entry.weightKg >= goalKg
            case .maintain: crossed = false
            }
            if crossed {
                NotificationCenter.default.post(name: .weightGoalReached, object: nil)
            }
        }
    }

    func deleteEntry(_ entry: WeightEntry) {
        let id = entry.id
        let descriptor = FetchDescriptor<WeightEntryModel>(predicate: #Predicate { $0.id == id })
        if let model = try? context.fetch(descriptor).first {
            context.delete(model)
            try? context.save()
            rebuild()
            onEntryDeleted?(id)
            syncProfileWeightToLatest()
        }
    }

    func replaceAllEntries(_ newEntries: [WeightEntry]) {
        let existing = (try? context.fetch(FetchDescriptor<WeightEntryModel>())) ?? []
        existing.forEach { context.delete($0) }
        newEntries.forEach { context.insert(WeightEntryModel(from: $0)) }
        try? context.save()
        rebuild()
    }

    /// Bulk-import weight samples discovered from HealthKit (e.g. years of
    /// scale history that predate Fud AI). Bypasses onEntryAdded so the
    /// imported externals don't echo back to HK as fresh writes — these
    /// samples already exist there. Saves + syncs profile once at the end.
    func importExternalEntries(_ external: [WeightEntry]) {
        guard !external.isEmpty else { return }
        external.forEach { context.insert(WeightEntryModel(from: $0)) }
        try? context.save()
        rebuild()
        syncProfileWeightToLatest()
    }

    func mergeWithCloudEntries(_ cloudEntries: [WeightEntry]) {
        var merged = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for cloudEntry in cloudEntries {
            merged[cloudEntry.id] = cloudEntry
        }
        replaceAllEntries(Array(merged.values))
    }

    // MARK: - Private helpers

    private func rebuild() {
        let models = (try? context.fetch(FetchDescriptor<WeightEntryModel>())) ?? []
        entries = models.map { WeightEntry(from: $0) }
    }

    /// Keep UserProfile.weightKg aligned with the most recent weight entry so
    /// Settings (Weight row) and Progress (Current badge) never disagree. If the
    /// store is empty, leave the profile as-is — we still need some weightKg for
    /// BMR/TDEE math; user can log a new one.
    private func syncProfileWeightToLatest() {
        guard var profile = UserProfile.load(),
              let newest = entries.sorted(by: { $0.date > $1.date }).first else { return }
        if abs(profile.weightKg - newest.weightKg) > 0.01 {
            profile.weightKg = newest.weightKg
            profile.save()
        }
    }
}
