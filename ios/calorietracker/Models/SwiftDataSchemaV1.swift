import Foundation
import SwiftData

// MARK: - FoodEntryModel

/// SwiftData model mirroring `FoodEntry`. Enums stored as raw `String` values;
/// computed properties re-wrap them for typed access. `servingUnitOptions` is
/// JSON-encoded because CloudKit cannot store arrays of structs directly.
///
/// CloudKit constraints applied throughout:
/// - Every stored property is either Optional or has a default value.
/// - `@Attribute(.unique)` is used only on primary IDs (CloudKit can't enforce
///   cross-device uniqueness, but the attribute still gives SwiftData a fetch
///   hint and keeps local inserts idempotent during migration).
/// - No relationships in v1 — add them in a later schema version with an
///   accompanying `MigrationStage`.
@Model
final class FoodEntryModel {
    // MARK: Identity

    @Attribute(.unique) var id: UUID = UUID()

    // MARK: Core nutrition

    var name: String = ""
    var calories: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    var timestamp: Date = Date()

    // MARK: Media

    /// Filename (not full path) under Application Support/fudai-food-images/.
    /// The raw image bytes are never stored in SwiftData — same convention as
    /// the UserDefaults layer.
    var imageFilename: String?
    var emoji: String?

    // MARK: Classification — stored as rawValue strings

    /// Backing store for `source`. Always set; default keeps old rows valid.
    var sourceRaw: String = FoodSource.manual.rawValue

    /// Backing store for `mealType`.
    var mealTypeRaw: String = MealType.other.rawValue

    // MARK: Micronutrients (all optional — nil when unavailable)

    var sugar: Double?
    var addedSugar: Double?
    var fiber: Double?
    var saturatedFat: Double?
    var monounsaturatedFat: Double?
    var polyunsaturatedFat: Double?
    var cholesterol: Double?
    var sodium: Double?
    var potassium: Double?
    var servingSizeGrams: Double?

    // MARK: Serving unit selection

    /// JSON-encoded `[ServingUnitOption]`. CloudKit doesn't support array-of-struct
    /// fields, so we serialise to a JSON string and decode on read.
    var servingUnitOptionsJSON: String?
    var selectedServingUnit: String?
    var selectedServingQuantity: Double?

    // MARK: Computed wrappers

    /// Typed accessor for `sourceRaw`. Falls back to `.manual` for unknown raw values.
    var source: FoodSource {
        FoodSource(rawValue: sourceRaw) ?? .manual
    }

    /// Typed accessor for `mealTypeRaw`. Falls back to `.other` for unknown raw values.
    var mealType: MealType {
        MealType(rawValue: mealTypeRaw) ?? .other
    }

    /// Decoded serving unit options. Returns an empty array when the JSON is absent
    /// or malformed — same default the `FoodEntry` struct uses.
    var servingUnitOptions: [ServingUnitOption] {
        guard let json = servingUnitOptionsJSON,
              let data = json.data(using: .utf8),
              let options = try? JSONDecoder().decode([ServingUnitOption].self, from: data)
        else { return [] }
        return options
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        timestamp: Date = Date(),
        imageFilename: String? = nil,
        emoji: String? = nil,
        sourceRaw: String = FoodSource.manual.rawValue,
        mealTypeRaw: String = MealType.other.rawValue,
        sugar: Double? = nil,
        addedSugar: Double? = nil,
        fiber: Double? = nil,
        saturatedFat: Double? = nil,
        monounsaturatedFat: Double? = nil,
        polyunsaturatedFat: Double? = nil,
        cholesterol: Double? = nil,
        sodium: Double? = nil,
        potassium: Double? = nil,
        servingSizeGrams: Double? = nil,
        servingUnitOptionsJSON: String? = nil,
        selectedServingUnit: String? = nil,
        selectedServingQuantity: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.timestamp = timestamp
        self.imageFilename = imageFilename
        self.emoji = emoji
        self.sourceRaw = sourceRaw
        self.mealTypeRaw = mealTypeRaw
        self.sugar = sugar
        self.addedSugar = addedSugar
        self.fiber = fiber
        self.saturatedFat = saturatedFat
        self.monounsaturatedFat = monounsaturatedFat
        self.polyunsaturatedFat = polyunsaturatedFat
        self.cholesterol = cholesterol
        self.sodium = sodium
        self.potassium = potassium
        self.servingSizeGrams = servingSizeGrams
        self.servingUnitOptionsJSON = servingUnitOptionsJSON
        self.selectedServingUnit = selectedServingUnit
        self.selectedServingQuantity = selectedServingQuantity
    }
}

// MARK: - UserProfileModel

/// SwiftData model mirroring `UserProfile`. A single record per device —
/// the migration agent writes one row keyed by a stable sentinel UUID.
/// Enum-typed fields use rawValue strings for the same CloudKit reason as
/// `FoodEntryModel`. Optional fields preserve the exact nullability of the
/// original struct so nil-default semantics stay consistent.
@Model
final class UserProfileModel {
    // MARK: Identity

    /// Stable sentinel — migration agent always upserts using this fixed value
    /// so there is never more than one profile row in the store.
    @Attribute(.unique) var id: UUID = UUID()

    // MARK: Personal info

