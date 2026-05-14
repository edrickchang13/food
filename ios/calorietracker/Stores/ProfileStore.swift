import Foundation
import SwiftData
import SwiftUI

/// Shared, observable wrapper around `UserProfile` so every view sees the same instance.
///
/// Backend: SwiftData (`UserProfileModel` via `BulkAISchemaV1`). Migrated from the
/// legacy `"userProfile"` UserDefaults JSON blob on first launch by
/// `SwiftDataMigration.runIfNeeded(into:)`.
///
/// **P22 migration:** `ProfileStore.save(_:)` is now the primary write path for
/// Settings and the HealthKit observer. The notification observer below remains as
/// a safety net for deferred callers (Onboarding, Wizards, WeightStore, BodyFatStore)
/// that still call the deprecated `UserProfile.save()` directly. Remove the observer
/// once all remaining call sites are migrated.
@Observable
@MainActor
final class ProfileStore {

    // MARK: - Private storage

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // MARK: - Public API

    /// The user's current profile. Updated by `save(_:)` and the transitional bridge observer.
    private(set) var profile: UserProfile

    // MARK: - Init

    /// Creates the store backed by `container`. The default argument constructs
    /// a production CloudKit container.
    init(container: ModelContainer = SwiftDataContainer.makeContainer()) {
        self.container = container
        if SwiftDataMigration.hasMigrated == false {
            _ = SwiftDataMigration.runIfNeeded(into: container)
        }
        self.profile = Self.loadProfile(from: container.mainContext)

        // --- Transitional bridge ---
        // Catches deferred callers that still use the deprecated `UserProfile.save()`
        // path (Onboarding, Wizards, WeightStore, BodyFatStore). Those callers write
        // to UserDefaults and post this notification; we mirror the value into SwiftData
        // and re-publish `profile`. Callers that go through `ProfileStore.save(_:)` post
        // the same notification, which causes a redundant pass through this handler —
        // that is benign: the values are identical and the SwiftData upsert is idempotent.
        // Remove this observer once all remaining callers are migrated.
        NotificationCenter.default.addObserver(
            forName: .userProfileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Prefer reading from UserDefaults since legacy callers just wrote there.
                // Fall back to SwiftData when UserDefaults has no value (e.g. after a
                // --reset-onboarding wipe that cleared the key before migration ran).
                if let legacy = UserProfile.load() {
                    Self.writeToSwiftData(legacy, into: self.container.mainContext)
                    self.profile = legacy
                } else {
                    self.profile = Self.loadProfile(from: self.container.mainContext)
                }
            }
        }
    }

    /// Reload from disk. Called externally after `--reset-onboarding` wipes UserDefaults.
    func reloadFromDisk() {
        profile = UserProfile.load() ?? Self.loadProfile(from: context)
    }

    /// Persists `profile` as the new source-of-truth.
    ///
    /// Writes through to SwiftData, updates the in-memory `profile` so SwiftUI
    /// views re-render, mirrors to UserDefaults so any read path that still calls
    /// `UserProfile.load()` sees the update, and posts `.userProfileDidChange` so
    /// `EngineState` and widget refresh observers fire without code changes.
    ///
    /// Safe to call directly on `@MainActor` — no `Task { @MainActor in }` wrapper
    /// needed at call sites.
    func save(_ profile: UserProfile) {
        // 1. Write to SwiftData — the eventual source of truth.
        Self.writeToSwiftData(profile, into: context)

        // 2. Publish in-memory so @Observable consumers re-render immediately.
        self.profile = profile

        // 3. Mirror to UserDefaults so background/launch paths that call
        //    UserProfile.load() before ProfileStore is constructed still see the
        //    current value. The deprecated `UserProfile.save()` handles this write and
        //    also posts `.userProfileDidChange`, which triggers the bridge observer and
        //    notifies EngineState + widget refresh observers — no separate post needed.
        profile.save()
    }

    // MARK: - Private helpers

    /// Fetch the single `UserProfileModel` row and map it to `UserProfile`.
    /// Returns `.default` when SwiftData has no profile row yet.
    private static func loadProfile(from context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfileModel>()
        guard let model = try? context.fetch(descriptor).first else {
            return .default
        }
        return UserProfile(
            name: model.name,
            gender: model.gender,
            birthday: model.birthday,
            heightCm: model.heightCm,
            weightKg: model.weightKg,
            activityLevel: model.activityLevel,
            goal: model.goal,
            bodyFatPercentage: model.bodyFatPercentage,
            goalBodyFatPercentage: model.goalBodyFatPercentage,
            useBodyFatInBMR: model.useBodyFatInBMR,
            weeklyChangeKg: model.weeklyChangeKg,
            goalWeightKg: model.goalWeightKg,
            customCalories: model.customCalories,
            customProtein: model.customProtein,
            customFat: model.customFat,
            customCarbs: model.customCarbs,
            autoBalanceMacro: model.autoBalanceMacro
        )
    }

    /// Upsert `profile` into SwiftData. If a row already exists its fields are
    /// updated in-place; otherwise a new row is inserted.
    private static func writeToSwiftData(_ profile: UserProfile, into context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfileModel>()
        if let existing = try? context.fetch(descriptor).first {
            existing.name = profile.name
            existing.genderRaw = profile.gender.rawValue
            existing.birthday = profile.birthday
            existing.heightCm = profile.heightCm
            existing.weightKg = profile.weightKg
            existing.activityLevelRaw = profile.activityLevel.rawValue
            existing.goalRaw = profile.goal.rawValue
            existing.bodyFatPercentage = profile.bodyFatPercentage
            existing.goalBodyFatPercentage = profile.goalBodyFatPercentage
            existing.useBodyFatInBMR = profile.useBodyFatInBMR
            existing.weeklyChangeKg = profile.weeklyChangeKg
            existing.goalWeightKg = profile.goalWeightKg
            existing.customCalories = profile.customCalories
            existing.customProtein = profile.customProtein
            existing.customFat = profile.customFat
            existing.customCarbs = profile.customCarbs
            existing.autoBalanceMacroRaw = profile.autoBalanceMacro?.rawValue
        } else {
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
        }
        try? context.save()
    }
}
