import Foundation
import SwiftUI
import SwiftData

// MARK: - FoodLogSortOrder

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

// MARK: - FoodLogMealGroup

struct FoodLogMealGroup: Identifiable {
    let id: String
    let meal: MealType
    let entries: [FoodEntry]
}

// MARK: - FoodStore

/// Observable store for food log entries. Backed by SwiftData (`FoodEntryModel`
/// via `ModelContainer.mainContext`). Favorites remain in UserDefaults JSON.
/// Public API matches the legacy UserDefaults version — callers are unaffected
/// by the backend change. A `[Date: [FoodEntry]]` day-index keeps per-day
/// queries at O(1) for large imports.
@MainActor
@Observable
class FoodStore {

    // MARK: - Public API

    private(set) var entries: [FoodEntry] = []
    var onEntriesChanged: (() -> Void)?
    var onEntryAdded: ((FoodEntry) -> Void)?
    var onEntryDeleted: ((UUID) -> Void)?
    var onEntryUpdated: ((FoodEntry) -> Void)?

    // MARK: - Favorites (remain in UserDefaults)

    private let favoritesKey = "favoriteFoodEntries"
    private(set) var favorites: [FoodEntry] = []

    // MARK: - SwiftData

    @ObservationIgnored private let container: ModelContainer

    private var context: ModelContext { container.mainContext }

    // MARK: - Day-index

    /// Lazily built, incrementally maintained; keyed by startOfDay.
    @ObservationIgnored private var dayIndex: [Date: [FoodEntry]]? = nil

    // MARK: - Init

    /// Creates a store backed by `container`. The migration guard is idempotent.
    init(container: ModelContainer = SwiftDataContainer.makeContainer()) {
        self.container = container
        if !SwiftDataMigration.hasMigrated {
            _ = SwiftDataMigration.runIfNeeded(into: container)
        }
        loadEntries()
        loadFavorites()
    }

    // MARK: - Today aggregations

    var todayEntries: [FoodEntry] { entries(for: .now) }
    var todayEntriesByMeal: [FoodLogMealGroup] { groupedEntries(todayEntries, order: .standard) }
    var todayCalories: Int { calories(for: .now) }
    var todayProtein: Int { protein(for: .now) }
    var todayCarbs: Int { carbs(for: .now) }
    var todayFat: Int { fat(for: .now) }

    // MARK: - Date-parameterized queries

