import Foundation
import SwiftData

/// One-shot migration from the legacy UserDefaults+JSON storage layer into
/// SwiftData. Runs at most once per install — subsequent launches are no-ops.
///
/// The legacy UserDefaults blobs are NOT deleted by this migration. They
/// remain as a fallback so the existing stores (FoodStore, WeightStore,
/// BodyFatStore, FavoritesStore) keep working unchanged through the P20
/// release cycle. P22 will cut views over to SwiftData and remove the
/// legacy stores then.
enum SwiftDataMigration {

    // MARK: - UserDefaults keys (legacy sources)

    private enum LegacyKey {
        static let foodEntries    = "foodEntries"
        static let weightEntries  = "weightEntries"
        static let bodyFatEntries = "bodyFatEntries"
        static let foodFavorites  = "foodFavorites"
        static let userProfile    = "userProfile"
    }

    // MARK: - Migration flag

    private static let migrationCompleteKey = "swiftDataMigrationV1Complete"

    /// `true` if the migration has already run on this install.
    static var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationCompleteKey)
    }

    // MARK: - Entry point

    /// Run the migration if it hasn't already been completed. Idempotent —
    /// safe to call on every app launch. Returns a summary describing what
    /// was migrated (or `.alreadyMigrated`).
    @MainActor
    static func runIfNeeded(into container: ModelContainer) -> MigrationResult {
        guard !hasMigrated else { return .alreadyMigrated }

        let context = container.mainContext

        let foodCount     = migrateFoodEntries(into: context)
        let weightCount   = migrateWeightEntries(into: context)
        let bodyFatCount  = migrateBodyFatEntries(into: context)
        let favCount      = migrateFavorites(into: context)
        let profileMigrated = migrateUserProfile(into: context)

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: migrationCompleteKey)
            return .completed(
                food: foodCount,
                weight: weightCount,
                bodyFat: bodyFatCount,
                favorites: favCount,
                profileMigrated: profileMigrated
            )
        } catch {
            return .failed(error: error)
        }
    }

    // MARK: - Sub-steps

    /// Read `[FoodEntry]` from UserDefaults, create `FoodEntryModel` rows.
    /// Returns the number of rows inserted. Returns 0 on decode failure
    /// (user had no legacy food data) without failing the whole migration.
    private static func migrateFoodEntries(into context: ModelContext) -> Int {
        guard
            let data = UserDefaults.standard.data(forKey: LegacyKey.foodEntries),
            let entries = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return 0 }

        let encoder = JSONEncoder()
        for entry in entries {
            // Re-encode servingUnitOptions as a JSON string so the value type
            // doesn't require a SwiftData relationship — also cheaper to store.
            let servingUnitJSON: String? = {
                guard !entry.servingUnitOptions.isEmpty,
                      let data = try? encoder.encode(entry.servingUnitOptions)
                else { return nil }
                return String(data: data, encoding: .utf8)
            }()

            let model = FoodEntryModel(
                id: entry.id,
                name: entry.name,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                timestamp: entry.timestamp,
                // imageData is intentionally NOT migrated — only the filename
                // survives so the JPEG on disk is the single source of truth.
                imageFilename: entry.imageFilename,
                emoji: entry.emoji,
                sourceRaw: entry.source.rawValue,
                mealTypeRaw: entry.mealType.rawValue,
                sugar: entry.sugar,
                addedSugar: entry.addedSugar,
                fiber: entry.fiber,
                saturatedFat: entry.saturatedFat,
                monounsaturatedFat: entry.monounsaturatedFat,
                polyunsaturatedFat: entry.polyunsaturatedFat,
                cholesterol: entry.cholesterol,
                sodium: entry.sodium,
                potassium: entry.potassium,
                servingSizeGrams: entry.servingSizeGrams,
                servingUnitOptionsJSON: servingUnitJSON,
                selectedServingUnit: entry.selectedServingUnit,
                selectedServingQuantity: entry.selectedServingQuantity
            )
            context.insert(model)
        }
        return entries.count
    }

    /// Read `[WeightEntry]` from UserDefaults, create `WeightEntryModel` rows.
    /// Returns 0 on decode failure without failing the whole migration.
    private static func migrateWeightEntries(into context: ModelContext) -> Int {
        guard
            let data = UserDefaults.standard.data(forKey: LegacyKey.weightEntries),
            let entries = try? JSONDecoder().decode([WeightEntry].self, from: data)
        else { return 0 }

        for entry in entries {
            let model = WeightEntryModel(
                id: entry.id,
                date: entry.date,
                weightKg: entry.weightKg
            )
            context.insert(model)
        }
        return entries.count
    }

    /// Read `[BodyFatEntry]` from UserDefaults, create `BodyFatEntryModel` rows.
    /// Returns 0 on decode failure without failing the whole migration.
    private static func migrateBodyFatEntries(into context: ModelContext) -> Int {
        guard
            let data = UserDefaults.standard.data(forKey: LegacyKey.bodyFatEntries),
            let entries = try? JSONDecoder().decode([BodyFatEntry].self, from: data)
        else { return 0 }

        for entry in entries {
            let model = BodyFatEntryModel(
                id: entry.id,
                date: entry.date,
                bodyFatFraction: entry.bodyFatFraction
            )
            context.insert(model)
        }
        return entries.count
    }

    /// Read `[String]` (ordered ID list) from UserDefaults, create
    /// `FavoriteModel` rows — one per ID. Legacy storage tracked only IDs, not
    /// an `addedAt` timestamp, so `addedAt` is set to `.now` for every row.
    /// Returns 0 on decode failure without failing the whole migration.
    private static func migrateFavorites(into context: ModelContext) -> Int {
        guard
            let data = UserDefaults.standard.data(forKey: LegacyKey.foodFavorites),
            let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return 0 }

        let now = Date.now
        for id in ids {
            let model = FavoriteModel(
                id: id,
                addedAt: now
            )
            context.insert(model)
        }
        return ids.count
    }

    /// Read `UserProfile` from UserDefaults, create a single `UserProfileModel`
    /// row. Returns `true` if a profile was migrated, `false` if none existed.
    private static func migrateUserProfile(into context: ModelContext) -> Bool {
        guard
            let data = UserDefaults.standard.data(forKey: LegacyKey.userProfile),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return false }

        let model = UserProfileModel(
            name: profile.name,
            genderRaw: profile.gender.rawValue,
            birthday: profile.birthday,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevelRaw: profile.activityLevel.rawValue,
            goalRaw: profile.goal.rawValue,
            bodyFatPercentage: profile.bodyFatPercentage,
            goalBodyFatPercentage: profile.goalBodyFatPercentage,
            useBodyFatInBMR: profile.useBodyFatInBMR,
            weeklyChangeKg: profile.weeklyChangeKg,
            goalWeightKg: profile.goalWeightKg,
            customCalories: profile.customCalories,
            customProtein: profile.customProtein,
            customFat: profile.customFat,
            customCarbs: profile.customCarbs,
            autoBalanceMacroRaw: profile.autoBalanceMacro?.rawValue
        )
        context.insert(model)
        return true
    }

    // MARK: - Result type

    enum MigrationResult {
        case alreadyMigrated
        case completed(food: Int, weight: Int, bodyFat: Int, favorites: Int, profileMigrated: Bool)
        case failed(error: Error)

        var summary: String {
            switch self {
            case .alreadyMigrated:
                return "SwiftData migration: already complete."
            case .completed(let food, let weight, let bodyFat, let favorites, let profileMigrated):
                return "SwiftData migration: \(food) food + \(weight) weight + \(bodyFat) body-fat + \(favorites) favorites + \(profileMigrated ? "1" : "0") profile."
            case .failed(let error):
                return "SwiftData migration FAILED: \(error.localizedDescription)"
            }
        }
    }
}
