import WidgetKit
import SwiftUI

struct EnergyBalanceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct EnergyBalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> EnergyBalanceEntry {
        EnergyBalanceEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (EnergyBalanceEntry) -> Void) {
        let snap = WidgetSnapshot.read() ?? .empty
        completion(EnergyBalanceEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EnergyBalanceEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSnapshot.read() ?? .empty
        let entry = EnergyBalanceEntry(date: now, snapshot: snap)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct EnergyBalanceWidget: Widget {
    let kind: String = "EnergyBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EnergyBalanceProvider()) { entry in
            EnergyBalanceWidgetEntryView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Energy Balance")
        .description("Today's calories with a ring and macro splits.")
        .supportedFamilies([.systemMedium])
    }
}
