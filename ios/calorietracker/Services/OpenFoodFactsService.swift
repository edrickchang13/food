import Foundation

/// Async client for the Open Food Facts public REST API. OFF is a CC0-licensed
/// crowd-sourced database of ~3M packaged foods worldwide, queryable for free
/// with no API key. Quality varies (community-edited) so OFF results are tagged
/// `.aiEstimated`-equivalent (we surface them as "from Open Food Facts") rather
/// than `.verified`.
///
/// We use the JSON search endpoint (`/cgi/search.pl`) over name queries since
/// PRD section 1 excludes barcode scanning. Results are mapped into the same
/// `FoodDatabaseItem` shape the rest of Bulk AI consumes, so callers can mix
/// these freely with the bundled seed.
enum OpenFoodFactsService {
    enum LookupError: Error, LocalizedError {
        case invalidQuery
        case network(URLError)
        case decodeFailed
        case noResults

        var errorDescription: String? {
            switch self {
            case .invalidQuery: "Empty or invalid query."
            case .network(let err): "Network: \(err.localizedDescription)"
            case .decodeFailed: "Couldn't parse Open Food Facts response."
            case .noResults: "No matches in Open Food Facts."
            }
        }
    }

    /// Up to 25 matches for a free-text product name query. Returns the most
    /// popular (highest unique_scans_n) results first since OFF's relevance
    /// sort is noisy. Items missing per-100g macros are filtered out.
    static func search(_ query: String, limit: Int = 25) async throws -> [FoodDatabaseItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LookupError.invalidQuery }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(min(limit, 50))),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,quantity"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n")
        ]

        guard let url = components.url else { throw LookupError.invalidQuery }

        var request = URLRequest(url: url)
        request.setValue("BulkAI/1.0 (https://github.com/edrickchang13/food)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch let urlError as URLError {
            throw LookupError.network(urlError)
        }

        let response: SearchResponse
        do {
            response = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw LookupError.decodeFailed
        }

        let items = (response.products ?? [])
            .compactMap { Self.makeItem(from: $0) }
            .prefix(limit)

        if items.isEmpty { throw LookupError.noResults }
        return Array(items)
    }

    // MARK: - Mapping

    private static func makeItem(from product: Product) -> FoodDatabaseItem? {
        guard let name = product.product_name, !name.isEmpty else { return nil }
        guard let n = product.nutriments,
              let kcal = n.energyKcalPer100g,
              kcal > 0 else { return nil }

        let displayName: String
        if let brand = product.brands?.split(separator: ",").first.map({ String($0).trimmingCharacters(in: .whitespaces) }),
           !brand.isEmpty {
            displayName = "\(name) (\(brand))"
        } else {
            displayName = name
        }

        return FoodDatabaseItem(
            id: "off_\(product.code ?? UUID().uuidString)",
            name: displayName,
            category: .prepared,
            preparation: .other,
            caloriesPer100g: kcal,
            proteinPer100g: n.proteinsPer100g ?? 0,
            carbsPer100g: n.carbsPer100g ?? 0,
            fatPer100g: n.fatPer100g ?? 0,
            fiberPer100g: n.fiberPer100g,
            source: .aiEstimated
        )
    }

    // MARK: - JSON shapes (Open Food Facts is loose, fields are best-effort)

    private struct SearchResponse: Decodable {
        let products: [Product]?
    }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let brands: String?
        let quantity: String?
        let nutriments: Nutriments?
    }

    /// Open Food Facts publishes many synonyms for the same nutrient. We try the
    /// common keys per nutrient and take the first present value. All units are
    /// already per 100 g of product when fetched via the `_100g` suffix.
    private struct Nutriments: Decodable {
        let energyKcalPer100g: Double?
        let proteinsPer100g: Double?
        let carbsPer100g: Double?
        let fatPer100g: Double?
        let fiberPer100g: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)

            func first(_ keys: [String]) -> Double? {
                for key in keys {
                    if let coding = DynamicKey(stringValue: key),
                       let value = try? container.decodeIfPresent(Double.self, forKey: coding),
                       value.isFinite {
                        return value
                    }
                }
                return nil
            }

            energyKcalPer100g = first([
                "energy-kcal_100g",
                "energy_kcal_100g",
                "energy-kcal_serving"
            ])
            proteinsPer100g = first(["proteins_100g", "protein_100g"])
            carbsPer100g = first(["carbohydrates_100g", "carbs_100g"])
            fatPer100g = first(["fat_100g"])
            fiberPer100g = first(["fiber_100g"])
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
