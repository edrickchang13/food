import Foundation
import SwiftData
import SwiftUI

/// Shared, observable wrapper around `UserProfile` so every view sees the same instance.
///
/// Backend: SwiftData (`UserProfileModel` via `BulkAISchemaV1`). Migrated from the
/// legacy `"userProfile"` UserDefaults JSON blob on first launch by
/// `SwiftDataMigration.runIfNeeded(into:)`.
///
/// **Transitional bridge (remove in P22 when all `UserProfile.save()` call sites
/// migrate to a `ProfileStore.save(_:)` API):** the existing app code paths
/// (Settings, Onboarding, Wizards, HealthKit observer) still call
/// `UserProfile.save()`, which writes to UserDefaults and posts
/// `.userProfileDidChange`. This store observes that notification, reads the
/// freshly-written UserDefaults value, mirrors it back into SwiftData, and
/// updates `profile` — keeping SwiftData as the living source of truth while the
/// legacy write path remains intact.
///
/// Public API is byte-for-byte identical to the prior UserDefaults
/// implementation so all callers need zero changes.
@Observable
@MainActor
final class ProfileStore {

    // MARK: - Private storage

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // MARK: - Public API

    /// The user's current profile. Updated whenever `.userProfileDidChange` fires.
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

        // --- Transitional bridge (see type doc-comment) ---
        // Legacy `UserProfile.save()` writes to UserDefaults then posts this
        // notification. We pick up the freshly-saved value, mirror it to
        // SwiftData, and re-publish `profile` so all observing views update.
        NotificationCenter.default.addObserver(
            forName: .userProfileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // 1. Read from UserDefaults — the legacy path wrote there.
                if let legacy = UserProfile.load() {
                    // 2. Mirror to SwiftData so it stays the source of truth.
                    Self.writeToSwiftData(legacy, into: self.container.mainContext)
                    self.profile = legacy
                } else {
                    // No UserDefaults value — re-pull directly from SwiftData.
                    self.profile = Self.loadProfile(from: self.container.mainContext)
                }
            }
        }
    }

    /// Reload from disk. Called externally after `--reset-onboarding` wipes UserDefaults.
    func reloadFromDisk() {
        profile = UserProfile.load() ?? Self.loadProfile(from: context)
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
