import Foundation
import SwiftData

/// Reads every persisted row into a `BackupPayload`.
///
/// Reads straight from SwiftData and UserDefaults, not through the app's stores.
/// A store shows nothing when one row fails to decode, and its food entries pull
/// every photo into memory, so neither is a safe source for a backup. Any read
/// failure throws: a backup that quietly omits a data type is worse than none.
///
/// Stays on the main actor because the `@Model` types are main-actor isolated in
/// this target, and yields between batches so the UI keeps drawing.
@MainActor
struct BackupCollector {
    let container: ModelContainer
    let environment: BackupEnvironment

    private static let batchSize = 500

    private var defaults: UserDefaults { environment.defaults }

    func collect() async throws -> BackupPayload {
        let context = ModelContext(container)
        var payload = BackupPayload()

        payload.foodEntries = try await rows(FoodEntryModel.self, in: context, Self.food)
        payload.weightEntries = try await rows(WeightEntryModel.self, in: context) {
            BackupWeightV1(id: $0.id, date: $0.date, weightKg: $0.weightKg)
        }
        payload.bodyFatEntries = try await rows(BodyFatEntryModel.self, in: context) {
            BackupBodyFatV1(id: $0.id, date: $0.date, bodyFatFraction: $0.bodyFatFraction)
        }
        payload.favorites = try await rows(FavoriteModel.self, in: context) {
            BackupFavoriteV1(id: $0.id, addedAt: $0.addedAt)
        }
        payload.profile = try readProfile(in: context)

        payload.periods = blobRows(BackupCatalog.BlobKey.periods, into: &payload)
        payload.recipes = blobRows(BackupCatalog.BlobKey.recipes, into: &payload)
        payload.measurements = blobRows(BackupCatalog.BlobKey.measurements, into: &payload)
        payload.chatMessages = blobRows(BackupCatalog.BlobKey.chat, into: &payload)
        payload.savedFoods = blobRows(BackupCatalog.BlobKey.savedFoods, into: &payload)
        payload.progressPhotos = blobRows(BackupCatalog.BlobKey.progressPhotos, into: &payload)
        payload.aiFoodCache = blobRows(BackupCatalog.BlobKey.aiFoodCache, into: &payload)

        payload.settings = BackupCatalog.readSettings(from: defaults)
        payload.rawBlobs = BackupCatalog.rawBlobKeys.compactMap { key in
            defaults.data(forKey: key).map { BackupRawBlobV1(key: key, data: $0) }
        }
        reconcileLegacyRows(in: &payload)
        return payload
    }

    // MARK: - SwiftData

    /// Fetches every row in one pass, because paging over a non-unique sort can
    /// skip or repeat rows. The count check catches a fetch that came back short.
    private func rows<Model: PersistentModel, Row>(
        _ type: Model.Type,
        in context: ModelContext,
        _ map: (Model) -> Row
    ) async throws -> [Row] {
        let descriptor = FetchDescriptor<Model>()
        do {
            let models = try context.fetch(descriptor)
            let expected = try context.fetchCount(descriptor)
            guard models.count == expected else {
                throw BackupError.storeUnreadable("\(Model.self): fetched \(models.count) of \(expected)")
            }
            var result: [Row] = []
            result.reserveCapacity(models.count)
            for (index, model) in models.enumerated() {
                result.append(map(model))
                if index % Self.batchSize == Self.batchSize - 1 { await Task.yield() }
            }
            return result
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.storeUnreadable("\(Model.self): \(error.localizedDescription)")
        }
    }

    private static func food(_ model: FoodEntryModel) -> BackupFoodV1 {
        BackupFoodV1(
            id: model.id,
            name: model.name,
            calories: model.calories,
            protein: model.protein,
            carbs: model.carbs,
            fat: model.fat,
            timestamp: model.timestamp,
            imageFilename: model.imageFilename,
            emoji: model.emoji,
            source: model.sourceRaw,
            mealType: model.mealTypeRaw,
            sugar: model.sugar,
            addedSugar: model.addedSugar,
            fiber: model.fiber,
            saturatedFat: model.saturatedFat,
            monounsaturatedFat: model.monounsaturatedFat,
            polyunsaturatedFat: model.polyunsaturatedFat,
            cholesterol: model.cholesterol,
            sodium: model.sodium,
            potassium: model.potassium,
            servingSizeGrams: model.servingSizeGrams,
            servingUnitOptions: servingUnits(model.servingUnitOptionsJSON),
            selectedServingUnit: model.selectedServingUnit,
            selectedServingQuantity: model.selectedServingQuantity
        )
    }

