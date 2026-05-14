import Foundation

/// Writes the weekly check-in countdown to the shared App Group `UserDefaults`
/// so the `CheckInCountdownWidget` (in `FudAIWidgets`) can render the same
/// numbers iOS sees on the Strategy tab. The widget reads two keys:
///
/// - `widget_daysUntilCheckIn` (Int) — days remaining, 0 when due today
/// - `widget_checkInProgress` (Double) — 0…1 fraction of the cadence elapsed
///
/// This helper is the single source of writes from the main app. `EngineState`
/// calls `CountdownSnapshotWriter.write(...)` at the end of every refresh; the
/// widget then picks up the new values on its next timeline refresh (hourly)
/// or on the next explicit `WidgetCenter.shared.reloadTimelines(...)` call.
///
/// Keys are intentionally string literals (not symbols) because the widget
/// extension can't import this file — it duplicates the strings in
/// `FudAIWidgets/CheckInCountdownWidget.swift`. Keep both sides in sync.
enum CountdownSnapshotWriter {

    private static let daysKey = "widget_daysUntilCheckIn"
    private static let progressKey = "widget_checkInProgress"

    /// Persist the latest countdown values to the App Group UserDefaults.
    /// Safe to call from any thread — `UserDefaults` is thread-safe.
    static func write(daysUntilCheckIn: Int, progress: Double) {
        let defaults = sharedDefaults
        defaults?.set(max(0, daysUntilCheckIn), forKey: daysKey)
        defaults?.set(min(1.0, max(0.0, progress)), forKey: progressKey)
    }

    /// Wipe the countdown keys. Called from Delete All Data so the widget
    /// doesn't keep showing a stale countdown after a reset.
    static func clear() {
        let defaults = sharedDefaults
        defaults?.removeObject(forKey: daysKey)
        defaults?.removeObject(forKey: progressKey)
    }

    private static var sharedDefaults: UserDefaults? {
        // Reuse the same App Group identifier source WidgetSnapshot uses so
        // both writers stay aligned. Falls back to the hardcoded ID if the
        // Info.plist key isn't set (shouldn't happen in production builds).
        let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.apoorvdarshan.calorietracker"
        return UserDefaults(suiteName: id)
    }
}
