import WidgetKit
import SwiftUI

@main
struct BulkAIWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CalorieWidget()
        ProteinWidget()
        // P17 additions — medium energy ring + small check-in countdown.
        EnergyBalanceWidget()
        CheckInCountdownWidget()
        // P17 Live Activity for today's kcal ring on the lock screen +
        // Dynamic Island. Main-app side starts/ends the activity in a
        // follow-up phase; the widget config is registered here so iOS
        // picks it up.
        CalorieLiveActivity()
    }
}
