import Foundation

/// Imports a Recipe from a URL by fetching the page and looking for schema.org Recipe
/// JSON-LD. Most major recipe sites (NYT Cooking, AllRecipes, Serious Eats, Bon Appétit,
/// Food Network, etc.) embed this. Falls back to nil if no parseable structured data is
/// found — the caller can prompt the user to enter ingredients manually.
///
/// Note: ingredient macros are not present in schema.org Recipe, so imported recipes
/// have zero macros per ingredient. The user can edit each row to fill them in, or
/// in a later phase we hand the ingredient list to the LLM for nutrition estimation.
enum RecipeImporter {
    enum ImportError: Error, LocalizedError {
        case invalidURL
        case fetchFailed
        case noStructuredData

        var errorDescription: String? {
            switch self {
            case .invalidURL: "That doesn't look like a valid URL."
            case .fetchFailed: "Couldn't reach the page."
            case .noStructuredData: "No recipe data found on this page. Add ingredients manually."
            }
        }
    }

    static func importRecipe(from urlString: String) async throws -> Recipe {
        guard let url = URL(string: urlString) else { throw ImportError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImportError.fetchFailed
        }
        guard let html = String(data: data, encoding: .utf8) else { throw ImportError.fetchFailed }

        guard let recipe = parseJSONLD(html: html, sourceURL: url) else {
            throw ImportError.noStructuredData
        }
        return recipe
    }

    /// Pulls every <script type="application/ld+json"> block out of the HTML and finds
    /// the first one that's (or contains) a Recipe. Some sites nest the recipe inside
    /// an @graph array, so we walk both shapes.
    private static func parseJSONLD(html: String, sourceURL: URL) -> Recipe? {
        let scripts = extractJSONLDBlocks(html: html)
        for block in scripts {
            guard let data = block.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipeNode(in: parsed) {
                return makeRecipe(from: recipe, sourceURL: sourceURL)
            }
        }
        return nil
    }

    private static func extractJSONLDBlocks(html: String) -> [String] {
        let pattern = #"<script[^>]+type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        return matches.compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[r])
        }
    }

    /// Recursively walks the parsed JSON looking for an object with @type == "Recipe".
    private static func findRecipeNode(in any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            if let type = dict["@type"], typeMatchesRecipe(type) { return dict }
            for value in dict.values {
                if let found = findRecipeNode(in: value) { return found }
            }
        } else if let array = any as? [Any] {
            for item in array {
                if let found = findRecipeNode(in: item) { return found }
            }
        }
        return nil
    }

    private static func typeMatchesRecipe(_ value: Any) -> Bool {
        if let s = value as? String { return s == "Recipe" }
        if let arr = value as? [String] { return arr.contains("Recipe") }
        return false
    }

    private static func makeRecipe(from node: [String: Any], sourceURL: URL) -> Recipe {
        let name = (node["name"] as? String) ?? sourceURL.host ?? "Imported recipe"

        // recipeYield can be a number, a string with a number, or an array.
        var servings = 1
        if let yieldNumber = node["recipeYield"] as? Int { servings = max(1, yieldNumber) }
        else if let yieldString = node["recipeYield"] as? String {
            let digits = yieldString.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            if let n = Int(String(digits)), n > 0 { servings = n }
        } else if let yieldArr = node["recipeYield"] as? [Any],
                  let first = yieldArr.first {
            if let n = first as? Int { servings = max(1, n) }
            else if let s = first as? String,
                    let n = Int(s.filter(\.isNumber)), n > 0 { servings = n }
        }

        let ingredientStrings = (node["recipeIngredient"] as? [String]) ?? []
        let ingredients: [RecipeIngredient] = ingredientStrings.map { rawLine in
            // Parse "200g flour" or "1 cup sugar" style strings. We extract the leading
            // gram count if explicit; otherwise default to 0 grams and let the user fix.
            let (grams, name) = splitGramsAndName(from: rawLine)
            return RecipeIngredient(name: name, grams: grams)
        }

        return Recipe(name: name, servings: servings, ingredients: ingredients, sourceURL: sourceURL)
    }

    /// Best-effort parse of an ingredient line. We only honor explicit gram counts; cups,
    /// tablespoons, ounces etc. are too ambiguous to convert without context. Anything we
    /// can't parse cleanly gets grams = 0 so the user knows to edit it.
    private static func splitGramsAndName(from line: String) -> (grams: Double, name: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if let match = lower.range(of: #"^(\d+(?:\.\d+)?)\s*g(?:ram(?:s)?)?\b"#, options: .regularExpression) {
            let numberString = lower[match].replacingOccurrences(of: #"[^0-9.]"#, with: "", options: .regularExpression)
            let grams = Double(numberString) ?? 0
            let nameStart = trimmed.index(trimmed.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: match.upperBound))
            let name = trimmed[nameStart...].trimmingCharacters(in: .whitespaces)
            return (grams, name.isEmpty ? trimmed : name)
        }
        return (0, trimmed)
    }
}
