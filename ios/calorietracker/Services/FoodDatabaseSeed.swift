import Foundation

/// Hand-curated seed foods that ship with Bulk AI. Values are per 100 g of edible
/// portion, sourced from USDA FoodData Central SR Legacy. The intent is to cover
/// the most common ~30 foods users will log frequently so the local lookup
/// returns a hit before we have to call Gemini.
///
/// Items with meaningful raw-vs-cooked differences (chicken breast, white rice,
/// brown rice) ship as separate variants. Users picking from the database see
/// both options and grams-per-serving choices are theirs to make.
///
/// A USDA FDC SR Legacy import is the next step (P7c) that will expand this to
/// thousands of foods. For now the seed is small enough to fit in a Swift literal
/// without needing a bundled JSON resource.
enum FoodDatabaseSeed {
    static let items: [FoodDatabaseItem] = [
        // Protein - poultry
        .init(id: "chicken_breast_raw", name: "Chicken breast", category: .protein, preparation: .raw,
              caloriesPer100g: 120, proteinPer100g: 23.0, carbsPer100g: 0, fatPer100g: 2.6,
              fiberPer100g: 0, source: .verified),
        .init(id: "chicken_breast_cooked", name: "Chicken breast", category: .protein, preparation: .cooked,
              caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0, fatPer100g: 3.6,
              fiberPer100g: 0, source: .verified),
        .init(id: "chicken_thigh_cooked", name: "Chicken thigh", category: .protein, preparation: .cooked,
              caloriesPer100g: 209, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 10.9,
              fiberPer100g: 0, source: .verified),

        // Protein - beef
        .init(id: "ground_beef_85_cooked", name: "Ground beef 85/15", category: .protein, preparation: .cooked,
              caloriesPer100g: 250, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 15.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "sirloin_cooked", name: "Sirloin steak", category: .protein, preparation: .cooked,
              caloriesPer100g: 206, proteinPer100g: 29.0, carbsPer100g: 0, fatPer100g: 9.0,
              fiberPer100g: 0, source: .verified),

        // Protein - fish / seafood
        .init(id: "salmon_cooked", name: "Atlantic salmon", category: .protein, preparation: .cooked,
              caloriesPer100g: 206, proteinPer100g: 22.0, carbsPer100g: 0, fatPer100g: 13.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "tuna_canned_water", name: "Tuna, canned in water", category: .protein, preparation: .other,
              caloriesPer100g: 116, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 0.8,
              fiberPer100g: 0, source: .verified),
        .init(id: "shrimp_cooked", name: "Shrimp", category: .protein, preparation: .cooked,
              caloriesPer100g: 99, proteinPer100g: 24.0, carbsPer100g: 0.2, fatPer100g: 0.3,
              fiberPer100g: 0, source: .verified),

        // Protein - eggs / dairy proteins
        .init(id: "whole_egg", name: "Whole egg", category: .protein, preparation: .other,
              caloriesPer100g: 143, proteinPer100g: 13.0, carbsPer100g: 1.1, fatPer100g: 9.5,
              fiberPer100g: 0, source: .verified),
        .init(id: "egg_white", name: "Egg whites", category: .protein, preparation: .other,
              caloriesPer100g: 52, proteinPer100g: 11.0, carbsPer100g: 0.7, fatPer100g: 0.2,
              fiberPer100g: 0, source: .verified),
        .init(id: "greek_yogurt_nonfat", name: "Greek yogurt, nonfat", category: .dairy, preparation: .other,
              caloriesPer100g: 59, proteinPer100g: 10.0, carbsPer100g: 3.6, fatPer100g: 0.4,
              fiberPer100g: 0, source: .verified),
        .init(id: "cottage_cheese_lowfat", name: "Cottage cheese, 1%", category: .dairy, preparation: .other,
              caloriesPer100g: 72, proteinPer100g: 12.4, carbsPer100g: 2.7, fatPer100g: 1.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "whey_protein", name: "Whey protein isolate", category: .protein, preparation: .other,
              caloriesPer100g: 370, proteinPer100g: 85.0, carbsPer100g: 3.0, fatPer100g: 1.0,
              fiberPer100g: 0, source: .verified),

        // Grains
        .init(id: "white_rice_raw", name: "White rice, long grain", category: .grain, preparation: .raw,
              caloriesPer100g: 365, proteinPer100g: 7.1, carbsPer100g: 80.0, fatPer100g: 0.7,
              fiberPer100g: 1.3, source: .verified),
        .init(id: "white_rice_cooked", name: "White rice, long grain", category: .grain, preparation: .cooked,
              caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28.0, fatPer100g: 0.3,
              fiberPer100g: 0.4, source: .verified),
        .init(id: "brown_rice_cooked", name: "Brown rice", category: .grain, preparation: .cooked,
              caloriesPer100g: 112, proteinPer100g: 2.6, carbsPer100g: 23.0, fatPer100g: 0.9,
              fiberPer100g: 1.8, source: .verified),
        .init(id: "rolled_oats_dry", name: "Rolled oats, dry", category: .grain, preparation: .raw,
              caloriesPer100g: 379, proteinPer100g: 13.0, carbsPer100g: 67.0, fatPer100g: 6.5,
              fiberPer100g: 10.0, source: .verified),
        .init(id: "whole_wheat_bread", name: "Whole wheat bread", category: .grain, preparation: .other,
              caloriesPer100g: 247, proteinPer100g: 13.0, carbsPer100g: 41.0, fatPer100g: 3.4,
              fiberPer100g: 6.0, source: .verified),
        .init(id: "pasta_cooked", name: "Pasta, cooked", category: .grain, preparation: .cooked,
              caloriesPer100g: 131, proteinPer100g: 5.0, carbsPer100g: 25.0, fatPer100g: 1.1,
              fiberPer100g: 1.8, source: .verified),
        .init(id: "quinoa_cooked", name: "Quinoa", category: .grain, preparation: .cooked,
              caloriesPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21.3, fatPer100g: 1.9,
              fiberPer100g: 2.8, source: .verified),
        .init(id: "sweet_potato_cooked", name: "Sweet potato, baked", category: .vegetable, preparation: .cooked,
              caloriesPer100g: 90, proteinPer100g: 2.0, carbsPer100g: 21.0, fatPer100g: 0.2,
              fiberPer100g: 3.3, source: .verified),
        .init(id: "russet_potato_cooked", name: "Russet potato, baked", category: .vegetable, preparation: .cooked,
              caloriesPer100g: 97, proteinPer100g: 2.6, carbsPer100g: 22.0, fatPer100g: 0.1,
              fiberPer100g: 2.1, source: .verified),

        // Vegetables
        .init(id: "broccoli_cooked", name: "Broccoli", category: .vegetable, preparation: .cooked,
              caloriesPer100g: 35, proteinPer100g: 2.4, carbsPer100g: 7.2, fatPer100g: 0.4,
              fiberPer100g: 3.3, source: .verified),
        .init(id: "spinach_raw", name: "Spinach", category: .vegetable, preparation: .raw,
              caloriesPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4,
              fiberPer100g: 2.2, source: .verified),
        .init(id: "kale_raw", name: "Kale", category: .vegetable, preparation: .raw,
              caloriesPer100g: 49, proteinPer100g: 4.3, carbsPer100g: 9.0, fatPer100g: 0.9,
              fiberPer100g: 3.6, source: .verified),
        .init(id: "carrot_raw", name: "Carrot", category: .vegetable, preparation: .raw,
              caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 9.6, fatPer100g: 0.2,
              fiberPer100g: 2.8, source: .verified),
        .init(id: "avocado", name: "Avocado", category: .fat, preparation: .raw,
              caloriesPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 8.5, fatPer100g: 14.7,
              fiberPer100g: 6.7, source: .verified),

        // Fruits
        .init(id: "banana", name: "Banana", category: .fruit, preparation: .raw,
              caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23.0, fatPer100g: 0.3,
              fiberPer100g: 2.6, source: .verified),
        .init(id: "apple", name: "Apple", category: .fruit, preparation: .raw,
              caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14.0, fatPer100g: 0.2,
              fiberPer100g: 2.4, source: .verified),
        .init(id: "blueberries", name: "Blueberries", category: .fruit, preparation: .raw,
              caloriesPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14.5, fatPer100g: 0.3,
              fiberPer100g: 2.4, source: .verified),
        .init(id: "strawberries", name: "Strawberries", category: .fruit, preparation: .raw,
              caloriesPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 7.7, fatPer100g: 0.3,
              fiberPer100g: 2.0, source: .verified),

        // Dairy
        .init(id: "milk_whole", name: "Whole milk", category: .dairy, preparation: .other,
              caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3,
              fiberPer100g: 0, source: .verified),
        .init(id: "milk_skim", name: "Skim milk", category: .dairy, preparation: .other,
              caloriesPer100g: 34, proteinPer100g: 3.4, carbsPer100g: 5.0, fatPer100g: 0.1,
              fiberPer100g: 0, source: .verified),
        .init(id: "cheddar_cheese", name: "Cheddar cheese", category: .dairy, preparation: .other,
              caloriesPer100g: 403, proteinPer100g: 24.9, carbsPer100g: 1.3, fatPer100g: 33.1,
              fiberPer100g: 0, source: .verified),

        // Fats
        .init(id: "almond", name: "Almonds", category: .fat, preparation: .raw,
              caloriesPer100g: 579, proteinPer100g: 21.0, carbsPer100g: 22.0, fatPer100g: 50.0,
              fiberPer100g: 12.5, source: .verified),
        .init(id: "peanut_butter", name: "Peanut butter", category: .fat, preparation: .other,
              caloriesPer100g: 588, proteinPer100g: 25.0, carbsPer100g: 20.0, fatPer100g: 50.0,
              fiberPer100g: 6.0, source: .verified),
        .init(id: "olive_oil", name: "Olive oil", category: .fat, preparation: .other,
              caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100,
              fiberPer100g: 0, source: .verified),
        .init(id: "butter", name: "Butter", category: .fat, preparation: .other,
              caloriesPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.1, fatPer100g: 81.0,
              fiberPer100g: 0, source: .verified)
    ]
}
