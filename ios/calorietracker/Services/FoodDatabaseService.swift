import Foundation
import SwiftUI

/// Searches the bundled verified seed and a runtime cache of LLM-derived items.
/// Lookup order: local exact match → local fuzzy match → caller's responsibility
/// to call the LLM and pass the result back through `record(_:)` for next time.
@Observable
final class FoodDatabaseService {
    private(set) var aiCache: [FoodDatabaseItem] = []
    private let cacheKey = "foodDatabaseAICache"

    /// Bundled USDA FoodData Central subset (~6,900 verified items). Loaded
    /// lazily on first search so app launch isn't blocked decoding ~1.7 MB JSON.
    private var bundledUSDA: [FoodDatabaseItem]? = nil

    // MARK: - Search index

    /// A lazily-built, name-sorted index over the full corpus.
    ///
    /// Design rationale:
    ///   - `lowerNames` stores each item's lowercased name so binary-search
    ///     prefix scans never re-lowercase inside the hot loop.
    ///   - `sourcePriority` stores a stable rank (1 = USDA, 2 = AI) so the
    ///     indexed pass (which never includes seed items) can still rank USDA
    ///     above AI when filling the non-seed result slots.
    ///   - The index is invalidated (set to nil) whenever `record(_:)` adds a
    ///     new AI-cache row; it rebuilds on the next search call.
    private struct SortedIndex {
        let sortedItems: [FoodDatabaseItem]
        let lowerNames: [String]
        let sourcePriority: [Int]   // 1 = USDA, 2 = AI cache (seed is not indexed)
    }

    private var searchIndex: SortedIndex?

    // MARK: - Init

    init() {
        loadCache()
    }

    // MARK: - Public API

    /// All known items: hand-curated seed + bundled USDA + AI cache, sorted
    /// by name. Used by browse UI when no search is active.
    var allItems: [FoodDatabaseItem] {
        (FoodDatabaseSeed.items + loadUSDAIfNeeded() + aiCache).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Returns matches across the curated seed, the bundled USDA dataset, and
    /// the AI cache. Case-insensitive substring on name. Curated seed ranks
    /// first (highest trust), USDA second (verified but plain names), AI cache
    /// last (LLM-derived, lowest trust).
    ///
    /// For queries of 2+ characters:
    ///   1. All seed matches (prefix or substring) are collected first — the
    ///      seed is only ~36 items so this is O(1) in practice. This guarantees
    ///      seed hits are never crowded out by USDA results.
    ///   2. Remaining slots are filled from the USDA+AI corpus via a
    ///      binary-search prefix scan followed by a substring fallback pass.
    /// For 0–1 character queries the index is bypassed entirely.
    func search(_ query: String, limit: Int = 25) -> [FoodDatabaseItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(FoodDatabaseSeed.items.prefix(limit)) }

        let lower = trimmed.lowercased()

        // Short queries: index overhead not worthwhile; linear scan all sources.
        guard lower.count >= 2 else {
            return Array(
                (FoodDatabaseSeed.items + loadUSDAIfNeeded() + aiCache)
                    .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
                    .prefix(limit)
            )
        }

        // Step 1: collect every seed match (the seed is tiny; this is negligible).
        let seedHits = FoodDatabaseSeed.items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }

        let remaining = limit - seedHits.count
        guard remaining > 0 else { return Array(seedHits.prefix(limit)) }

        // Step 2: fill remaining slots from USDA + AI via the binary-search index.
        let idx = buildIndexIfNeeded()
        let seedIDs = Set(seedHits.map(\.id))
        let nonSeedHits = indexedSearch(lower: lower, limit: remaining, excludingIDs: seedIDs, in: idx)

