import Foundation
import SwiftUI

/// Searches the bundled verified seed and a runtime cache of LLM-derived items.
/// Lookup order: local exact match → local fuzzy match → caller's responsibility
/// to call the LLM and pass the result back through `record(_:)` for next time.
@Observable
final class FoodDatabaseService {
    private(set) var aiCache: [FoodDatabaseItem] = []
    private let cacheKey = "foodDatabaseAICache"

    init() {
        loadCache()
    }

    /// All known items, seed + AI cache, sorted by name. Used by browse UI.
    var allItems: [FoodDatabaseItem] {
        (FoodDatabaseSeed.items + aiCache).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Returns matches across both seed and cache. Case-insensitive substring
    /// search on the name field. Verified seed results rank ahead of AI ones
    /// since they're trustworthier.
    func search(_ query: String, limit: Int = 25) -> [FoodDatabaseItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(FoodDatabaseSeed.items.prefix(limit)) }

        let seedHits = FoodDatabaseSeed.items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
        let cacheHits = aiCache.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
        return Array((seedHits + cacheHits).prefix(limit))
    }

    /// Persists an AI-derived nutrition lookup so it shows up on next search.
    /// Called by the higher-level food parsing flow after a Gemini call that
    /// returned macros for a previously-unknown item.
    func record(_ item: FoodDatabaseItem) {
        guard item.source == .aiEstimated else { return }
        if aiCache.contains(where: { $0.id == item.id }) { return }
        aiCache.append(item)
        saveCache()
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
