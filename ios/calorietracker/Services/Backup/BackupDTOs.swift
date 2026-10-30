import Foundation

// Version 1 row shapes. These are frozen copies of the app's models, not the
// models themselves, so the file format holds still when a model gains a field.
//
// Key names deliberately match the app's Codable output: the same type reads a
// row straight out of a UserDefaults blob and writes one back. Enums are plain
// strings so a value from another version is carried along instead of failing
// the decode. Unknown keys are ignored by synthesized Decodable and Optional
// properties may be absent. Non-optional properties are the fields the app's own
// decoders require, which is what keeps a restored blob loadable.

nonisolated struct BackupServingUnitV1: Codable, Equatable, Sendable {
    var unit: String
    var gramsPerUnit: Double
    var quantity: Double?
}

/// A food log entry, and also a saved food in `favoriteFoodEntries`.
nonisolated struct BackupFoodV1: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var timestamp: Date
    var imageFilename: String?
    var emoji: String?
    var source: String
    var mealType: String?
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
    var servingUnitOptions: [BackupServingUnitV1]?
    var selectedServingUnit: String?
    var selectedServingQuantity: Double?
}

nonisolated struct BackupWeightV1: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var weightKg: Double
}

nonisolated struct BackupBodyFatV1: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var bodyFatFraction: Double
}

nonisolated struct BackupFavoriteV1: Codable, Equatable, Sendable {
    /// `FoodDatabaseItem.id`.
    var id: String
    var addedAt: Date
}

nonisolated struct BackupProfileV1: Codable, Equatable, Sendable {
    var name: String?
    var gender: String
    var birthday: Date
    var heightCm: Double
    var weightKg: Double
    var activityLevel: String
    var goal: String
    var bodyFatPercentage: Double?
    var goalBodyFatPercentage: Double?
    var useBodyFatInBMR: Bool?
    var weeklyChangeKg: Double?
    var goalWeightKg: Double?
    var customCalories: Int?
    var customProtein: Int?
    var customFat: Int?
    var customCarbs: Int?
    var autoBalanceMacro: String?
}

nonisolated struct BackupPeriodV1: Codable, Equatable, Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var notes: String?
}

nonisolated struct BackupRecipeIngredientV1: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
}

nonisolated struct BackupRecipeV1: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var servings: Int
    var ingredients: [BackupRecipeIngredientV1]
    var sourceURL: String?
    var notes: String?
    var createdAt: Date
}

nonisolated struct BackupMeasurementV1: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var site: String
    var valueCm: Double
    var note: String?
}

nonisolated struct BackupChatMessageV1: Codable, Equatable, Sendable {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
}

nonisolated struct BackupProgressPhotoV1: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var side: String
    var filename: String
    var weightKgAtTime: Double?
    var notes: String?
}

nonisolated struct BackupFoodCacheItemV1: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var category: String
    var preparation: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double?
    var sodiumPer100g: Double?
    var sugarPer100g: Double?
    var saturatedFatPer100g: Double?
    var source: String
}

/// One allowlisted UserDefaults value. Exactly one payload field is set.
nonisolated struct BackupSettingV1: Codable, Equatable, Sendable {
    var key: String
    var bool: Bool?
    var int: Int?
    var double: Double?
    var string: String?
    var data: Data?

    var isEmpty: Bool {
        bool == nil && int == nil && double == nil && string == nil && data == nil
    }
}

nonisolated enum BackupImageKind: String, Codable, Sendable {
    case food
    case progress
}

nonisolated struct BackupImageV1: Codable, Equatable, Sendable {
    var kind: BackupImageKind
    var filename: String
    var data: Data
}

/// A verbatim copy of a UserDefaults blob. Never read by restore: it exists so a
/// row the typed decoders could not understand still leaves the device.
nonisolated struct BackupRawBlobV1: Codable, Equatable, Sendable {
    var key: String
    var data: Data
}

/// Decodes an array element without letting one bad row fail the whole array.
nonisolated struct BackupLossyRow<Row: Decodable>: Decodable {
    let value: Row?

    init(from decoder: Decoder) {
        value = try? Row(from: decoder)
    }
}

// MARK: - Payload