    private static func servingUnits(_ json: String?) -> [BackupServingUnitV1]? {
        guard let data = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([BackupServingUnitV1].self, from: data)
    }

    /// UserDefaults first: every profile write lands there, while the SwiftData
    /// copy is only mirrored once `ProfileStore` observes the change.
    private func readProfile(in context: ModelContext) throws -> BackupProfileV1? {
        if let data = defaults.data(forKey: BackupCatalog.BlobKey.profile),
           let profile = try? JSONDecoder().decode(BackupProfileV1.self, from: data) {
            return profile
        }
        do {
            return try context.fetch(FetchDescriptor<UserProfileModel>()).first.map(Self.profile)
        } catch {
            throw BackupError.storeUnreadable("profile: \(error.localizedDescription)")
        }
    }

    private static func profile(_ model: UserProfileModel) -> BackupProfileV1 {
        BackupProfileV1(
            name: model.name,
            gender: model.genderRaw,
            birthday: model.birthday,
            heightCm: model.heightCm,
            weightKg: model.weightKg,
            activityLevel: model.activityLevelRaw,
            goal: model.goalRaw,
            bodyFatPercentage: model.bodyFatPercentage,
            goalBodyFatPercentage: model.goalBodyFatPercentage,
            useBodyFatInBMR: model.useBodyFatInBMR,
            weeklyChangeKg: model.weeklyChangeKg,
            goalWeightKg: model.goalWeightKg,
            customCalories: model.customCalories,
            customProtein: model.customProtein,
            customFat: model.customFat,
            customCarbs: model.customCarbs,
            autoBalanceMacro: model.autoBalanceMacroRaw
        )
    }

    // MARK: - UserDefaults blobs

    /// Row-by-row decode. Rows that fail are counted, and survive in the raw
    /// copies, instead of taking the whole blob down with them.
    private func blobRows<Row: Decodable>(_ key: String, into payload: inout BackupPayload) -> [Row] {
        guard let data = defaults.data(forKey: key), !data.isEmpty else { return [] }
        guard let decoded = try? JSONDecoder().decode([BackupLossyRow<Row>].self, from: data) else {
            payload.undecodableRows[key] = 1
            return []
        }
        let rows = decoded.compactMap(\.value)
        if rows.count < decoded.count {
            payload.undecodableRows[key] = decoded.count - rows.count
        }
        return rows
    }

    // MARK: - Pre-SwiftData rows

    /// The legacy blobs are frozen at migration time, so a row found only there
    /// usually means the user deleted it later. The exception is an empty table
    /// beside a non-empty blob: `SwiftDataMigration` treats a decode failure as
    /// "no data" and still marks itself done, so those rows are the real data.
    private func reconcileLegacyRows(in payload: inout BackupPayload) {
        let legacyFood: [BackupFoodV1] = blobRows(BackupCatalog.LegacyKey.food, into: &payload)
        let legacyWeight: [BackupWeightV1] = blobRows(BackupCatalog.LegacyKey.weight, into: &payload)
        let legacyBodyFat: [BackupBodyFatV1] = blobRows(BackupCatalog.LegacyKey.bodyFat, into: &payload)
        let legacyFavorites: [String] = blobRows(BackupCatalog.LegacyKey.favorites, into: &payload)

        if payload.foodEntries.isEmpty {
            payload.foodEntries = legacyFood
        } else {
            let known = Set(payload.foodEntries.map(\.id))
            record(legacyFood.count { !known.contains($0.id) }, BackupCatalog.LegacyKey.food, in: &payload)
        }
        if payload.weightEntries.isEmpty {
            payload.weightEntries = legacyWeight
        } else {
            let known = Set(payload.weightEntries.map(\.id))
            record(legacyWeight.count { !known.contains($0.id) }, BackupCatalog.LegacyKey.weight, in: &payload)
        }
        if payload.bodyFatEntries.isEmpty {
            payload.bodyFatEntries = legacyBodyFat
        } else {
            let known = Set(payload.bodyFatEntries.map(\.id))
            record(legacyBodyFat.count { !known.contains($0.id) }, BackupCatalog.LegacyKey.bodyFat, in: &payload)
        }
        if payload.favorites.isEmpty {
            payload.favorites = legacyFavorites.map { BackupFavoriteV1(id: $0, addedAt: .now) }
        } else {
            let known = Set(payload.favorites.map(\.id))
            record(legacyFavorites.count { !known.contains($0) }, BackupCatalog.LegacyKey.favorites, in: &payload)
        }
    }

    private func record(_ count: Int, _ key: String, in payload: inout BackupPayload) {
        if count > 0 { payload.legacyOnlyRows[key] = count }
    }
}
