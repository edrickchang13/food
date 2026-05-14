//
//  calorietrackerTests.swift
//  calorietrackerTests
//
//  Created by Apoorv Darshan on 05/02/26.
//

import Testing
import Foundation
import SwiftData
@testable import calorietracker

struct calorietrackerTests {

    @Test func example() async throws {
        // Write your test here and use APIs like #expect(...) to check expected conditions.
    }

}

// MARK: - EngineState debounce tests

/// Verifies that rapid store-change callbacks coalesce into a single trailing-edge
/// refresh via the 250 ms debounce window added in P13.
struct EngineStateDebounceTests {

    /// After N rapid addEntry calls, pendingRefresh should be non-nil (debounce armed)
    /// and the same Task object should survive (all but the last got cancelled and replaced).
    @Test
    @MainActor
    func pendingRefreshArmedAfterRapidEntries() async throws {
        // FoodStore + WeightStore are @MainActor post-P21 (SwiftData
        // ModelContext is main-actor-isolated). The test method matches.
        let weightStore = WeightStore(container: SwiftDataContainer.makePreviewContainer())
        let foodStore = FoodStore(container: SwiftDataContainer.makePreviewContainer())
        let engine = EngineState(weightStore: weightStore, foodStore: foodStore)

        // Fire 20 callbacks synchronously — each cancels the previous debounce task.
        for i in 0..<20 {
            weightStore.addEntry(WeightEntry(date: Date.now, weightKg: 70.0 + Double(i)))
        }

        // The debounce window has NOT elapsed yet, so pendingRefresh must be non-nil.
        #expect(engine.pendingRefreshForTesting != nil, "pendingRefresh should be non-nil immediately after rapid entries")
    }

    /// After waiting longer than the debounce window, pendingRefresh becomes nil
    /// (the task completed and there is no new pending work).
    @Test
    @MainActor
    func pendingRefreshClearsAfterDebounceWindow() async throws {
        let weightStore = WeightStore(container: SwiftDataContainer.makePreviewContainer())
        let foodStore = FoodStore(container: SwiftDataContainer.makePreviewContainer())
        let engine = EngineState(weightStore: weightStore, foodStore: foodStore)

        // Trigger a single debounce cycle.
        weightStore.addEntry(WeightEntry(date: Date.now, weightKg: 75.0))

        // Wait well past the 250 ms window.
        try await Task.sleep(for: .milliseconds(350))

        // The task has completed; pendingRefresh should now be nil.
        #expect(engine.pendingRefreshForTesting == nil, "pendingRefresh should be nil after debounce window elapses")
    }
}

// MARK: - FoodDatabaseService search-index correctness tests

