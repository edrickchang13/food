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

    // MARK: - Factory

    /// Convenience constructor used by every entry below. All macro values are
    /// per 100 g of edible portion. Pass `nil` for any micronutrient the chain
    /// does not publish consistently (nil is preferable to a wrong number).
    private static func chain(
        id: String,
        name: String,
        category: FoodDatabaseCategory,
        kcal: Double,
        p: Double,
        c: Double,
        f: Double,
        fiber: Double?,
        sodium: Double?,
        sugar: Double?,
        satFat: Double?
    ) -> FoodDatabaseItem {
        FoodDatabaseItem(
            id: id,
            name: name,
            category: category,
            preparation: .other,
            caloriesPer100g: kcal,
            proteinPer100g: p,
            carbsPer100g: c,
            fatPer100g: f,
            fiberPer100g: fiber,
            sodiumPer100g: sodium,
            sugarPer100g: sugar,
            saturatedFatPer100g: satFat,
            source: .verified
        )
    }

    // MARK: - Items

    static let items: [FoodDatabaseItem] = [

        // MARK: In-N-Out (innout.com/menu/nutrition-info, captured 2025-11)
        // Serving weights from published nutrition info; sodium/sugar/sat-fat divided by serving weight.
        chain(id: "innout_double_double",        name: "In-N-Out Double-Double",                  category: .prepared,
              kcal: 240,  p: 13.4, c: 11.6, f: 16.2, fiber: 0.9,
              sodium: 315, sugar: 3.0, satFat: 5.5),  // 330 g serving: 1040 mg Na, 10 g sugar, 18 g sat fat

        chain(id: "innout_cheeseburger",          name: "In-N-Out Cheeseburger",                  category: .prepared,
              kcal: 197,  p: 9.9,  c: 13.6, f: 11.8, fiber: 1.2,
              sodium: 373, sugar: 3.4, satFat: 3.0),  // 268 g serving: 1000 mg Na, 9 g sugar, 8 g sat fat

        chain(id: "innout_hamburger",             name: "In-N-Out Hamburger",                     category: .prepared,
              kcal: 169,  p: 8.7,  c: 14.0, f: 9.0,  fiber: 1.2,
              sodium: 267, sugar: 3.7, satFat: 2.1),  // 243 g serving: 650 mg Na, 9 g sugar, 5 g sat fat

        chain(id: "innout_animal_fries",          name: "In-N-Out Animal Fries",                  category: .prepared,
              kcal: 280,  p: 8.0,  c: 25.0, f: 17.0, fiber: 2.5,
              sodium: 286, sugar: 0.8, satFat: 4.6),  // 395 g serving: 1130 mg Na, 3 g sugar, 18 g sat fat

        chain(id: "innout_protein_style_double",  name: "In-N-Out Double-Double Protein Style",   category: .prepared,
              kcal: 224,  p: 15.6, c: 5.1,  f: 16.5, fiber: 1.1,
              sodium: 341, sugar: 1.6, satFat: 5.6),  // 305 g serving: 1040 mg Na, 5 g sugar, 17 g sat fat

        // MARK: Chick-fil-A (chick-fil-a.com/nutrition-allergens, captured 2025-11)
        chain(id: "cfa_chicken_sandwich",         name: "Chick-fil-A Chicken Sandwich",           category: .prepared,
              kcal: 250,  p: 15.0, c: 25.0, f: 10.0, fiber: 1.5,
              sodium: 675, sugar: 2.5, satFat: 1.0),  // 200 g serving: 1350 mg Na, 5 g sugar, 2 g sat fat

        chain(id: "cfa_grilled_chicken_sandwich", name: "Chick-fil-A Grilled Chicken Sandwich",   category: .prepared,
              kcal: 175,  p: 16.0, c: 17.0, f: 4.0,  fiber: 1.5,
              sodium: 450, sugar: 3.0, satFat: 0.5),  // 200 g serving: 900 mg Na, 6 g sugar, 1 g sat fat

        chain(id: "cfa_spicy_chicken_sandwich",   name: "Chick-fil-A Spicy Chicken Sandwich",     category: .prepared,
              kcal: 264,  p: 14.7, c: 24.5, f: 11.7, fiber: 1.5,
              sodium: 662, sugar: 2.0, satFat: 1.0),  // 204 g serving: 1350 mg Na, 4 g sugar, 2 g sat fat

        chain(id: "cfa_nuggets_8ct",              name: "Chick-fil-A Nuggets (8-ct)",             category: .protein,
              kcal: 274,  p: 25.0, c: 9.4,  f: 14.8, fiber: 0.4,
              sodium: 850, sugar: 0.9, satFat: 3.1),  // 113 g serving: 960 mg Na, 1 g sugar, 3.5 g sat fat

        chain(id: "cfa_grilled_nuggets_8ct",      name: "Chick-fil-A Grilled Nuggets (8-ct)",    category: .protein,
              kcal: 130,  p: 25.0, c: 1.0,  f: 3.0,  fiber: 0,
              sodium: 389, sugar: 0.0, satFat: 0.4),  // 113 g serving: 440 mg Na, 0 g sugar, 0.5 g sat fat

        chain(id: "cfa_waffle_fries_medium",      name: "Chick-fil-A Waffle Fries",              category: .prepared,
              kcal: 311,  p: 3.7,  c: 34.1, f: 17.8, fiber: 4.4,
              sodium: 184, sugar: 0.0, satFat: 2.0),  // 125 g serving: 230 mg Na, 0 g sugar, 2.5 g sat fat

        chain(id: "cfa_cobb_salad",               name: "Chick-fil-A Cobb Salad (no dressing)",  category: .prepared,
              kcal: 116,  p: 11.0, c: 4.0,  f: 7.0,  fiber: 1.5,
              sodium: 261, sugar: 1.2, satFat: 1.1),  // 330 g serving: 860 mg Na, 4 g sugar, 3.5 g sat fat

        // MARK: Chipotle (chipotle.com/nutrition-calculator, captured 2025-11)
        // All items published as 4 oz (113 g) portions; divide published mg/g by 1.13.
        chain(id: "chipotle_chicken_4oz",         name: "Chipotle Chicken (4 oz)",               category: .protein,
              kcal: 165,  p: 28.6, c: 0,    f: 6.3,  fiber: 0,
              sodium: 274, sugar: 0.0, satFat: 1.3),  // 310 mg Na, 0 g sugar, 1.5 g sat fat / 113 g

        chain(id: "chipotle_steak_4oz",           name: "Chipotle Steak (4 oz)",                 category: .protein,
              kcal: 132,  p: 22.0, c: 1.7,  f: 5.3,  fiber: 0,
              sodium: 314, sugar: 0.0, satFat: 1.3),  // 355 mg Na, 0 g sugar, 1.5 g sat fat / 113 g

        chain(id: "chipotle_barbacoa_4oz",        name: "Chipotle Barbacoa (4 oz)",              category: .protein,
              kcal: 150,  p: 24.0, c: 1.7,  f: 5.7,  fiber: 0,
              sodium: 469, sugar: 0.0, satFat: 1.8),  // 530 mg Na, 0 g sugar, 2.0 g sat fat / 113 g

        chain(id: "chipotle_carnitas_4oz",        name: "Chipotle Carnitas (4 oz)",              category: .protein,
              kcal: 187,  p: 24.0, c: 0,    f: 10.0, fiber: 0,
              sodium: 336, sugar: 0.0, satFat: 3.1),  // 380 mg Na, 0 g sugar, 3.5 g sat fat / 113 g

        chain(id: "chipotle_sofritas_4oz",        name: "Chipotle Sofritas (4 oz)",              category: .protein,
              kcal: 132,  p: 7.6,  c: 8.5,  f: 8.0,  fiber: 3.4,
              sodium: 478, sugar: 0.9, satFat: 0.4),  // 540 mg Na, 1 g sugar, 0.5 g sat fat / 113 g

        chain(id: "chipotle_white_rice",          name: "Chipotle White Rice (4 oz)",            category: .grain,
              kcal: 187,  p: 3.4,  c: 35.6, f: 3.4,  fiber: 0,
              sodium: 186, sugar: 0.0, satFat: 0.4),  // 210 mg Na, 0 g sugar, 0.5 g sat fat / 113 g

        chain(id: "chipotle_brown_rice",          name: "Chipotle Brown Rice (4 oz)",            category: .grain,
              kcal: 175,  p: 4.2,  c: 32.2, f: 3.4,  fiber: 2.5,
              sodium: 186, sugar: 0.0, satFat: 0.4),  // 210 mg Na, 0 g sugar, 0.5 g sat fat / 113 g

        chain(id: "chipotle_black_beans",         name: "Chipotle Black Beans (4 oz)",           category: .protein,
              kcal: 109,  p: 7.6,  c: 19.5, f: 1.3,  fiber: 7.6,
              sodium: 155, sugar: 0.0, satFat: 0.0),  // 175 mg Na, 0 g sugar, 0 g sat fat / 113 g

        // MARK: Starbucks (starbucks.com/menu/drinks, captured 2025-11)
        // Grande = 16 fl oz ≈ 473 g of finished beverage; per-100 g = published value / 4.73.
        chain(id: "sbux_caffe_latte_grande_2pct",        name: "Starbucks Caffè Latte (Grande, 2%)",              category: .dairy,
              kcal: 38,   p: 2.5,  c: 3.7,  f: 1.4,  fiber: 0,
              sodium: 32,  sugar: 3.8, satFat: 0.6),  // 150 mg Na, 18 g sugar, 3 g sat fat / 473 g

        chain(id: "sbux_cappuccino_grande_2pct",         name: "Starbucks Cappuccino (Grande, 2%)",               category: .dairy,
              kcal: 27,   p: 1.8,  c: 2.7,  f: 1.0,  fiber: 0,
              sodium: 21,  sugar: 2.5, satFat: 0.4),  // 100 mg Na, 12 g sugar, 2 g sat fat / 473 g

        chain(id: "sbux_americano_grande",               name: "Starbucks Caffè Americano (Grande)",              category: .prepared,
              kcal: 2,    p: 0.2,  c: 0,    f: 0,    fiber: 0,
              sodium: 3,   sugar: 0.0, satFat: 0.0),  // 15 mg Na, 0 g sugar, 0 g sat fat / 473 g

        chain(id: "sbux_pumpkin_spice_latte_grande",     name: "Starbucks Pumpkin Spice Latte (Grande, 2%)",      category: .dairy,
              kcal: 80,   p: 2.0,  c: 12.7, f: 2.4,  fiber: 0.2,
              sodium: 46,  sugar: 10.6, satFat: 1.3), // 220 mg Na, 50 g sugar, 6 g sat fat / 473 g

        chain(id: "sbux_strawberry_acai_refresher_grande", name: "Starbucks Strawberry Açaí Refresher (Grande)", category: .fruit,
              kcal: 17,   p: 0,    c: 4.4,  f: 0,    fiber: 0.2,
              sodium: 6,   sugar: 5.1, satFat: 0.0),  // 30 mg Na, 24 g sugar, 0 g sat fat / 473 g

        chain(id: "sbux_protein_box_eggs_cheese",        name: "Starbucks Eggs & Cheese Protein Box",            category: .prepared,
              kcal: 196,  p: 12.5, c: 14.4, f: 10.4, fiber: 1.9,
              sodium: 174, sugar: 3.8, satFat: 1.5),  // 265 g box: 460 mg Na, 10 g sugar, 4 g sat fat

        // MARK: McDonald's (mcdonalds.com/us/en-us/about-our-food.html, captured 2025-11)
        chain(id: "mcd_big_mac",                  name: "McDonald's Big Mac",                    category: .prepared,
              kcal: 257,  p: 12.1, c: 21.2, f: 14.5, fiber: 1.8,
              sodium: 491, sugar: 4.2, satFat: 4.7),  // 212 g serving: 1040 mg Na, 9 g sugar, 10 g sat fat

        chain(id: "mcd_quarter_pounder",          name: "McDonald's Quarter Pounder with Cheese", category: .prepared,
              kcal: 244,  p: 14.7, c: 17.9, f: 12.8, fiber: 1.7,
              sodium: 553, sugar: 4.0, satFat: 5.8),  // 226 g serving: 1250 mg Na, 9 g sugar, 13 g sat fat

        chain(id: "mcd_chicken_mcnuggets_10ct",   name: "McDonald's Chicken McNuggets (10-ct)",  category: .protein,
              kcal: 281,  p: 14.5, c: 17.5, f: 17.5, fiber: 0.9,
              sodium: 512, sugar: 0.0, satFat: 2.1),  // 166 g serving: 850 mg Na, 0 g sugar, 3.5 g sat fat

        chain(id: "mcd_world_famous_fries_medium", name: "McDonald's World Famous Fries (Medium)", category: .prepared,
              kcal: 320,  p: 4.4,  c: 41.3, f: 15.0, fiber: 3.8,
              sodium: 342, sugar: 0.0, satFat: 1.7),  // 117 g serving: 400 mg Na, 0 g sugar, 2 g sat fat

        chain(id: "mcd_egg_mcmuffin",             name: "McDonald's Egg McMuffin",               category: .prepared,
              kcal: 232,  p: 14.3, c: 26.5, f: 8.2,  fiber: 1.6,
              sodium: 547, sugar: 2.2, satFat: 3.6),  // 137 g serving: 750 mg Na, 3 g sugar, 5 g sat fat

        // MARK: Costco / Kirkland Signature staples (kirklandsignature.com + USDA SR Legacy, captured 2025-11)
        chain(id: "kirkland_rotisserie_chicken",   name: "Kirkland Rotisserie Chicken",           category: .protein,
              kcal: 190,  p: 27.0, c: 0,    f: 9.0,  fiber: 0,
              sodium: 550, sugar: 0.0, satFat: 2.5),  // per-100 g published directly on Costco label

        chain(id: "kirkland_organic_eggs",         name: "Kirkland Organic Eggs (large, whole)",  category: .protein,
              kcal: 143,  p: 12.6, c: 0.7,  f: 9.5,  fiber: 0,
              sodium: 140, sugar: 0.0, satFat: 2.7),  // 50 g/egg: 70 mg Na, 0 g sugar, 1.35 g sat fat

        chain(id: "kirkland_almond_milk_unsweetened", name: "Kirkland Almond Milk (Unsweetened)", category: .dairy,
              kcal: 13,   p: 0.4,  c: 0.4,  f: 1.3,  fiber: 0.4,
              sodium: 67,  sugar: 0.0, satFat: 0.0),  // 240 g serving: 160 mg Na, 0 g sugar, 0 g sat fat

        chain(id: "kirkland_whey_protein_chocolate", name: "Kirkland Whey Protein (Chocolate)",  category: .protein,
              kcal: 365,  p: 73.2, c: 12.2, f: 2.4,  fiber: 2.4,
              sodium: 447, sugar: 13.2, satFat: 2.6), // 38 g serving: 170 mg Na, 5 g sugar, 1 g sat fat

        chain(id: "kirkland_kettle_chips",         name: "Kirkland Kettle Chips",                category: .prepared,
              kcal: 536,  p: 7.1,  c: 60.7, f: 28.6, fiber: 5.4,
              sodium: 375, sugar: 3.6, satFat: 8.9),  // 28 g serving: 105 mg Na, 1 g sugar, 2.5 g sat fat

        // MARK: Costco food court (costco.com/food-court, captured 2025-11)
        chain(id: "costco_hot_dog",               name: "Costco Hot Dog & Drink Combo",          category: .prepared,
              kcal: 245,  p: 8.2,  c: 22.0, f: 13.6, fiber: 1.2,
              sodium: 658, sugar: 1.5, satFat: 3.0),  // ~266 g hot dog + bun: 1750 mg Na, 4 g sugar, 8 g sat fat

        chain(id: "costco_pizza_slice_cheese",    name: "Costco Pizza Slice (Cheese)",           category: .prepared,
              kcal: 282,  p: 13.4, c: 36.5, f: 9.5,  fiber: 2.0,
              sodium: 470, sugar: 2.5, satFat: 2.5),  // 285 g slice: 1340 mg Na, 7 g sugar, 7 g sat fat

        chain(id: "costco_chicken_bake",          name: "Costco Chicken Bake",                   category: .prepared,
              kcal: 235,  p: 14.5, c: 21.2, f: 10.0, fiber: 1.7,
              sodium: 533, sugar: 1.6, satFat: 2.2),  // 317 g item: 1690 mg Na, 5 g sugar, 7 g sat fat

        // MARK: Trader Joe's frequent items (traderjoes.com, captured 2025-11)
        chain(id: "tj_mandarin_orange_chicken",   name: "Trader Joe's Mandarin Orange Chicken",  category: .prepared,
              kcal: 198,  p: 13.5, c: 19.5, f: 7.5,  fiber: 1.0,
              sodium: 357, sugar: 12.1, satFat: 2.5), // 140 g serving: 500 mg Na, 17 g sugar, 3.5 g sat fat

        chain(id: "tj_cauliflower_gnocchi",       name: "Trader Joe's Cauliflower Gnocchi",      category: .vegetable,
              kcal: 91,   p: 1.8,  c: 19.1, f: 1.3,  fiber: 1.8,
              sodium: 307, sugar: 2.1, satFat: 0.0),  // 140 g serving: 430 mg Na, 3 g sugar, 0 g sat fat

        chain(id: "tj_dark_chocolate_pb_cups",    name: "Trader Joe's Dark Chocolate Peanut Butter Cups", category: .prepared,
              kcal: 538,  p: 11.5, c: 42.3, f: 38.5, fiber: 3.8,
              sodium: 225, sugar: 40.0, satFat: 25.0), // 40 g (2 cups): 90 mg Na, 16 g sugar, 10 g sat fat

        // MARK: Sweetgreen (sweetgreen.com/nutrition, captured 2025-11)
        chain(id: "sweetgreen_harvest_bowl",      name: "Sweetgreen Harvest Bowl",               category: .prepared,
              kcal: 133,  p: 5.6,  c: 17.0, f: 5.2,  fiber: 2.4,
              sodium: 195, sugar: 2.3, satFat: 0.5),  // ~440 g bowl: 860 mg Na, 10 g sugar, 2 g sat fat

        chain(id: "sweetgreen_kale_caesar",       name: "Sweetgreen Kale Caesar",                category: .prepared,
              kcal: 165,  p: 7.2,  c: 6.6,  f: 12.4, fiber: 2.0,
              sodium: 362, sugar: 1.3, satFat: 1.6),  // ~315 g bowl: 1140 mg Na, 4 g sugar, 5 g sat fat

        // MARK: Subway (subway.com/en-us/menunutrition, captured 2025-11)
        chain(id: "subway_turkey_breast_6in",     name: "Subway Turkey Breast (6-inch)",         category: .prepared,
              kcal: 145,  p: 9.6,  c: 19.5, f: 3.0,  fiber: 2.2,
              sodium: 456, sugar: 2.2, satFat: 0.7),  // 228 g sub: 1040 mg Na, 5 g sugar, 1.5 g sat fat

        chain(id: "subway_meatball_marinara_6in", name: "Subway Meatball Marinara (6-inch)",     category: .prepared,
              kcal: 220,  p: 9.6,  c: 23.7, f: 9.4,  fiber: 2.3,
              sodium: 340, sugar: 3.5, satFat: 2.5),  // 318 g sub: 1080 mg Na, 11 g sugar, 8 g sat fat
    ]
}
