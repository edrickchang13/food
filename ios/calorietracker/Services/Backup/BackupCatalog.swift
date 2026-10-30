import Foundation

/// The single list of what a backup may touch outside SwiftData.
///
/// Settings are an allowlist, never a dump of UserDefaults, so nothing is
/// included by accident. Keys are plain strings instead of references to the
/// stores' constants so this file compiles against any version of those stores.
nonisolated enum BackupCatalog {

    // MARK: - JSON row blobs

    enum BlobKey {
        static let periods = "periodEntries"
        static let recipes = "userRecipes"
        static let measurements = "bodyMeasurementEntries"
        static let chat = "coachChatHistory"
        static let progressPhotos = "progressPhotos"
        static let savedFoods = "favoriteFoodEntries"
        static let aiFoodCache = "foodDatabaseAICache"
        static let profile = "userProfile"
    }

    /// Pre-SwiftData sources, left in place by `SwiftDataMigration`.
    enum LegacyKey {
        static let food = "foodEntries"
        static let weight = "weightEntries"
        static let bodyFat = "bodyFatEntries"
        static let favorites = "foodFavorites"
    }

    /// Copied verbatim into the file as a last-resort archive.
    static let rawBlobKeys = [
        BlobKey.periods, BlobKey.recipes, BlobKey.measurements, BlobKey.chat,
        BlobKey.progressPhotos, BlobKey.savedFoods, BlobKey.aiFoodCache, BlobKey.profile,
        LegacyKey.food, LegacyKey.weight, LegacyKey.bodyFat, LegacyKey.favorites,
    ]

    // MARK: - Settings allowlist

    private static let exactKeys: Set<String> = {
        var keys: Set<String> = [
            // Goals and targets
            "optionalNutrientGoals", "optionalNutrientGoalRanges", "homeTopNutrients",
            // Preferences
            "useMetric", "weekStartsOnMonday", "appearanceMode", "appThemeColor",
            "foodLogSortOrder", "lastRecentsSegment", "foodLogHiddenShortcuts", "foodLogIncompleteDays",
            // AI preferences. The keys themselves live in the Keychain and are never read.
            "selectedAIProvider", "selectedAIModel", "aiUserContext", "aiFallbackEnabled",
            "selectedFallbackAIProvider", "selectedFallbackAIModel",
            "selectedSpeechProvider", "selectedSpeechLanguage",
        ]
        keys.formUnion(mergeableKeys)
        for reminder in ["breakfast", "lunch", "dinner", "streak", "dailySummary", "weightLog", "bodyFatLog"] {
            for suffix in ["Enabled", "Hour", "Minute"] {
                keys.insert("\(reminder)Reminder\(suffix)")
            }
        }
        return keys
    }()

    /// Newer JSON values that are merged instead of skipped when the device
    /// already has a value. Arrays merge by `id`, dictionaries by key. Absent on
    /// older builds, which is fine: an absent key is not exported.
    static let mergeableKeys: Set<String> = ["customFoods", "foodServingHints", "favoriteServings"]

    /// `engine.*` holds program mode and check-in state, including any key the
    /// engine adds later.
    private static let allowedPrefixes = ["engine.", "selectedSpeechLanguage_"]

    /// Any key containing one of these is refused even if it matches above.
    private static let forbiddenFragments = ["apikey", "api_key", "token", "secret", "password", "credential"]

    static func isAllowedSetting(_ key: String) -> Bool {
        let lowered = key.lowercased()
        guard !forbiddenFragments.contains(where: lowered.contains) else { return false }
        return exactKeys.contains(key) || allowedPrefixes.contains(where: key.hasPrefix)
    }

    /// Reads every allowlisted value present in `defaults`, sorted by key.
    static func readSettings(from defaults: UserDefaults) -> [BackupSettingV1] {
        defaults.dictionaryRepresentation()
            .filter { isAllowedSetting($0.key) }
            .compactMap { setting(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    static func setting(key: String, value: Any) -> BackupSettingV1? {
        var setting = BackupSettingV1(key: key)
        switch value {
        case let string as String:
            setting.string = string
        case let data as Data:
            setting.data = data
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                setting.bool = number.boolValue
            } else if CFNumberIsFloatType(number) {
                setting.double = number.doubleValue
            } else {
                setting.int = number.intValue
            }
        default:
            return nil
        }
        return setting
    }
}

private nonisolated extension BackupSettingV1 {
    init(key: String) {
        self.init(key: key, bool: nil, int: nil, double: nil, string: nil, data: nil)
    }
}