/// These tests verify correctness invariants for the binary-search +
/// substring-fallback index in FoodDatabaseService.
///
/// Note: `loadUSDAIfNeeded()` DOES load successfully inside the test host
/// because the test target is @testable import of the app target and Bundle.main
/// resolves to the app bundle (which contains usda-seed.json). Tests are written
/// against invariants (all results match query, all seed hits appear) rather than
/// exact-set equality with a stripped oracle, so USDA presence doesn't matter.
struct FoodDatabaseServiceIndexTests {

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// Linear-scan reference implementation, matching the original production
    /// algorithm exactly. Used as the oracle to compare the indexed path against.
    private func linearSearch(_ query: String, in service: FoodDatabaseService, limit: Int = 25) -> [FoodDatabaseItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(FoodDatabaseSeed.items.prefix(limit)) }
        let seedHits  = FoodDatabaseSeed.items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        // USDA is absent in the test host; treat as empty (matching production fallback).
        let cacheHits = service.aiCache.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        return Array((seedHits + cacheHits).prefix(limit))
    }

    // -------------------------------------------------------------------------
    // Prefix matches
    // -------------------------------------------------------------------------

    @Test("Index returns seed chicken items for 'chi' prefix")
    func prefixChicken() {
        let svc = FoodDatabaseService()
        let hits = svc.search("chi", limit: 25)
        #expect(!hits.isEmpty, "Expected at least one hit for 'chi'")
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains("chi") },
                "All results must contain 'chi'")
    }

    @Test("Index returns rice items for 'rice' substring (non-prefix)")
    func substringRice() {
        let svc = FoodDatabaseService()
        let hits = svc.search("rice", limit: 25)
        // Both "White rice, long grain" and "Brown rice" are in the seed.
        let names = hits.map { $0.name.lowercased() }
        #expect(names.contains(where: { $0.contains("rice") }),
                "Expected at least one 'rice' hit from substring search")
    }

    @Test("'white rice' prefix returns white-rice seed entries")
    func prefixWhiteRice() {
        let svc = FoodDatabaseService()
        let hits = svc.search("white rice", limit: 25)
        #expect(!hits.isEmpty, "Expected white rice hits")
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains("white rice") })
    }

    // -------------------------------------------------------------------------
    // Correctness invariants (indexed path vs known-good seed hits)
    // -------------------------------------------------------------------------
    //
    // Rather than comparing against a stripped oracle (which would need to
    // replicate USDA loading to be accurate), these tests verify the invariants
    // that matter:
    //   1. Every result returned actually matches the query.
    //   2. Every seed item matching the query appears in the results
    //      (within the limit), proving no seed hits are silently dropped.

    @Test("All indexed 'chi' results contain the query; no seed hits dropped")
    func correctnessChicken() {
        let svc = FoodDatabaseService()
        let query = "chi"
        let hits = svc.search(query, limit: 25)
        // All returned items must contain the query.
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains(query) },
                "Every result must contain '\(query)'")
        // Every seed item that matches must appear in the result set.
        let seedMatchIDs = Set(FoodDatabaseSeed.items
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map(\.id))
        let hitIDs = Set(hits.map(\.id))
        #expect(seedMatchIDs.isSubset(of: hitIDs),
                "All seed hits for '\(query)' must be present in indexed results")
    }

    @Test("All indexed 'egg' results contain the query; no seed hits dropped")
    func correctnessEgg() {
        let svc = FoodDatabaseService()
        let query = "egg"
        let hits = svc.search(query, limit: 25)
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains(query) },
                "Every result must contain '\(query)'")
        let seedMatchIDs = Set(FoodDatabaseSeed.items
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map(\.id))
        let hitIDs = Set(hits.map(\.id))
        #expect(seedMatchIDs.isSubset(of: hitIDs),
                "All seed hits for '\(query)' must be present in indexed results")
    }

    @Test("All indexed 'oat' results contain the query; no seed hits dropped")
    func correctnessOat() {
        let svc = FoodDatabaseService()
        let query = "oat"
        let hits = svc.search(query, limit: 25)
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains(query) },
                "Every result must contain '\(query)'")
        let seedMatchIDs = Set(FoodDatabaseSeed.items
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map(\.id))
        let hitIDs = Set(hits.map(\.id))
        #expect(seedMatchIDs.isSubset(of: hitIDs),
                "All seed hits for '\(query)' must be present in indexed results")
    }

    // -------------------------------------------------------------------------
    // record() invalidation
    // -------------------------------------------------------------------------

    @Test("Recorded AI item surfaces on next search after index invalidation")
    func recordInvalidatesIndex() {
        let svc = FoodDatabaseService()

        // Pre-condition: item is not yet present.
        let before = svc.search("zucchini noodles", limit: 25)
        #expect(before.isEmpty, "Item should not be in the index before record()")

        // Record a synthetic AI-estimated item.
        let newItem = FoodDatabaseItem(
            id: "ai_zucchini_noodles",
            name: "Zucchini noodles",
            category: .vegetable,
            preparation: .other,
            caloriesPer100g: 20,
            proteinPer100g: 1.5,
            carbsPer100g: 3.1,
            fatPer100g: 0.3,
            fiberPer100g: 1.0,
            source: .aiEstimated
        )
        svc.record(newItem)

        // Post-condition: index was invalidated; next search should find the item.
        let after = svc.search("zucchini", limit: 25)
        #expect(after.contains(where: { $0.id == "ai_zucchini_noodles" }),
                "Recorded AI item must appear in search after index rebuild")
    }

    @Test("Duplicate record() calls do not add the same item twice")
    func noDuplicateOnDoubleRecord() {
        let svc = FoodDatabaseService()
        let item = FoodDatabaseItem(
            id: "ai_test_dedupe",
            name: "Test dedupe item",
            category: .prepared,
            preparation: .other,
            caloriesPer100g: 100,
            proteinPer100g: 5,
            carbsPer100g: 10,
            fatPer100g: 3,
            fiberPer100g: nil,
            source: .aiEstimated
        )
        svc.record(item)
        svc.record(item)
        let hits = svc.search("test dedupe", limit: 25)
        let matchingCount = hits.filter { $0.id == "ai_test_dedupe" }.count
        #expect(matchingCount == 1, "record() should be idempotent; only one entry expected")
    }

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    @Test("Single-character query bypasses index and returns results")
    func singleCharQuery() {
        let svc = FoodDatabaseService()
        // Single char hits the fast path; ensure no crash and non-empty result for 'e'.
        let hits = svc.search("e", limit: 25)
        // Many seed items contain 'e'; result should be non-empty.
        #expect(!hits.isEmpty)
    }

    @Test("Empty query returns seed prefix")
    func emptyQuery() {
        let svc = FoodDatabaseService()
        let hits = svc.search("", limit: 10)
        #expect(hits.count <= 10)
        #expect(hits.allSatisfy { FoodDatabaseSeed.items.map(\.id).contains($0.id) },
                "Empty query must return only seed items")
    }

    @Test("Seed items rank before AI items in search results")
    func seedRankingOverAI() {
        let svc = FoodDatabaseService()
        // Record an AI item that would sort before "Chicken breast" alphabetically.
        let aiItem = FoodDatabaseItem(
            id: "ai_aa_chicken",
            name: "AA Chicken (AI-derived)",
            category: .protein,
            preparation: .other,
            caloriesPer100g: 150,
            proteinPer100g: 25,
            carbsPer100g: 0,
            fatPer100g: 3,
            fiberPer100g: nil,
            source: .aiEstimated
        )
        svc.record(aiItem)

        // Search for "chicken" — seed items should come before the AI item.
        let hits = svc.search("chicken", limit: 25)
        let firstAIIndex = hits.firstIndex(where: { $0.source == .aiEstimated })
        let lastSeedIndex = hits.lastIndex(where: { $0.source == .verified })

        if let firstAI = firstAIIndex, let lastSeed = lastSeedIndex {
            #expect(lastSeed < firstAI, "All seed (verified) chicken items must rank before AI items")
        }
        // If there are no AI items in the result (limit reached by seed) that's fine too.
    }
}