        return seedHits + nonSeedHits
    }

    /// Searches the local seed + AI cache, then merges Open Food Facts results
    /// over the network. Returns local matches synchronously and OFF matches
    /// after they arrive. Caller is expected to render incrementally — when
    /// the local set is empty and OFF is loading, show a spinner.
    ///
    /// OFF results are appended to the AI cache on success so they show up
    /// locally on the next launch and don't require a network round-trip.
    func searchIncludingRemote(_ query: String, limit: Int = 30) async -> [FoodDatabaseItem] {
        let local = search(query, limit: limit)
        let remote: [FoodDatabaseItem]
        do {
            remote = try await OpenFoodFactsService.search(query, limit: limit)
        } catch {
            return local
        }
        // Cache remote hits so future searches don't repeat the network call.
        for item in remote {
            record(item)
        }
        // Dedupe by id; local wins on collision since verified ranks above OFF.
        var seenIDs = Set(local.map { $0.id })
        var combined = local
        for item in remote where !seenIDs.contains(item.id) {
            combined.append(item)
            seenIDs.insert(item.id)
        }
        return Array(combined.prefix(limit))
    }

    /// Persists an AI-derived nutrition lookup so it shows up on next search.
    /// Called by the higher-level food parsing flow after a Gemini call that
    /// returned macros for a previously-unknown item.
    func record(_ item: FoodDatabaseItem) {
        guard item.source == .aiEstimated else { return }
        if aiCache.contains(where: { $0.id == item.id }) { return }
        aiCache.append(item)
        // Invalidate the sorted index so the new entry is included on the next search.
        searchIndex = nil
        saveCache()
    }

    /// Caches a Gemini-derived analysis as an AI-estimated database entry. Only
    /// caches when the analysis names a single recognizable item with a known
    /// serving size, so we don't pollute the cache with complex multi-item
    /// meals that don't generalize.
    func recordFromAnalysis(name: String, kcal: Int, protein: Int, carbs: Int, fat: Int, servingGrams: Double?, fiber: Double?) {
        guard let grams = servingGrams, grams > 0 else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count < 40 else { return }
        // Skip clearly-composed names: anything with quantities, "with", commas, or
        // " and " in them isn't a single ingredient we can usefully cache per-100g.
        let lower = trimmed.lowercased()
        let banned = [" with ", " and ", ",", "+", "&"]
        for marker in banned where lower.contains(marker) { return }
        if lower.contains(where: \.isNumber) { return }
        let perGram = 100.0 / grams
        let item = FoodDatabaseItem(
            id: "ai_" + trimmed.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: trimmed,
            category: .prepared,
            preparation: .other,
            caloriesPer100g: Double(kcal) * perGram,
            proteinPer100g: Double(protein) * perGram,
            carbsPer100g: Double(carbs) * perGram,
            fatPer100g: Double(fat) * perGram,
            fiberPer100g: fiber.map { $0 * perGram },
            source: .aiEstimated
        )
        record(item)
    }

    /// Try to short-circuit a free-text input by parsing a "<grams>g <name>"
    /// pattern and matching the name against the local database. Returns nil
    /// when the input is too complex (multiple items, no explicit grams, no
    /// unambiguous match) and the caller should fall back to the LLM.
    func quickLookup(_ input: String) -> (item: FoodDatabaseItem, grams: Double)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" and "), !trimmed.contains(",") else { return nil }

        // Match leading "<number>g <name>" or "<number> g <name>".
        guard let regex = try? NSRegularExpression(
            pattern: #"^\s*(\d+(?:\.\d+)?)\s*g(?:rams?)?\s+(.+)$"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges == 3,
              let gramsRange = Range(match.range(at: 1), in: trimmed),
              let nameRange = Range(match.range(at: 2), in: trimmed),
              let grams = Double(String(trimmed[gramsRange])),
              grams > 0
        else { return nil }

        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let hits = search(name, limit: 5)

        // Demand exactly one strong match. If multiple seed entries share a
        // name (e.g. raw vs cooked variants), fall back to the LLM so the user
        // doesn't get the wrong preparation silently.
        let exactMatches = hits.filter { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        if exactMatches.count == 1 {
            return (exactMatches[0], grams)
        }
        if hits.count == 1 {
            return (hits[0], grams)
        }
        return nil
    }

    // MARK: - Private helpers

    /// One-shot lazy decode of the bundled USDA JSON. Subsequent calls return
    /// the cached array. Decoding 1.7 MB of simple structs takes ~150 ms on a
    /// recent iPhone; doing it on first-search keeps cold launch snappy.
    private func loadUSDAIfNeeded() -> [FoodDatabaseItem] {
        if let bundledUSDA { return bundledUSDA }
        guard let url = Bundle.main.url(forResource: "usda-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([FoodDatabaseItem].self, from: data)
        else {
            bundledUSDA = []
            return []
        }
        bundledUSDA = decoded
        return decoded
    }

    /// Builds the sorted index on first call. Subsequent calls return the cached
    /// index. Callers must set `searchIndex = nil` to force a rebuild (e.g. when
    /// the AI cache grows via `record(_:)`).
    ///
    /// The index covers USDA and AI-cache items only. Seed items are handled
    /// directly in `search(_:limit:)` before this index is consulted, so
    /// including them here would add overhead without benefit.
    ///
    /// Items are sorted by lowercased name. `sourcePriority` tracks USDA (1)
    /// vs AI (2) so the indexed path can still rank USDA above AI items when
    /// filling the non-seed slots.
    private func buildIndexIfNeeded() -> SortedIndex {
        if let searchIndex { return searchIndex }

        let usda  = loadUSDAIfNeeded()
        let cache = aiCache

        struct Tagged {
            let item: FoodDatabaseItem
            let lower: String
            let priority: Int
        }

        var tagged: [Tagged] = []
        tagged.reserveCapacity(usda.count + cache.count)
        for item in usda  { tagged.append(Tagged(item: item, lower: item.name.lowercased(), priority: 1)) }
        for item in cache { tagged.append(Tagged(item: item, lower: item.name.lowercased(), priority: 2)) }

        let sorted = tagged.sorted { $0.lower < $1.lower }

        let built = SortedIndex(
            sortedItems: sorted.map(\.item),
            lowerNames: sorted.map(\.lower),
            sourcePriority: sorted.map(\.priority)
        )
        searchIndex = built
        return built
    }

    /// Binary-search assisted lookup against a pre-sorted index, skipping items
    /// already returned by the seed pass in `search(_:limit:)`.
    ///
    /// Pass 1 — prefix bucket:
    ///   Binary-searches to the first name >= `lower`, then walks forward while
    ///   `names[i].hasPrefix(lower)`. All prefix matches are collected (no early
    ///   exit) so that USDA items with priority 1 don't crowd out AI items with
    ///   priority 2 in the final prefix sort. After sorting by priority the top
    ///   `limit` items are taken.
    ///
    /// Pass 2 — substring bucket (only when Pass 1 fills < `limit` slots):
    ///   A single linear scan over the full index collecting names that contain
    ///   but do not start with the query. Sorted by priority before merging.
    ///   This restores MacroFactor-style hits such as "Chicken Rice Bowl" for
    ///   a "rice" query.
    ///
    /// Seed items are excluded via `excludingIDs` (already collected upstream)
    /// so they never appear in this function's output.
    private func indexedSearch(
        lower: String,
        limit: Int,
        excludingIDs: Set<String>,
        in idx: SortedIndex
    ) -> [FoodDatabaseItem] {
        let names = idx.lowerNames

        // --- Pass 1: binary-search to first prefix match ---
        var lo = 0, hi = names.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if names[mid] < lower {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        struct Candidate {
            let item: FoodDatabaseItem
            let priority: Int
        }
        var prefixBucket: [Candidate] = []
        var i = lo
        while i < names.count, names[i].hasPrefix(lower) {
            let item = idx.sortedItems[i]
            if !excludingIDs.contains(item.id) {
                prefixBucket.append(Candidate(item: item, priority: idx.sourcePriority[i]))
            }
            i += 1
        }
        prefixBucket.sort { $0.priority < $1.priority }

        if prefixBucket.count >= limit {
            return prefixBucket.prefix(limit).map(\.item)
        }

        // --- Pass 2: linear substring scan for non-prefix containment ---
        let remaining = limit - prefixBucket.count
        var seenIDs = excludingIDs.union(Set(prefixBucket.map { $0.item.id }))
        var substringBucket: [Candidate] = []
        for j in 0..<names.count {
            guard !seenIDs.contains(idx.sortedItems[j].id) else { continue }
            guard names[j].contains(lower), !names[j].hasPrefix(lower) else { continue }
            substringBucket.append(Candidate(item: idx.sortedItems[j], priority: idx.sourcePriority[j]))
            seenIDs.insert(idx.sortedItems[j].id)
        }
        substringBucket.sort { $0.priority < $1.priority }

        return (prefixBucket + substringBucket.prefix(remaining)).map(\.item)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([FoodDatabaseItem].self, from: data)
        else { return }
        aiCache = decoded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(aiCache) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
