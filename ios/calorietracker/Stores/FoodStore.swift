import Foundation
import SwiftUI

enum FoodLogSortOrder: String, CaseIterable, Identifiable {
    case standard
    case latestMealsFirst

    static let storageKey = "foodLogSortOrder"
    static let defaultOrder: FoodLogSortOrder = .standard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Breakfast → Lunch → Dinner"
        case .latestMealsFirst: "Latest Meals First"
        }
    }

    static func order(for rawValue: String) -> FoodLogSortOrder {
        FoodLogSortOrder(rawValue: rawValue) ?? defaultOrder
    }
}

struct FoodLogMealGroup: Identifiable {
    let id: String
    let meal: MealType
    let entries: [FoodEntry]
}

@Observable
class FoodStore {
    private(set) var entries: [FoodEntry] = []
    var onEntriesChanged: (() -> Void)?
    var onEntryAdded: ((FoodEntry) -> Void)?
    var onEntryDeleted: ((UUID) -> Void)?
    var onEntryUpdated: ((FoodEntry) -> Void)?

    /// Per-day index, populated lazily on first read and maintained
    /// incrementally by add/update/delete. Keyed by the user-calendar's
    /// startOfDay for the entry's timestamp. Avoids the O(N) full-array
    /// scan per `entries(for:date)` call — critical at 3,806 imported
    /// entries where ProgressTabView would otherwise burn ~1.4M filter
    /// comparisons per render at the 1Y range and trip the iOS watchdog.
    @ObservationIgnored private var dayIndex: [Date: [FoodEntry]]? = nil

    /// Shared start-of-day reducer.
    private func dayKey(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func rebuildDayIndex() {
        dayIndex = Dictionary(grouping: entries) { dayKey(for: $0.timestamp) }
    }

    private func dayIndexEnsured() -> [Date: [FoodEntry]] {
        if let dayIndex { return dayIndex }
        rebuildDayIndex()
        return dayIndex ?? [:]
    }

    private func indexInsert(_ entry: FoodEntry) {
        guard dayIndex != nil else { return }   // lazy: skip if never read yet
        let key = dayKey(for: entry.timestamp)
        dayIndex?[key, default: []].append(entry)
    }

    private func indexRemove(_ entry: FoodEntry) {
        guard dayIndex != nil else { return }
        let key = dayKey(for: entry.timestamp)
        dayIndex?[key]?.removeAll { $0.id == entry.id }
        if dayIndex?[key]?.isEmpty == true {
            dayIndex?.removeValue(forKey: key)
        }
    }

    private func indexReplace(old: FoodEntry, new: FoodEntry) {
        indexRemove(old)
        indexInsert(new)
    }

    private let storageKey = "foodEntries"
    private let favoritesKey = "favoriteFoodEntries"
    private(set) var favorites: [FoodEntry] = []

    init() {
        loadEntries()
        loadFavorites()
    }

    var todayEntries: [FoodEntry] {
        // Route through the O(1) day index instead of scanning the full array.
        entries(for: .now)
    }

    var todayEntriesByMeal: [FoodLogMealGroup] {
        groupedEntries(todayEntries, order: .standard)
    }

    var todayCalories: Int {
        // Use the index-keyed path so we pay one dict lookup, not a full filter.
        calories(for: .now)
    }

    var todayProtein: Int {
        protein(for: .now)
    }

    var todayCarbs: Int {
        carbs(for: .now)
    }

    var todayFat: Int {
        fat(for: .now)
    }

    // MARK: - Date-parameterized queries

    func entries(for date: Date) -> [FoodEntry] {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    func entriesByMeal(for date: Date, order: FoodLogSortOrder = .standard) -> [FoodLogMealGroup] {
        let dayEntries = entries(for: date)
        return groupedEntries(dayEntries, order: order)
    }

    private func groupedEntries(_ dayEntries: [FoodEntry], order: FoodLogSortOrder) -> [FoodLogMealGroup] {
        switch order {
        case .standard:
            return MealType.allCases.compactMap { meal in
                let mealEntries = dayEntries.filter { $0.mealType == meal }
                guard !mealEntries.isEmpty else { return nil }
                return FoodLogMealGroup(id: "standard-\(meal.rawValue)", meal: meal, entries: mealEntries)
            }
        case .latestMealsFirst:
            return latestMealRuns(dayEntries)
        }
    }

    private func latestMealRuns(_ dayEntries: [FoodEntry]) -> [FoodLogMealGroup] {
        var groups: [FoodLogMealGroup] = []
        var currentMeal: MealType?
        var currentEntries: [FoodEntry] = []

        func appendCurrentGroup() {
            guard let meal = currentMeal, !currentEntries.isEmpty else { return }
            let firstEntryID = currentEntries.first?.id.uuidString ?? UUID().uuidString
            groups.append(FoodLogMealGroup(
                id: "latest-\(groups.count)-\(meal.rawValue)-\(firstEntryID)",
                meal: meal,
                entries: currentEntries
            ))
        }

        for entry in dayEntries {
            if entry.mealType == currentMeal {
                currentEntries.append(entry)
            } else {
                appendCurrentGroup()
                currentMeal = entry.mealType
                currentEntries = [entry]
            }
        }

        appendCurrentGroup()
        return groups
    }

    func calories(for date: Date) -> Int {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + $1.calories }
    }

    func protein(for date: Date) -> Int {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + $1.protein }
    }