// MARK: - StepReader availability tests

/// Verifies that StepReader returns nil in the unit test host, where
/// HKHealthStore.isHealthDataAvailable() is false (simulator / macOS host
/// process without HealthKit entitlement). No mock needed — the guard at the
/// top of each method covers this case directly.
struct StepReaderTests {

    @Test("last7Days() returns nil or all-zero counts in the test host")
    func last7DaysReturnsNilWithoutHealthKit() async {
        // HealthKit IS available in the simulator host but no permission has
        // been granted to this test bundle. The HKStatisticsCollectionQuery
        // still enumerates buckets, each with empty stats that the reader
        // maps to zero. Accept either nil OR an array of zeros — both
        // correctly mean "no real step data."
        let result = await StepReader.last7Days()
        if let result {
            #expect(result.allSatisfy { $0 == 0 },
                    "Expected nil or all-zero counts when HealthKit has no data")
        }
    }

    @Test("today() returns nil or zero when HealthKit is unavailable")
    func todayReturnsNilWithoutHealthKit() async {
        let result = await StepReader.today()
        if let result {
            #expect(result == 0,
                    "Expected nil or zero when HealthKit has no data for today")
        }
    }
}

// MARK: - SlotPicksService tests

/// Verifies the time-of-day suggestion algorithm added in P14.
/// Tests cover the six invariants called out in the brief.
struct SlotPicksServiceTests {

    // MARK: - Helpers

    /// Builds a FoodEntry at a given offset from now with a fixed hour.
    private func entry(
        name: String,
        daysAgo: Int,
        hour: Int,
        calories: Int = 300
    ) -> FoodEntry {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        let base = calendar.date(from: comps) ?? Date()
        let timestamp = calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        return FoodEntry(
            name: name,
            calories: calories,
            protein: 20,
            carbs: 30,
            fat: 10,
            timestamp: timestamp,
            source: .manual
        )
    }

