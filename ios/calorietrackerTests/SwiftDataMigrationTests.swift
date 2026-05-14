import Testing
import Foundation
import SwiftData
@testable import calorietracker

// MARK: - Helpers

/// Namespace for shared test helpers so individual test structs stay small.
private enum MigrationTestHelpers {

    // MARK: UserDefaults isolation

    /// Returns a fresh, empty UserDefaults suite unique to each test.
    /// Removes any stale data from a prior run before returning.
    static func freshDefaults(name: String) -> UserDefaults {
        UserDefaults(suiteName: name)!.removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name)!
    }

    // MARK: Standard keys (mirrored from the migration's private enum)

    static let foodKey    = "foodEntries"
    static let weightKey  = "weightEntries"
    static let bodyFatKey = "bodyFatEntries"
    static let favKey     = "foodFavorites"
    static let profileKey = "userProfile"
    static let flagKey    = "swiftDataMigrationV1Complete"

    // MARK: Seed helpers

    static func seedFoodEntries(_ entries: [FoodEntry], into defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(entries)
        defaults.set(data, forKey: foodKey)
    }

    static func seedWeightEntries(_ entries: [WeightEntry], into defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(entries)
        defaults.set(data, forKey: weightKey)
    }

    static func seedBodyFatEntries(_ entries: [BodyFatEntry], into defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(entries)
        defaults.set(data, forKey: bodyFatKey)
    }

    static func seedFavoriteIDs(_ ids: [String], into defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(ids)
        defaults.set(data, forKey: favKey)
    }

    static func seedProfile(_ profile: UserProfile, into defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(profile)
        defaults.set(data, forKey: profileKey)
    }

    // MARK: Minimal sample data

    static func makeFoodEntry(id: UUID = UUID(), name: String = "Test Food") -> FoodEntry {
        FoodEntry(
            id: id,
            name: name,
            calories: 300,
            protein: 25,
            carbs: 30,
            fat: 10,
            timestamp: Date(timeIntervalSinceReferenceDate: 0),
            source: .manual,
            mealType: .lunch
        )
    }

    static func makeWeightEntry(id: UUID = UUID()) -> WeightEntry {
        WeightEntry(id: id, date: Date(timeIntervalSinceReferenceDate: 0), weightKg: 75.0)
    }

    static func makeBodyFatEntry(id: UUID = UUID()) -> BodyFatEntry {
        BodyFatEntry(id: id, date: Date(timeIntervalSinceReferenceDate: 0), bodyFatFraction: 0.18)
    }

    static func makeProfile() -> UserProfile {
        UserProfile(
            name: "Test User",
            gender: .male,
            birthday: Date(timeIntervalSinceReferenceDate: 0),
            heightCm: 180,
            weightKg: 80,
            activityLevel: .active,
            goal: .lose,
            bodyFatPercentage: 0.20,
            goalBodyFatPercentage: nil,
            useBodyFatInBMR: true,
            weeklyChangeKg: 0.5,
            goalWeightKg: 75,
            customCalories: nil,
            customProtein: nil,
            customFat: nil,
            customCarbs: nil,
            autoBalanceMacro: nil
        )
    }
}

// MARK: - SwiftDataMigrationTests

/// Tests for `SwiftDataMigration.runIfNeeded(into:)`.
///
/// Each test uses an in-memory `ModelContainer` via
/// `SwiftDataContainer.makePreviewContainer()` so no data is written to disk.
/// The migration reads from `UserDefaults.standard` (matching the production
/// stores' hardcoded behavior), so tests share that defaults store. Suite is
/// `.serialized` so concurrent test execution can't have one test's seeded
/// rows leak into another test's "empty" pre-condition. P22 will inject
/// `UserDefaults` into the migration for full hermeticity.
@Suite(.serialized)
struct SwiftDataMigrationTests {

    // MARK: - Test 1: Empty-legacy round-trip

    /// With no legacy data in UserDefaults, migration should complete cleanly,
    /// report zero counts for every store, and mark itself done.
    @Test("Empty legacy store produces completed result with all-zero counts")
    @MainActor
    func emptyLegacyRoundTrip() throws {
        // Clear ALL legacy keys, not just the migration flag. The test runs
        // inside the host app's process; UserDefaults.standard may carry real
        // food / weight / profile rows from the user's actual app usage on
        // this simulator. Without clearing them the migration would happily
        // pick them up and report non-zero counts.
        let keysToClear = [
            MigrationTestHelpers.foodKey,
            MigrationTestHelpers.weightKey,
            MigrationTestHelpers.bodyFatKey,
            MigrationTestHelpers.favKey,
            MigrationTestHelpers.profileKey,
            MigrationTestHelpers.flagKey,
        ]
        // Snapshot existing values so the test can restore them on exit —
        // we don't want to wipe the user's real app data permanently.
        let snapshot = keysToClear.reduce(into: [String: Any?]()) { acc, key in
            acc[key] = UserDefaults.standard.object(forKey: key)
        }
        keysToClear.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        defer {
            keysToClear.forEach { UserDefaults.standard.removeObject(forKey: $0) }
            for (key, value) in snapshot {
                if let value { UserDefaults.standard.set(value, forKey: key) }
            }
        }

        let container = SwiftDataContainer.makePreviewContainer()
        let result = SwiftDataMigration.runIfNeeded(into: container)

        guard case .completed(let food, let weight, let bodyFat, let favorites, let profile) = result else {
            Issue.record("Expected .completed but got: \(result.summary)")
            return
        }
        #expect(food == 0)
        #expect(weight == 0)
        #expect(bodyFat == 0)
        #expect(favorites == 0)
        #expect(profile == false)
        #expect(SwiftDataMigration.hasMigrated, "hasMigrated must be true after successful run")
    }