    var name: String?
    /// `Gender.rawValue` — default "male" matches `UserProfile.default`.
    var genderRaw: String = Gender.male.rawValue
    var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var heightCm: Double = 175.0
    var weightKg: Double = 70.0

    // MARK: Goals & activity

    /// `ActivityLevel.rawValue`
    var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    /// `WeightGoal.rawValue`
    var goalRaw: String = WeightGoal.maintain.rawValue
    var bodyFatPercentage: Double?
    var goalBodyFatPercentage: Double?
    /// Nil = treat as true (same semantics as `UserProfile.useBodyFatInBMR`).
    var useBodyFatInBMR: Bool?
    var weeklyChangeKg: Double?
    var goalWeightKg: Double?

    // MARK: Custom macro overrides

    var customCalories: Int?
    var customProtein: Int?
    var customFat: Int?
    var customCarbs: Int?
    /// `AutoBalanceMacro.rawValue` — nil when auto-balance is not active.
    var autoBalanceMacroRaw: String?

    // MARK: Computed wrappers

    var gender: Gender {
        Gender(rawValue: genderRaw) ?? .male
    }

    var activityLevel: ActivityLevel {
        ActivityLevel(rawValue: activityLevelRaw) ?? .moderate
    }

    var goal: WeightGoal {
        WeightGoal(rawValue: goalRaw) ?? .maintain
    }

    var autoBalanceMacro: AutoBalanceMacro? {
        guard let raw = autoBalanceMacroRaw else { return nil }
        return AutoBalanceMacro(rawValue: raw)
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String? = nil,
        genderRaw: String = Gender.male.rawValue,
        birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
        heightCm: Double = 175.0,
        weightKg: Double = 70.0,
        activityLevelRaw: String = ActivityLevel.moderate.rawValue,
        goalRaw: String = WeightGoal.maintain.rawValue,
        bodyFatPercentage: Double? = nil,
        goalBodyFatPercentage: Double? = nil,
        useBodyFatInBMR: Bool? = nil,
        weeklyChangeKg: Double? = nil,
        goalWeightKg: Double? = nil,
        customCalories: Int? = nil,
        customProtein: Int? = nil,
        customFat: Int? = nil,
        customCarbs: Int? = nil,
        autoBalanceMacroRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.genderRaw = genderRaw
        self.birthday = birthday
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevelRaw = activityLevelRaw
        self.goalRaw = goalRaw
        self.bodyFatPercentage = bodyFatPercentage
        self.goalBodyFatPercentage = goalBodyFatPercentage
        self.useBodyFatInBMR = useBodyFatInBMR
        self.weeklyChangeKg = weeklyChangeKg
        self.goalWeightKg = goalWeightKg
        self.customCalories = customCalories
        self.customProtein = customProtein
        self.customFat = customFat
        self.customCarbs = customCarbs
        self.autoBalanceMacroRaw = autoBalanceMacroRaw
    }
}

// MARK: - WeightEntryModel

/// SwiftData model mirroring `WeightEntry`. Field names and types match exactly
/// so the migration agent can copy `entry.weightKg` → `model.weightKg` without
/// any mapping layer.
@Model
final class WeightEntryModel {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0.0

    init(id: UUID = UUID(), date: Date = Date(), weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: - BodyFatEntryModel

/// SwiftData model mirroring `BodyFatEntry`. Fraction stored as-is (0.0–1.0),
/// same convention as the struct and `UserProfile.bodyFatPercentage`.
@Model
final class BodyFatEntryModel {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    /// Fraction in [0.0, 1.0] — multiply by 100 for display.
    var bodyFatFraction: Double = 0.0

    init(id: UUID = UUID(), date: Date = Date(), bodyFatFraction: Double) {
        self.id = id
        self.date = date
        self.bodyFatFraction = bodyFatFraction
    }
}

// MARK: - FavoriteModel

/// SwiftData model for a single favorited food item. The `id` field is the
/// `FoodDatabaseItem.id` string (e.g. an Open Food Facts barcode or a custom
/// UUID string). `addedAt` preserves insertion order for the "newest first"
/// display in `FavoritesStore`.
@Model
final class FavoriteModel {
    /// `FoodDatabaseItem.id` — unique per food item, not a UUID.
    @Attribute(.unique) var id: String = ""
    var addedAt: Date = Date()

    init(id: String, addedAt: Date = Date()) {
        self.id = id
        self.addedAt = addedAt
    }
}

// MARK: - VersionedSchema (v1 lock)

/// V1 schema lock. Every `@Model` type in the app is registered here.
///
/// Migration rule:
///   - To add a field: add a new `BulkAISchemaV2` that includes the changed model
///     type and a `MigrationStage.lightweight(fromVersion:toVersion:)` between v1
///     and v2. Never remove or rename a field without a migration stage.
///   - To add a model: add a new schema version even if the change is additive —
///     CloudKit synced containers require explicit version bumps.
enum BulkAISchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FoodEntryModel.self,
            UserProfileModel.self,
            WeightEntryModel.self,
            BodyFatEntryModel.self,
            FavoriteModel.self,
        ]
    }
}

/// Migration plan. `stages` is empty in v1 — there is no previous schema to
/// migrate from. Future versions append a `MigrationStage` between each pair of
/// adjacent schema versions.
enum BulkAIMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BulkAISchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