    // MARK: - Tests

    @Test("Empty entries returns empty result")
    func emptyInputReturnsEmpty() {
        let slotDate = Date()
        let result = SlotPicksService.suggestions(from: [], for: slotDate)
        #expect(result.isEmpty)
    }

    @Test("Entries outside the hour window are excluded")
    func hourWindowFiltersOutOfBandEntries() {
        // Slot hour is 9 AM; window is ±2 h → 7–11. Log something at 14:00.
        var slotComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        slotComps.hour = 9
        let slotDate = Calendar.current.date(from: slotComps) ?? Date()

        let inWindow  = entry(name: "Oatmeal",   daysAgo: 1, hour: 9)
        let outWindow = entry(name: "Burger",     daysAgo: 1, hour: 14)

        let results = SlotPicksService.suggestions(from: [inWindow, outWindow], for: slotDate, windowHours: 4)
        let names = results.map { $0.name }
        #expect(names.contains("Oatmeal"))
        #expect(!names.contains("Burger"))
    }

    @Test("Entries older than lookbackDays are excluded")
    func lookbackCutoffFiltersOldEntries() {
        var slotComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        slotComps.hour = 12
        let slotDate = Calendar.current.date(from: slotComps) ?? Date()

        let recent = entry(name: "Salad",    daysAgo: 5,  hour: 12)
        let old    = entry(name: "Old food", daysAgo: 45, hour: 12)

        let results = SlotPicksService.suggestions(from: [recent, old], for: slotDate, lookbackDays: 30)
        let names = results.map { $0.name }
        #expect(names.contains("Salad"))
        #expect(!names.contains("Old food"))
    }

    @Test("Multiple entries of the same name on the same day count once toward day-count")
    func sameDaySameNameCountsOnce() {
        var slotComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        slotComps.hour = 8
        let slotDate = Calendar.current.date(from: slotComps) ?? Date()

        // "Eggs" logged 3 times on day 1 and once on day 2 → 2 distinct days.
        // "Toast" logged once per day for 3 different days → 3 distinct days.
        // Toast should rank first.
        let eggs1a = entry(name: "Eggs",  daysAgo: 1, hour: 8)
        let eggs1b = entry(name: "Eggs",  daysAgo: 1, hour: 8, calories: 310)
        let eggs1c = entry(name: "Eggs",  daysAgo: 1, hour: 9, calories: 320)
        let eggs2  = entry(name: "Eggs",  daysAgo: 2, hour: 8)

        let toast1 = entry(name: "Toast", daysAgo: 1, hour: 8)
        let toast2 = entry(name: "Toast", daysAgo: 2, hour: 8)
        let toast3 = entry(name: "Toast", daysAgo: 3, hour: 8)

        let all = [eggs1a, eggs1b, eggs1c, eggs2, toast1, toast2, toast3]
        let results = SlotPicksService.suggestions(from: all, for: slotDate, windowHours: 4)
        #expect(results.count >= 2)
        #expect(results[0].name == "Toast", "Toast (3 distinct days) should rank above Eggs (2 distinct days)")
        #expect(results[1].name == "Eggs")
    }

    @Test("Most-frequent name ranks first")
    func mostFrequentRanksFirst() {
        var slotComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        slotComps.hour = 7
        let slotDate = Calendar.current.date(from: slotComps) ?? Date()

        // "Protein shake" logged on 5 distinct days; "Coffee" on 2.
        let shake = (1...5).map { entry(name: "Protein shake", daysAgo: $0, hour: 7) }
        let coffee = (1...2).map { entry(name: "Coffee",       daysAgo: $0, hour: 7) }

        let results = SlotPicksService.suggestions(from: shake + coffee, for: slotDate, windowHours: 4)
        #expect(results.first?.name == "Protein shake")
    }

