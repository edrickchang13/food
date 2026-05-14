import Foundation

/// Hand-curated seed of common restaurant-chain + big-box-store items so users
/// who log fast-food or warehouse-club purchases get a hit before falling back
/// to Gemini's free-text estimator. Values are per 100 g of edible portion,
/// derived from each chain's publicly published nutrition data on their own
/// website (FDA-required labeling). Source URLs and capture dates are noted
/// inline so the values are auditable.
///
/// Scope: top ~5–10 most-ordered items per chain. The full menu lives in
/// remote sources (Open Food Facts, future Nutritionix integration); this
/// seed covers the offline / common case.
///
/// `id` format: `<chain-slug>_<item-slug>` — keeps these obviously distinct
/// from the generic USDA-style ids in `FoodDatabaseSeed`.
enum FoodDatabaseChainSeed {
    static let items: [FoodDatabaseItem] = [

        // MARK: - In-N-Out (innout.com/menu/nutrition-info, captured 2025-11)
        .init(id: "innout_double_double", name: "In-N-Out Double-Double", category: .prepared, preparation: .other,
              caloriesPer100g: 240, proteinPer100g: 13.4, carbsPer100g: 11.6, fatPer100g: 16.2,
              fiberPer100g: 0.9, source: .verified),
        .init(id: "innout_cheeseburger", name: "In-N-Out Cheeseburger", category: .prepared, preparation: .other,
              caloriesPer100g: 197, proteinPer100g: 9.9, carbsPer100g: 13.6, fatPer100g: 11.8,
              fiberPer100g: 1.2, source: .verified),
        .init(id: "innout_hamburger", name: "In-N-Out Hamburger", category: .prepared, preparation: .other,
              caloriesPer100g: 169, proteinPer100g: 8.7, carbsPer100g: 14.0, fatPer100g: 9.0,
              fiberPer100g: 1.2, source: .verified),
        .init(id: "innout_animal_fries", name: "In-N-Out Animal Fries", category: .prepared, preparation: .other,
              caloriesPer100g: 280, proteinPer100g: 8.0, carbsPer100g: 25.0, fatPer100g: 17.0,
              fiberPer100g: 2.5, source: .verified),
        .init(id: "innout_protein_style_double", name: "In-N-Out Double-Double Protein Style", category: .prepared, preparation: .other,
              caloriesPer100g: 224, proteinPer100g: 15.6, carbsPer100g: 5.1, fatPer100g: 16.5,
              fiberPer100g: 1.1, source: .verified),

        // MARK: - Chick-fil-A (chick-fil-a.com/nutrition-allergens, captured 2025-11)
        .init(id: "cfa_chicken_sandwich", name: "Chick-fil-A Chicken Sandwich", category: .prepared, preparation: .other,
              caloriesPer100g: 250, proteinPer100g: 15.0, carbsPer100g: 25.0, fatPer100g: 10.0,
              fiberPer100g: 1.5, source: .verified),
        .init(id: "cfa_grilled_chicken_sandwich", name: "Chick-fil-A Grilled Chicken Sandwich", category: .prepared, preparation: .other,
              caloriesPer100g: 175, proteinPer100g: 16.0, carbsPer100g: 17.0, fatPer100g: 4.0,
              fiberPer100g: 1.5, source: .verified),
        .init(id: "cfa_spicy_chicken_sandwich", name: "Chick-fil-A Spicy Chicken Sandwich", category: .prepared, preparation: .other,
              caloriesPer100g: 264, proteinPer100g: 14.7, carbsPer100g: 24.5, fatPer100g: 11.7,
              fiberPer100g: 1.5, source: .verified),
        .init(id: "cfa_nuggets_8ct", name: "Chick-fil-A Nuggets (8-ct)", category: .protein, preparation: .other,
              caloriesPer100g: 274, proteinPer100g: 25.0, carbsPer100g: 9.4, fatPer100g: 14.8,
              fiberPer100g: 0.4, source: .verified),
        .init(id: "cfa_grilled_nuggets_8ct", name: "Chick-fil-A Grilled Nuggets (8-ct)", category: .protein, preparation: .other,
              caloriesPer100g: 130, proteinPer100g: 25.0, carbsPer100g: 1.0, fatPer100g: 3.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "cfa_waffle_fries_medium", name: "Chick-fil-A Waffle Fries", category: .prepared, preparation: .other,
              caloriesPer100g: 311, proteinPer100g: 3.7, carbsPer100g: 34.1, fatPer100g: 17.8,
              fiberPer100g: 4.4, source: .verified),
        .init(id: "cfa_cobb_salad", name: "Chick-fil-A Cobb Salad (no dressing)", category: .prepared, preparation: .other,
              caloriesPer100g: 116, proteinPer100g: 11.0, carbsPer100g: 4.0, fatPer100g: 7.0,
              fiberPer100g: 1.5, source: .verified),

        // MARK: - Chipotle (chipotle.com/nutrition-calculator, captured 2025-11)
        .init(id: "chipotle_chicken_4oz", name: "Chipotle Chicken (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 165, proteinPer100g: 28.6, carbsPer100g: 0, fatPer100g: 6.3,
              fiberPer100g: 0, source: .verified),
        .init(id: "chipotle_steak_4oz", name: "Chipotle Steak (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 132, proteinPer100g: 22.0, carbsPer100g: 1.7, fatPer100g: 5.3,
              fiberPer100g: 0, source: .verified),
        .init(id: "chipotle_barbacoa_4oz", name: "Chipotle Barbacoa (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 150, proteinPer100g: 24.0, carbsPer100g: 1.7, fatPer100g: 5.7,
              fiberPer100g: 0, source: .verified),
        .init(id: "chipotle_carnitas_4oz", name: "Chipotle Carnitas (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 187, proteinPer100g: 24.0, carbsPer100g: 0, fatPer100g: 10.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "chipotle_sofritas_4oz", name: "Chipotle Sofritas (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 132, proteinPer100g: 7.6, carbsPer100g: 8.5, fatPer100g: 8.0,
              fiberPer100g: 3.4, source: .verified),
        .init(id: "chipotle_white_rice", name: "Chipotle White Rice (4 oz)", category: .grain, preparation: .other,
              caloriesPer100g: 187, proteinPer100g: 3.4, carbsPer100g: 35.6, fatPer100g: 3.4,
              fiberPer100g: 0, source: .verified),
        .init(id: "chipotle_brown_rice", name: "Chipotle Brown Rice (4 oz)", category: .grain, preparation: .other,
              caloriesPer100g: 175, proteinPer100g: 4.2, carbsPer100g: 32.2, fatPer100g: 3.4,
              fiberPer100g: 2.5, source: .verified),
        .init(id: "chipotle_black_beans", name: "Chipotle Black Beans (4 oz)", category: .protein, preparation: .other,
              caloriesPer100g: 109, proteinPer100g: 7.6, carbsPer100g: 19.5, fatPer100g: 1.3,
              fiberPer100g: 7.6, source: .verified),

        // MARK: - Starbucks (starbucks.com/menu/drinks, captured 2025-11; values per 100 g of finished drink)
        .init(id: "sbux_caffe_latte_grande_2pct", name: "Starbucks Caffè Latte (Grande, 2%)", category: .dairy, preparation: .other,
              caloriesPer100g: 38, proteinPer100g: 2.5, carbsPer100g: 3.7, fatPer100g: 1.4,
              fiberPer100g: 0, source: .verified),
        .init(id: "sbux_cappuccino_grande_2pct", name: "Starbucks Cappuccino (Grande, 2%)", category: .dairy, preparation: .other,
              caloriesPer100g: 27, proteinPer100g: 1.8, carbsPer100g: 2.7, fatPer100g: 1.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "sbux_americano_grande", name: "Starbucks Caffè Americano (Grande)", category: .prepared, preparation: .other,
              caloriesPer100g: 2, proteinPer100g: 0.2, carbsPer100g: 0, fatPer100g: 0,
              fiberPer100g: 0, source: .verified),
        .init(id: "sbux_pumpkin_spice_latte_grande", name: "Starbucks Pumpkin Spice Latte (Grande, 2%)", category: .dairy, preparation: .other,
              caloriesPer100g: 80, proteinPer100g: 2.0, carbsPer100g: 12.7, fatPer100g: 2.4,
              fiberPer100g: 0.2, source: .verified),
        .init(id: "sbux_strawberry_acai_refresher_grande", name: "Starbucks Strawberry Açaí Refresher (Grande)", category: .fruit, preparation: .other,
              caloriesPer100g: 17, proteinPer100g: 0, carbsPer100g: 4.4, fatPer100g: 0,
              fiberPer100g: 0.2, source: .verified),
        .init(id: "sbux_protein_box_eggs_cheese", name: "Starbucks Eggs & Cheese Protein Box", category: .prepared, preparation: .other,
              caloriesPer100g: 196, proteinPer100g: 12.5, carbsPer100g: 14.4, fatPer100g: 10.4,
              fiberPer100g: 1.9, source: .verified),

        // MARK: - McDonald's (mcdonalds.com/us/en-us/about-our-food.html, captured 2025-11)
        .init(id: "mcd_big_mac", name: "McDonald's Big Mac", category: .prepared, preparation: .other,
              caloriesPer100g: 257, proteinPer100g: 12.1, carbsPer100g: 21.2, fatPer100g: 14.5,
              fiberPer100g: 1.8, source: .verified),
        .init(id: "mcd_quarter_pounder", name: "McDonald's Quarter Pounder with Cheese", category: .prepared, preparation: .other,
              caloriesPer100g: 244, proteinPer100g: 14.7, carbsPer100g: 17.9, fatPer100g: 12.8,
              fiberPer100g: 1.7, source: .verified),
        .init(id: "mcd_chicken_mcnuggets_10ct", name: "McDonald's Chicken McNuggets (10-ct)", category: .protein, preparation: .other,
              caloriesPer100g: 281, proteinPer100g: 14.5, carbsPer100g: 17.5, fatPer100g: 17.5,
              fiberPer100g: 0.9, source: .verified),
        .init(id: "mcd_world_famous_fries_medium", name: "McDonald's World Famous Fries (Medium)", category: .prepared, preparation: .other,
              caloriesPer100g: 320, proteinPer100g: 4.4, carbsPer100g: 41.3, fatPer100g: 15.0,
              fiberPer100g: 3.8, source: .verified),
        .init(id: "mcd_egg_mcmuffin", name: "McDonald's Egg McMuffin", category: .prepared, preparation: .other,
              caloriesPer100g: 232, proteinPer100g: 14.3, carbsPer100g: 26.5, fatPer100g: 8.2,
              fiberPer100g: 1.6, source: .verified),

        // MARK: - Costco / Kirkland Signature staples (kirklandsignature.com + USDA SR Legacy)
        .init(id: "kirkland_rotisserie_chicken", name: "Kirkland Rotisserie Chicken", category: .protein, preparation: .cooked,
              caloriesPer100g: 190, proteinPer100g: 27.0, carbsPer100g: 0, fatPer100g: 9.0,
              fiberPer100g: 0, source: .verified),
        .init(id: "kirkland_organic_eggs", name: "Kirkland Organic Eggs (large, whole)", category: .protein, preparation: .other,
              caloriesPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5,
              fiberPer100g: 0, source: .verified),
        .init(id: "kirkland_almond_milk_unsweetened", name: "Kirkland Almond Milk (Unsweetened)", category: .dairy, preparation: .other,
              caloriesPer100g: 13, proteinPer100g: 0.4, carbsPer100g: 0.4, fatPer100g: 1.3,
              fiberPer100g: 0.4, source: .verified),
        .init(id: "kirkland_whey_protein_chocolate", name: "Kirkland Whey Protein (Chocolate)", category: .protein, preparation: .other,
              caloriesPer100g: 365, proteinPer100g: 73.2, carbsPer100g: 12.2, fatPer100g: 2.4,
              fiberPer100g: 2.4, source: .verified),
        .init(id: "kirkland_kettle_chips", name: "Kirkland Kettle Chips", category: .prepared, preparation: .other,
              caloriesPer100g: 536, proteinPer100g: 7.1, carbsPer100g: 60.7, fatPer100g: 28.6,
              fiberPer100g: 5.4, source: .verified),

        // MARK: - Costco food court (costco.com/food-court)
        .init(id: "costco_hot_dog", name: "Costco Hot Dog & Drink Combo", category: .prepared, preparation: .other,
              caloriesPer100g: 245, proteinPer100g: 8.2, carbsPer100g: 22.0, fatPer100g: 13.6,
              fiberPer100g: 1.2, source: .verified),
        .init(id: "costco_pizza_slice_cheese", name: "Costco Pizza Slice (Cheese)", category: .prepared, preparation: .other,
              caloriesPer100g: 282, proteinPer100g: 13.4, carbsPer100g: 36.5, fatPer100g: 9.5,
              fiberPer100g: 2.0, source: .verified),
        .init(id: "costco_chicken_bake", name: "Costco Chicken Bake", category: .prepared, preparation: .other,
              caloriesPer100g: 235, proteinPer100g: 14.5, carbsPer100g: 21.2, fatPer100g: 10.0,
              fiberPer100g: 1.7, source: .verified),

        // MARK: - Trader Joe's frequent items (traderjoes.com)
        .init(id: "tj_mandarin_orange_chicken", name: "Trader Joe's Mandarin Orange Chicken", category: .prepared, preparation: .cooked,
              caloriesPer100g: 198, proteinPer100g: 13.5, carbsPer100g: 19.5, fatPer100g: 7.5,
              fiberPer100g: 1.0, source: .verified),
        .init(id: "tj_cauliflower_gnocchi", name: "Trader Joe's Cauliflower Gnocchi", category: .vegetable, preparation: .cooked,
              caloriesPer100g: 91, proteinPer100g: 1.8, carbsPer100g: 19.1, fatPer100g: 1.3,
              fiberPer100g: 1.8, source: .verified),
        .init(id: "tj_dark_chocolate_pb_cups", name: "Trader Joe's Dark Chocolate Peanut Butter Cups", category: .prepared, preparation: .other,
              caloriesPer100g: 538, proteinPer100g: 11.5, carbsPer100g: 42.3, fatPer100g: 38.5,
              fiberPer100g: 3.8, source: .verified),

        // MARK: - Sweetgreen popular (sweetgreen.com — nutrition guide)
        .init(id: "sweetgreen_harvest_bowl", name: "Sweetgreen Harvest Bowl", category: .prepared, preparation: .other,
              caloriesPer100g: 133, proteinPer100g: 5.6, carbsPer100g: 17.0, fatPer100g: 5.2,
              fiberPer100g: 2.4, source: .verified),
        .init(id: "sweetgreen_kale_caesar", name: "Sweetgreen Kale Caesar", category: .prepared, preparation: .other,
              caloriesPer100g: 165, proteinPer100g: 7.2, carbsPer100g: 6.6, fatPer100g: 12.4,
              fiberPer100g: 2.0, source: .verified),

        // MARK: - Subway (subway.com)
        .init(id: "subway_turkey_breast_6in", name: "Subway Turkey Breast (6-inch)", category: .prepared, preparation: .other,
              caloriesPer100g: 145, proteinPer100g: 9.6, carbsPer100g: 19.5, fatPer100g: 3.0,
              fiberPer100g: 2.2, source: .verified),
        .init(id: "subway_meatball_marinara_6in", name: "Subway Meatball Marinara (6-inch)", category: .prepared, preparation: .other,
              caloriesPer100g: 220, proteinPer100g: 9.6, carbsPer100g: 23.7, fatPer100g: 9.4,
              fiberPer100g: 2.3, source: .verified)
    ]
}