    // MARK: - Test 2: Food round-trip

    /// Write 3 `FoodEntry` rows to UserDefaults, run migration, then fetch
    /// `FoodEntryModel` rows from the in-memory container and verify IDs and macros.
    @Test("Food entries round-trip: 3 rows with matching IDs and macros")
    @MainActor
    func foodRoundTrip() throws {
        UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey) }

        // Arrange: 3 food entries with distinct IDs and recognisable values.
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let entries = [
            MigrationTestHelpers.makeFoodEntry(id: id1, name: "Chicken"),
            MigrationTestHelpers.makeFoodEntry(id: id2, name: "Rice"),
            MigrationTestHelpers.makeFoodEntry(id: id3, name: "Broccoli"),
        ]
        MigrationTestHelpers.seedFoodEntries(entries, into: .standard)
        defer {
            UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.foodKey)
        }

        let container = SwiftDataContainer.makePreviewContainer()

        // Act
        let result = SwiftDataMigration.runIfNeeded(into: container)

        // Assert: result reports 3 food rows.
        guard case .completed(let food, _, _, _, _) = result else {
            Issue.record("Expected .completed, got: \(result.summary)")
            return
        }
        #expect(food == 3)

        // Assert: fetch from SwiftData and verify ID + macro fidelity.
        let context = container.mainContext
        let fetched = try context.fetch(FetchDescriptor<FoodEntryModel>())
        #expect(fetched.count == 3, "All 3 rows must be present in SwiftData")

        let ids = Set(fetched.map(\.id))
        #expect(ids.contains(id1))
        #expect(ids.contains(id2))
        #expect(ids.contains(id3))

        // Every migrated row should carry the same macro values as the source.
        for model in fetched {
            #expect(model.calories == 300)
            #expect(model.protein  == 25)
            #expect(model.carbs    == 30)
            #expect(model.fat      == 10)
        }

        // Verify meal-type string survived the rawValue round-trip. The model
        // exposes a computed `mealType: MealType` accessor over a stored
        // `mealTypeRaw: String`, so we compare enum-to-enum here.
        for model in fetched {
            #expect(model.mealType == MealType.lunch)
        }
    }

    // MARK: - Test 3: Idempotency

    /// Running the migration twice must return `.alreadyMigrated` on the second
    /// call and must NOT duplicate rows in SwiftData.
    @Test("Migration is idempotent: second run returns alreadyMigrated, no duplicate rows")
    @MainActor
    func idempotency() throws {
        UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey) }

        let entry = MigrationTestHelpers.makeFoodEntry()
        MigrationTestHelpers.seedFoodEntries([entry], into: .standard)
        defer {
            UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.foodKey)
        }

        let container = SwiftDataContainer.makePreviewContainer()

        // First run — should complete.
        let first = SwiftDataMigration.runIfNeeded(into: container)
        guard case .completed = first else {
            Issue.record("First run expected .completed, got: \(first.summary)")
            return
        }

        // Second run — should be a no-op.
        let second = SwiftDataMigration.runIfNeeded(into: container)
        guard case .alreadyMigrated = second else {
            Issue.record("Second run expected .alreadyMigrated, got: \(second.summary)")
            return
        }

        // Row count must not have doubled.
        let context = container.mainContext
        let fetched = try context.fetch(FetchDescriptor<FoodEntryModel>())
        #expect(fetched.count == 1, "Idempotent: must not duplicate rows on second migration call")
    }

    // MARK: - Test 4: UserProfile round-trip

    /// Write a `UserProfile` with non-default values to UserDefaults, run
    /// migration, then verify the `UserProfileModel` fields match exactly.
    @Test("UserProfile round-trip: non-default field values preserved")
    @MainActor
    func profileRoundTrip() throws {
        UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey)
        defer { UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.flagKey) }

        let profile = MigrationTestHelpers.makeProfile()
        MigrationTestHelpers.seedProfile(profile, into: .standard)
        defer {
            UserDefaults.standard.removeObject(forKey: MigrationTestHelpers.profileKey)
        }

        let container = SwiftDataContainer.makePreviewContainer()

        // Act
        let result = SwiftDataMigration.runIfNeeded(into: container)

        guard case .completed(_, _, _, _, let profileMigrated) = result else {
            Issue.record("Expected .completed, got: \(result.summary)")
            return
        }
        #expect(profileMigrated, "profileMigrated must be true when a profile exists")

        // Assert: fetch the single profile model and verify field values.
        let context = container.mainContext
        let fetched = try context.fetch(FetchDescriptor<UserProfileModel>())
        #expect(fetched.count == 1, "Exactly one UserProfileModel must exist after migration")

        let model = fetched[0]
        // The model exposes computed enum accessors (`gender: Gender`,
        // `activityLevel: ActivityLevel`, `goal: WeightGoal`) over their
        // stored `*Raw: String` siblings, so assertions compare enum-to-enum.
        #expect(model.name         == "Test User")
        #expect(model.gender       == Gender.male)
        #expect(model.heightCm     == 180)
        #expect(model.weightKg     == 80)
        #expect(model.activityLevel == ActivityLevel.active)
        #expect(model.goal         == WeightGoal.lose)
        #expect(model.bodyFatPercentage == 0.20)
        #expect(model.useBodyFatInBMR   == true)
        #expect(model.weeklyChangeKg    == 0.5)
        #expect(model.goalWeightKg      == 75)
    }
}