    func entries(for date: Date) -> [FoodEntry] {
        let key = dayKey(for: date)
        return (dayIndexEnsured()[key] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    func entriesByMeal(for date: Date, order: FoodLogSortOrder = .standard) -> [FoodLogMealGroup] {
        let dayEntries = entries(for: date)
        return groupedEntries(dayEntries, order: order)
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
            favorites.removeAll { $0.id == entry.id }
            // Ensure on-disk JPEG exists before persisting; in-memory bytes aren't encoded.
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

    // MARK: - CRUD

    func addEntry(_ entry: FoodEntry) {
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)
        let model = makeModel(from: entry)
        context.insert(model)
        persistContext()
        entries.append(entry)
        indexInsert(entry)
        onEntriesChanged?()
        onEntryAdded?(entry)
    }

    /// Bulk-append many entries with a single SwiftData save. Skips per-entry
    /// callbacks; engine refreshes once via `onEntriesChanged`.
    func addEntries(_ newEntries: [FoodEntry]) {
        guard !newEntries.isEmpty else { return }
        for var entry in newEntries {
            offloadImageToDiskIfNeeded(&entry)
            context.insert(makeModel(from: entry))
        }
        persistContext()
        loadEntries()
        onEntriesChanged?()
    }

    func updateEntry(_ entry: FoodEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let old = entries[index]
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)

        // Update the SwiftData model in place.
        if let model = fetchModel(id: entry.id) {
            applyEntry(entry, to: model)
        } else {
            context.insert(makeModel(from: entry))
        }
        persistContext()

        entries[index] = entry
        indexReplace(old: old, new: entry)
        onEntriesChanged?()
        // Single callback so HealthKit can serialize delete-then-write atomically.
        onEntryUpdated?(entry)
    }

    func deleteEntry(_ entry: FoodEntry) {
        let id = entry.id
        // Skip disk-delete when another entry or favorite still references this file.
        if let filename = entry.imageFilename,
           !isImageStillReferenced(filename: filename, excludingEntryID: id) {
            FoodImageStore.shared.delete(filename: filename)
        }

        if let model = fetchModel(id: id) {
            context.delete(model)
            persistContext()
        }

        entries.removeAll { $0.id == id }
        indexRemove(entry)
        onEntriesChanged?()
        onEntryDeleted?(id)
    }

    func replaceAllEntries(_ newEntries: [FoodEntry]) {
        // Delete orphaned JPEGs; skip files still referenced by survivors or favorites.
        let surviving = Set(newEntries.map(\.id))
        let survivingFilenames = Set(newEntries.compactMap(\.imageFilename))
        let favoriteFilenames = Set(favorites.compactMap(\.imageFilename))
        for old in entries where !surviving.contains(old.id) {
            guard let filename = old.imageFilename else { continue }
            if survivingFilenames.contains(filename) || favoriteFilenames.contains(filename) { continue }
            FoodImageStore.shared.delete(filename: filename)
        }

        let descriptor = FetchDescriptor<FoodEntryModel>()
        if let existing = try? context.fetch(descriptor) {
            for model in existing { context.delete(model) }
        }

        var prepared: [FoodEntry] = []
        for var e in newEntries {
            offloadImageToDiskIfNeeded(&e)
            context.insert(makeModel(from: e))
            prepared.append(e)
        }
        persistContext()

        entries = prepared
        dayIndex = nil
        onEntriesChanged?()
    }

    func mergeWithCloudEntries(_ cloudEntries: [FoodEntry]) {
        var merged = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for cloudEntry in cloudEntries {
            merged[cloudEntry.id] = cloudEntry
        }
        let mergedEntries = Array(merged.values)

        // Upsert each merged entry into SwiftData.
        for entry in mergedEntries {
            if let model = fetchModel(id: entry.id) {
                applyEntry(entry, to: model)
            } else {
                context.insert(makeModel(from: entry))
            }
        }
        persistContext()

        entries = mergedEntries
        dayIndex = nil
        onEntriesChanged?()
    }

    // MARK: - Private: SwiftData I/O

    /// Fetches all rows from SwiftData and rebuilds `entries` + day-index.
    private func loadEntries() {
        let descriptor = FetchDescriptor<FoodEntryModel>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        guard let models = try? context.fetch(descriptor) else { return }
        entries = models.map(makeEntry(from:))
        // Day-index is invalidated; first reader rebuilds it lazily.
        dayIndex = nil
    }

    /// Saves the context; logs in DEBUG on failure instead of crashing.
    private func persistContext() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("[FoodStore] SwiftData save failed: \(error)")
            #endif
        }
    }

    /// Fetch the `FoodEntryModel` for a given UUID, or nil if not found.
    private func fetchModel(id: UUID) -> FoodEntryModel? {
        var descriptor = FetchDescriptor<FoodEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Maps a `FoodEntry` to a new `FoodEntryModel`; stores filename, not bytes.
    private func makeModel(from entry: FoodEntry) -> FoodEntryModel {
        FoodEntryModel(
            id: entry.id,
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            timestamp: entry.timestamp,
            imageFilename: entry.imageFilename,
            emoji: entry.emoji,
            sourceRaw: entry.source.rawValue,
            mealTypeRaw: entry.mealType.rawValue,
            sugar: entry.sugar,
            addedSugar: entry.addedSugar,
            fiber: entry.fiber,
            saturatedFat: entry.saturatedFat,
            monounsaturatedFat: entry.monounsaturatedFat,
            polyunsaturatedFat: entry.polyunsaturatedFat,
            cholesterol: entry.cholesterol,
            sodium: entry.sodium,
            potassium: entry.potassium,
            servingSizeGrams: entry.servingSizeGrams,
            servingUnitOptionsJSON: encodeServingUnits(entry.servingUnitOptions),
            selectedServingUnit: entry.selectedServingUnit,
            selectedServingQuantity: entry.selectedServingQuantity
        )
    }

    /// Mutates an existing model in place; avoids delete+insert churn.
    private func applyEntry(_ entry: FoodEntry, to model: FoodEntryModel) {
        model.name = entry.name
        model.calories = entry.calories
        model.protein = entry.protein
        model.carbs = entry.carbs
        model.fat = entry.fat
        model.timestamp = entry.timestamp
        model.imageFilename = entry.imageFilename
        model.emoji = entry.emoji
        model.sourceRaw = entry.source.rawValue
        model.mealTypeRaw = entry.mealType.rawValue
        model.sugar = entry.sugar
        model.addedSugar = entry.addedSugar
        model.fiber = entry.fiber
        model.saturatedFat = entry.saturatedFat
        model.monounsaturatedFat = entry.monounsaturatedFat
        model.polyunsaturatedFat = entry.polyunsaturatedFat
        model.cholesterol = entry.cholesterol
        model.sodium = entry.sodium
        model.potassium = entry.potassium
        model.servingSizeGrams = entry.servingSizeGrams
        model.servingUnitOptionsJSON = encodeServingUnits(entry.servingUnitOptions)
        model.selectedServingUnit = entry.selectedServingUnit
        model.selectedServingQuantity = entry.selectedServingQuantity
    }

    /// Maps a `FoodEntryModel` to a `FoodEntry`; loads image bytes from sidecar.
    private func makeEntry(from model: FoodEntryModel) -> FoodEntry {
        let imageData = model.imageFilename.flatMap { FoodImageStore.shared.load(filename: $0) }
        return FoodEntry(
            id: model.id,
            name: model.name,
            calories: model.calories,
            protein: model.protein,
            carbs: model.carbs,
            fat: model.fat,
            timestamp: model.timestamp,
            imageData: imageData,
            imageFilename: model.imageFilename,
            emoji: model.emoji,
            source: model.source,
            mealType: model.mealType,
            sugar: model.sugar,
            addedSugar: model.addedSugar,
            fiber: model.fiber,
            saturatedFat: model.saturatedFat,
            monounsaturatedFat: model.monounsaturatedFat,
            polyunsaturatedFat: model.polyunsaturatedFat,
            cholesterol: model.cholesterol,
            sodium: model.sodium,
            potassium: model.potassium,
            servingSizeGrams: model.servingSizeGrams,
            servingUnitOptions: model.servingUnitOptions,
            selectedServingUnit: model.selectedServingUnit,
            selectedServingQuantity: model.selectedServingQuantity
        )
    }

    /// JSON-encodes serving unit options; returns nil when empty.
    private func encodeServingUnits(_ options: [ServingUnitOption]) -> String? {
        guard !options.isEmpty,
              let data = try? JSONEncoder().encode(options)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private: Favorites persistence (UserDefaults)

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

    // MARK: - Private: Image sidecar

    /// Writes in-memory image bytes to disk and stamps the filename. No-op if already on disk.
    private func offloadImageToDiskIfNeeded(_ entry: inout FoodEntry) {
        guard entry.imageFilename == nil, let data = entry.imageData else { return }
        if let filename = FoodImageStore.shared.store(data: data, for: entry.id) {
            entry.imageFilename = filename
        }
    }

    /// Returns `true` when another entry or a favorite still references `filename`.
    private func isImageStillReferenced(filename: String, excludingEntryID: UUID) -> Bool {
        entries.contains(where: { $0.id != excludingEntryID && $0.imageFilename == filename })
            || favorites.contains { $0.imageFilename == filename }
    }

    // MARK: - Private: Day-index helpers

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

    // MARK: - Meal grouping helpers

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
}

// MARK: - FrequentFoodGroup

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
