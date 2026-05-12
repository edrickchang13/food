import Foundation

/// A single entry in the verified nutrition database that ships with Bulk AI.
/// Macros are per 100 g of edible portion. For foods where raw and cooked values
/// differ meaningfully (chicken breast, rice, etc.) we ship both variants as
/// separate items rather than computing a conversion ratio at runtime.
struct FoodDatabaseItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: FoodDatabaseCategory
    let preparation: FoodPreparation
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double?
    let source: FoodDatabaseSource
}

enum FoodDatabaseCategory: String, Codable, CaseIterable {
    case protein
    case grain
    case vegetable
    case fruit
    case dairy
    case fat
    case prepared

    var displayName: String {
        switch self {
        case .protein: "Protein"
        case .grain: "Grain"
        case .vegetable: "Vegetable"
        case .fruit: "Fruit"
        case .dairy: "Dairy"
        case .fat: "Fat"
        case .prepared: "Prepared"
        }
    }
}

enum FoodPreparation: String, Codable, CaseIterable {
    case raw
    case cooked
    case other

    var displayName: String {
        switch self {
        case .raw: "Raw"
        case .cooked: "Cooked"
        case .other: ""
        }
    }
}

enum FoodDatabaseSource: String, Codable {
    /// Verified from USDA FoodData Central or equivalent peer-reviewed source.
    case verified
    /// Filled in from a Gemini call after a local-DB miss. Less reliable; the
    /// app shows a small "AI-estimated" indicator when these are surfaced.
    case aiEstimated
}