    func carbs(for date: Date) -> Int {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + $1.carbs }
    }

    func fat(for date: Date) -> Int {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + $1.fat }
    }

    // MARK: - Micronutrient aggregation

    func sugar(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.sugar ?? 0) }
    }

    func addedSugar(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.addedSugar ?? 0) }
    }

    func fiber(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.fiber ?? 0) }
    }

    func saturatedFat(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.saturatedFat ?? 0) }
    }

    func monounsaturatedFat(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.monounsaturatedFat ?? 0) }
    }

    func polyunsaturatedFat(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.polyunsaturatedFat ?? 0) }
    }

    func cholesterol(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.cholesterol ?? 0) }
    }

    func sodium(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.sodium ?? 0) }
    }

    func potassium(for date: Date) -> Double {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).reduce(0) { $0 + ($1.potassium ?? 0) }
    }

    // MARK: - Recents / Frequent

    func recentEntries(limit: Int = 50) -> [FoodEntry] {
        Array(entries.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func frequentGroups() -> [FrequentFoodGroup] {
        var aggregates: [String: (count: Int, template: FoodEntry)] = [:]
        for entry in entries {
            let key = "\(entry.name.lowercased())|\(entry.calories)"
            if let current = aggregates[key] {
                let newCount = current.count + 1
                let template = entry.timestamp > current.template.timestamp ? entry : current.template
                aggregates[key] = (newCount, template)
            } else {
                aggregates[key] = (1, entry)
            }
        }
        return aggregates.map { _, pair in
            FrequentFoodGroup(template: pair.template, count: pair.count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Favorites

    func isFavorite(_ entry: FoodEntry) -> Bool {
        favorites.contains { $0.favoriteKey == entry.favoriteKey }
    }

    func toggleFavorite(_ entry: FoodEntry) {
        if let index = favorites.firstIndex(where: { $0.favoriteKey == entry.favoriteKey }) {
            favorites.remove(at: index)
        } else {
            // Remove any existing entry with same id to prevent duplicates
            favorites.removeAll { $0.id == entry.id }
            // Make sure the favorite has its own on-disk JPEG before persisting.
            // Without this, favoriting an entry that hasn't been through
            // addEntry() yet (e.g. straight from the Food Result review screen)
            // would persist with imageData = bytes-in-memory-only — and since
            // FoodEntry.encode drops raw bytes by design, the favorite would
            // come back image-less on the next launch.
            var favorite = entry
            offloadImageToDiskIfNeeded(&favorite)
            favorites.append(favorite)
        }
        saveFavorites()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return }
        favorites = decoded
    }

    // MARK: - CRUD

    func addEntry(_ entry: FoodEntry) {
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)
        entries.append(entry)
        indexInsert(entry)
        saveEntries()
        onEntriesChanged?()
        onEntryAdded?(entry)
    }

    /// Bulk-append many entries with a single save at the end. Used by the
    /// MacroFactor CSV importer — calling `addEntry` 3,806 times would do
    /// 3,806 JSON encodes + UserDefaults writes, which freezes the UI for
    /// several seconds. This version pays the encode/write cost once.
    func addEntries(_ newEntries: [FoodEntry]) {
        guard !newEntries.isEmpty else { return }
        entries.append(contentsOf: newEntries)
        // Rebuild rather than N inserts; faster at thousands of entries.
        if dayIndex != nil { rebuildDayIndex() }
        saveEntries()
        onEntriesChanged?()
        // Skip onEntryAdded callbacks for bulk; engine refreshes once via
        // onEntriesChanged anyway.
    }

    func updateEntry(_ entry: FoodEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let old = entries[index]
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)
        entries[index] = entry
        indexReplace(old: old, new: entry)
        saveEntries()
        onEntriesChanged?()
        // Single callback so HealthKit can serialize delete-then-write atomically.
        onEntryUpdated?(entry)
    }

    func deleteEntry(_ entry: FoodEntry) {
        let id = entry.id
        // Skip the disk-delete when a favorite (or another entry) still
        // references this filename. Without this guard, favoriting a meal,
        // deleting the log entry, and relaunching wipes the favorite's image
        // because both rows share the same fudai-image-<uuid>.jpg.
        if let filename = entry.imageFilename, !isImageStillReferenced(filename: filename, excludingEntryID: id) {
            FoodImageStore.shared.delete(filename: filename)
        }
        entries.removeAll { $0.id == id }
        indexRemove(entry)
        saveEntries()
        onEntriesChanged?()
        onEntryDeleted?(id)
    }

    func replaceAllEntries(_ newEntries: [FoodEntry]) {
        // Delete on-disk JPEGs for any entry that's about to be removed —
        // otherwise Clear Food Log / Delete All Data orphan files in
        // Application Support forever. Skip files that a favorite or a
        // surviving entry still references (same filename, different id).
        let surviving = Set(newEntries.map(\.id))
        let survivingFilenames = Set(newEntries.compactMap(\.imageFilename))
        let favoriteFilenames = Set(favorites.compactMap(\.imageFilename))
        for old in entries where !surviving.contains(old.id) {
            guard let filename = old.imageFilename else { continue }
            if survivingFilenames.contains(filename) || favoriteFilenames.contains(filename) { continue }
            FoodImageStore.shared.delete(filename: filename)
        }
        entries = newEntries.map { var e = $0; offloadImageToDiskIfNeeded(&e); return e }
        saveEntries()
        onEntriesChanged?()
    }

    func mergeWithCloudEntries(_ cloudEntries: [FoodEntry]) {
        var merged = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for cloudEntry in cloudEntries {
            merged[cloudEntry.id] = cloudEntry
        }
        entries = Array(merged.values)
        saveEntries()
        onEntriesChanged?()
    }

    /// If `entry` carries in-memory `imageData` but no `imageFilename`, write
    /// the bytes to disk and stamp the filename onto the entry. No-op when
    /// there are no bytes, or when a filename is already set (idempotent).
    /// The 4 MiB UserDefaults cap demands we never persist raw bytes.
    private func offloadImageToDiskIfNeeded(_ entry: inout FoodEntry) {
        guard entry.imageFilename == nil, let data = entry.imageData else { return }
        if let filename = FoodImageStore.shared.store(data: data, for: entry.id) {
            entry.imageFilename = filename
        }
    }

    /// Used by deleteEntry / replaceAllEntries to decide whether the on-disk
    /// JPEG can safely be removed. A filename can be shared by a logged entry
    /// + a favorite (same `id`, same generated `fudai-image-<uuid>.jpg`), or
    /// by two logged entries that came from the same favorite re-log.
    private func isImageStillReferenced(filename: String, excludingEntryID: UUID) -> Bool {
        if entries.contains(where: { $0.id != excludingEntryID && $0.imageFilename == filename }) {
            return true
        }
        return favorites.contains { $0.imageFilename == filename }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return }
        entries = decoded
        // Invalidate any stale per-day cache; first reader rebuilds lazily.
        dayIndex = nil

        // Legacy migration: rows written by pre-FoodImageStore builds embedded
        // JPEG bytes in the JSON blob. Offload any such rows to disk, stamp
        // the filename, and rewrite the UserDefaults blob — shrinking it from
        // multi-MB to ~a few KB so the 4 MiB cap stops silently swallowing
        // adds/deletes. Idempotent: runs only on entries that need it.
        var migrated = false
        for i in entries.indices {
            if entries[i].imageFilename == nil, let data = entries[i].imageData {
                if let filename = FoodImageStore.shared.store(data: data, for: entries[i].id) {
                    entries[i].imageFilename = filename
                    migrated = true
                }
            }
        }
        if migrated {
            saveEntries()
        }
    }
}

struct FrequentFoodGroup: Identifiable {
    let id: String
    let name: String
    let calories: Int
    let count: Int
    let template: FoodEntry

    init(template: FoodEntry, count: Int) {
        self.id = "\(template.name.lowercased())|\(template.calories)"
        self.name = template.name
        self.calories = template.calories
        self.count = count
        self.template = template
    }
}
