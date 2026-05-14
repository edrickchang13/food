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
    let sodiumPer100g: Double?         // milligrams per 100 g
    let sugarPer100g: Double?          // grams per 100 g
    let saturatedFatPer100g: Double?   // grams per 100 g
    let source: FoodDatabaseSource

    init(
        id: String,
        name: String,
        category: FoodDatabaseCategory,
        preparation: FoodPreparation,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        sugarPer100g: Double? = nil,
        saturatedFatPer100g: Double? = nil,
        source: FoodDatabaseSource
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.preparation = preparation
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumPer100g = sodiumPer100g
        self.sugarPer100g = sugarPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.source = source
    }
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