/// Every row in a backup, minus photo bytes. Produced by `BackupCollector` on
/// export and by `BackupFileReader` on restore.
nonisolated struct BackupPayload: Equatable, Sendable {
    var foodEntries: [BackupFoodV1] = []
    var weightEntries: [BackupWeightV1] = []
    var bodyFatEntries: [BackupBodyFatV1] = []
    var favorites: [BackupFavoriteV1] = []
    var profile: BackupProfileV1?
    var periods: [BackupPeriodV1] = []
    var recipes: [BackupRecipeV1] = []
    var measurements: [BackupMeasurementV1] = []
    var chatMessages: [BackupChatMessageV1] = []
    var savedFoods: [BackupFoodV1] = []
    var progressPhotos: [BackupProgressPhotoV1] = []
    var aiFoodCache: [BackupFoodCacheItemV1] = []
    var settings: [BackupSettingV1] = []
    var rawBlobs: [BackupRawBlobV1] = []
    var undecodableRows: [String: Int] = [:]
    var legacyOnlyRows: [String: Int] = [:]

    /// Row counts only. Photo file counts come from the file itself.
    func rowCount(of type: BackupDataType) -> Int {
        switch type {
        case .foodEntries: foodEntries.count
        case .weightEntries: weightEntries.count
        case .bodyFatEntries: bodyFatEntries.count
        case .favorites: favorites.count
        case .profile: profile == nil ? 0 : 1
        case .periods: periods.count
        case .recipes: recipes.count
        case .measurements: measurements.count
        case .chatMessages: chatMessages.count
        case .savedFoods: savedFoods.count
        case .progressPhotos: progressPhotos.count
        case .aiFoodCache: aiFoodCache.count
        case .settings: settings.count
        case .foodImageFiles, .progressPhotoFiles: 0
        }
    }

    /// Every photo filename a row points at, by folder.
    var referencedImages: [(kind: BackupImageKind, filename: String)] {
        let food = (foodEntries + savedFoods).compactMap(\.imageFilename)
        return Set(food).map { (BackupImageKind.food, $0) }
            + Set(progressPhotos.map(\.filename)).map { (BackupImageKind.progress, $0) }
    }
}

// MARK: - Records

/// One line of a backup file.
nonisolated enum BackupRecord: Sendable {
    case header(BackupHeader)
    case food(BackupFoodV1)
    case weight(BackupWeightV1)
    case bodyFat(BackupBodyFatV1)
    case favorite(BackupFavoriteV1)
    case profile(BackupProfileV1)
    case period(BackupPeriodV1)
    case recipe(BackupRecipeV1)
    case measurement(BackupMeasurementV1)
    case chatMessage(BackupChatMessageV1)
    case savedFood(BackupFoodV1)
    case progressPhoto(BackupProgressPhotoV1)
    case aiFood(BackupFoodCacheItemV1)
    case setting(BackupSettingV1)
    case image(BackupImageV1)
    case rawBlob(BackupRawBlobV1)
    case manifest(BackupManifest)
    /// A record type from a later version of the format.
    case unknown(String)
}

nonisolated extension BackupRecord: Codable {
    private enum CodingKeys: String, CodingKey { case t, r }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try c.decode(String.self, forKey: .t)
        switch tag {
        case "header": self = .header(try c.decode(BackupHeader.self, forKey: .r))
        case "food": self = .food(try c.decode(BackupFoodV1.self, forKey: .r))
        case "weight": self = .weight(try c.decode(BackupWeightV1.self, forKey: .r))
        case "bodyFat": self = .bodyFat(try c.decode(BackupBodyFatV1.self, forKey: .r))
        case "favorite": self = .favorite(try c.decode(BackupFavoriteV1.self, forKey: .r))
        case "profile": self = .profile(try c.decode(BackupProfileV1.self, forKey: .r))
        case "period": self = .period(try c.decode(BackupPeriodV1.self, forKey: .r))
        case "recipe": self = .recipe(try c.decode(BackupRecipeV1.self, forKey: .r))
        case "measurement": self = .measurement(try c.decode(BackupMeasurementV1.self, forKey: .r))
        case "chat": self = .chatMessage(try c.decode(BackupChatMessageV1.self, forKey: .r))
        case "savedFood": self = .savedFood(try c.decode(BackupFoodV1.self, forKey: .r))
        case "progressPhoto": self = .progressPhoto(try c.decode(BackupProgressPhotoV1.self, forKey: .r))
        case "aiFood": self = .aiFood(try c.decode(BackupFoodCacheItemV1.self, forKey: .r))
        case "setting": self = .setting(try c.decode(BackupSettingV1.self, forKey: .r))
        case "image": self = .image(try c.decode(BackupImageV1.self, forKey: .r))
        case "rawBlob": self = .rawBlob(try c.decode(BackupRawBlobV1.self, forKey: .r))
        case "manifest": self = .manifest(try c.decode(BackupManifest.self, forKey: .r))
        default: self = .unknown(tag)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func put<Value: Encodable>(_ tag: String, _ value: Value) throws {
            try c.encode(tag, forKey: .t)
            try c.encode(value, forKey: .r)
        }
        switch self {
        case .header(let v): try put("header", v)
        case .food(let v): try put("food", v)
        case .weight(let v): try put("weight", v)
        case .bodyFat(let v): try put("bodyFat", v)
        case .favorite(let v): try put("favorite", v)
        case .profile(let v): try put("profile", v)
        case .period(let v): try put("period", v)
        case .recipe(let v): try put("recipe", v)
        case .measurement(let v): try put("measurement", v)
        case .chatMessage(let v): try put("chat", v)
        case .savedFood(let v): try put("savedFood", v)
        case .progressPhoto(let v): try put("progressPhoto", v)
        case .aiFood(let v): try put("aiFood", v)
        case .setting(let v): try put("setting", v)
        case .image(let v): try put("image", v)
        case .rawBlob(let v): try put("rawBlob", v)
        case .manifest(let v): try put("manifest", v)
        case .unknown(let tag): try c.encode(tag, forKey: .t)
        }
    }
}
