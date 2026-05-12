import Foundation

struct RecipeIngredient: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double,
        caloriesPer100g: Double = 0,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        fatPer100g: Double = 0
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
    }

    var totalCalories: Double { grams / 100 * caloriesPer100g }
    var totalProtein: Double { grams / 100 * proteinPer100g }
    var totalCarbs: Double { grams / 100 * carbsPer100g }
    var totalFat: Double { grams / 100 * fatPer100g }
}

struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var servings: Int
    var ingredients: [RecipeIngredient]
    var sourceURL: URL?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        servings: Int = 1,
        ingredients: [RecipeIngredient] = [],
        sourceURL: URL? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.servings = max(1, servings)
        self.ingredients = ingredients
        self.sourceURL = sourceURL
        self.notes = notes
        self.createdAt = createdAt
    }

    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { ingredients.reduce(0) { $0 + $1.totalFat } }

    var caloriesPerServing: Int { Int((totalCalories / Double(servings)).rounded()) }
    var proteinPerServing: Int { Int((totalProtein / Double(servings)).rounded()) }
    var carbsPerServing: Int { Int((totalCarbs / Double(servings)).rounded()) }
    var fatPerServing: Int { Int((totalFat / Double(servings)).rounded()) }

    /// Build a FoodEntry from `servings` portions of this recipe. The caller decides
    /// the meal type and date.
    func makeFoodEntry(servings: Double, mealType: MealType, date: Date = .now) -> FoodEntry {
        let multiplier = servings / Double(self.servings)
        return FoodEntry(
            name: servings == 1 ? name : "\(name) (\(servings) servings)",
            calories: Int((totalCalories * multiplier).rounded()),
            protein: Int((totalProtein * multiplier).rounded()),
            carbs: Int((totalCarbs * multiplier).rounded()),
            fat: Int((totalFat * multiplier).rounded()),
            timestamp: date,
            source: .manual,
            mealType: mealType
        )
    }
}
