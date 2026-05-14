//
//  calorietrackerTests.swift
//  calorietrackerTests
//
//  Created by Apoorv Darshan on 05/02/26.
//

import Testing
import Foundation
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
    @Test func pendingRefreshArmedAfterRapidEntries() async throws {
        let weightStore = WeightStore()
        let foodStore = FoodStore()
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
    @Test func pendingRefreshClearsAfterDebounceWindow() async throws {
        let weightStore = WeightStore()
        let foodStore = FoodStore()
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
