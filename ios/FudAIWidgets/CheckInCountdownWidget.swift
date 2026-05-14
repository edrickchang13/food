import WidgetKit
import SwiftUI

// MARK: - App Group snapshot reader

/// Reads countdown state written by the main app into the shared App Group.
/// Keys: `widget_daysUntilCheckIn` (Int) and `widget_checkInProgress` (Double).
/// Falls back to safe defaults (7 days, 0 progress) until the main app writes its first values.
enum CountdownSnapshotReader {
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.apoorvdarshan.calorietracker"
    }

    static func read() -> (days: Int, progress: Double) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let days = defaults?.integer(forKey: "widget_daysUntilCheckIn") ?? 7
        let progress = defaults?.double(forKey: "widget_checkInProgress") ?? 0
        return (days: max(0, days), progress: min(1, max(0, progress)))
    }
}

// MARK: - Timeline entry

struct CheckInCountdownEntry: TimelineEntry {
    let date: Date
    let daysRemaining: Int
    let progress: Double
}

// MARK: - Timeline provider

struct CheckInCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckInCountdownEntry {
        CheckInCountdownEntry(date: Date(), daysRemaining: 5, progress: 0.28)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInCountdownEntry) -> Void) {
        let snap = CountdownSnapshotReader.read()
        completion(CheckInCountdownEntry(date: Date(), daysRemaining: snap.days, progress: snap.progress))
    }

    /// Refresh hourly — days-remaining ticks at most once per day, but hourly
    /// polling catches midnight rollovers reliably without hammering the system.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInCountdownEntry>) -> Void) {
        let snap = CountdownSnapshotReader.read()
        let entry = CheckInCountdownEntry(date: Date(), daysRemaining: snap.days, progress: snap.progress)
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct CheckInCountdownWidget: Widget {
    let kind: String = "CheckInCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckInCountdownProvider()) { entry in
            CheckInCountdownWidgetEntryView(entry: entry)
                .containerBackground(Color(hex: "0F0F10"), for: .widget)
        }
        .configurationDisplayName("Check-In Countdown")
        .description("Days until your next weekly check-in.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color(hex:) helper

/// Fileprivate to avoid duplicate-symbol collisions if other widget files
/// in this target define the same extension.
fileprivate extension Color {
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8)  & 0xFF) / 255.0,
            blue:  Double( v        & 0xFF) / 255.0
        )
    }
}