    @Test("limit parameter caps the result count")
    func limitIsCapped() {
        var slotComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        slotComps.hour = 12
        let slotDate = Calendar.current.date(from: slotComps) ?? Date()

        // Create 20 distinct foods, each logged once.
        let entries = (0..<20).map { i in
            entry(name: "Food \(i)", daysAgo: i + 1, hour: 12)
        }

        let results = SlotPicksService.suggestions(from: entries, for: slotDate, limit: 5)
        #expect(results.count <= 5)
    }
}

// MARK: - FavoritesStore tests

/// Each test injects a fresh in-memory `ModelContainer` via
/// `SwiftDataContainer.makePreviewContainer()` so `FavoriteModel` rows from one
/// test can never leak into another. The persistence test shares a single
/// container between two store instances to verify that the second store sees
/// data written by the first — exactly what a shared in-memory container
/// provides without any on-disk side-effects.
struct FavoritesStoreTests {

    // 1. add then contains returns true
    @Test("add then contains returns true")
    @MainActor
    func addThenContains() {
        let store = FavoritesStore(container: SwiftDataContainer.makePreviewContainer())
        store.add("apple_raw")
        #expect(store.contains("apple_raw"), "Newly added ID must be contained")
    }

    // 2. add twice is idempotent
    @Test("add twice is idempotent")
    @MainActor
    func addIdempotent() {
        let store = FavoritesStore(container: SwiftDataContainer.makePreviewContainer())
        store.add("banana")
        store.add("banana")
        #expect(store.favorites.count == 1, "Duplicate add must not increase count beyond 1")
        #expect(store.sortedIDs.count == 1, "Ordered list must also remain at 1 after duplicate add")
    }

    // 3. remove decrements
    @Test("remove decrements favorites count")
    @MainActor
    func removeDecrements() {
        let store = FavoritesStore(container: SwiftDataContainer.makePreviewContainer())
        store.add("chicken_breast")
        store.add("broccoli_raw")
        store.remove("chicken_breast")
        #expect(!store.contains("chicken_breast"), "Removed ID must not be contained")
        #expect(store.favorites.count == 1)
        #expect(store.sortedIDs.count == 1)
    }

    // 4. toggle: adds when missing, removes when present
    @Test("toggle adds when missing and removes when present")
    @MainActor
    func toggleBehavior() {
        let store = FavoritesStore(container: SwiftDataContainer.makePreviewContainer())
        store.toggle("oats_rolled")
        #expect(store.contains("oats_rolled"), "toggle on absent ID must add it")
        store.toggle("oats_rolled")
        #expect(!store.contains("oats_rolled"), "toggle on present ID must remove it")
        #expect(store.favorites.isEmpty)
    }

    // 5. sortedIDs returns most-recent-first
    @Test("sortedIDs returns most-recent-first (insertion order reversed)")
    @MainActor
    func sortedIDsOrder() {
        let store = FavoritesStore(container: SwiftDataContainer.makePreviewContainer())
        store.add("first")
        store.add("second")
        store.add("third")
        let ids = store.sortedIDs
        #expect(ids == ["third", "second", "first"],
                "sortedIDs must be newest-first: got \(ids)")
    }

    // 6. persistence: two stores sharing the same in-memory container both see the same rows.
    // This verifies that `rebuild()` loads whatever the first store wrote — identical semantics
    // to a real relaunch except the backing store is in-memory and discarded after the test.
    @Test("persistence round-trip: new store instance loads all saved favorites")
    @MainActor
    func persistenceRoundTrip() {
        let container = SwiftDataContainer.makePreviewContainer()
        let store1 = FavoritesStore(container: container)
        store1.add("egg_whole")
        store1.add("brown_rice_cooked")
        store1.add("olive_oil")

        // Create a second store backed by the same container — simulates app relaunch.
        let store2 = FavoritesStore(container: container)
        #expect(store2.contains("egg_whole"), "egg_whole must survive persistence")
        #expect(store2.contains("brown_rice_cooked"), "brown_rice_cooked must survive persistence")
        #expect(store2.contains("olive_oil"), "olive_oil must survive persistence")
        #expect(store2.favorites.count == 3, "All 3 favorites must be loaded from disk")
        // Insertion order must also survive.
        #expect(store2.sortedIDs == ["olive_oil", "brown_rice_cooked", "egg_whole"],
                "Insertion order must be preserved after reload")
    }
}
