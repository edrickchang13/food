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
