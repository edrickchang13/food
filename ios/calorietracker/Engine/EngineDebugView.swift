import SwiftUI
import BulkAIEngine

/// A minimal read-only window onto the engine's current snapshot. Used during P1
/// to confirm the engine is computing reasonable values from real stores before
/// we replace any user-facing UI with engine-driven values. Wire this into Settings
/// for now; remove or fold into the main dashboard once we trust the numbers.
struct EngineDebugView: View {
    @Environment(EngineState.self) private var engineState

    var body: some View {
        List {
            Section("Weight Trend") {
                row("Latest trend kg",
                    engineState.snapshot.currentTrendKg.map { String(format: "%.2f", $0) } ?? "(no logs)")
                row("Trend points", "\(engineState.snapshot.trend.count)")
                if let first = engineState.snapshot.trend.first, let last = engineState.snapshot.trend.last {
                    row("Span",
                        "\(first.day) to \(last.day)")
                }
            }

            Section("Dynamic Expenditure") {
                if let exp = engineState.snapshot.expenditure {
                    row("kcal/day", String(format: "%.0f", exp.kcalPerDay))
                    row("Confidence", exp.confidence.rawValue)
                    row("Food log days", "\(exp.foodLogDays) / \(exp.windowDays)")
                    row("Weight log days", "\(exp.weightLogDays) / \(exp.windowDays)")
                    row("Prior", String(format: "%.0f kcal/day", exp.priorKcalPerDay))
                    row("Clamp applied", exp.clampApplied ? "yes" : "no")
                } else {
                    row("Expenditure", "(no profile)")
                }
            }

            Section("Daily Plan") {
                if let plan = engineState.snapshot.dailyPlan {
                    row("Calorie target", String(format: "%.0f kcal", plan.kcalTarget))
                    row("Protein", String(format: "%.0f g", plan.macros.proteinG))
                    row("Fat", String(format: "%.0f g", plan.macros.fatG))
                    row("Carbs", String(format: "%.0f g", plan.macros.carbsG))
                    row("Floor applied", plan.floorApplied ? "yes" : "no")
                } else {
                    row("Daily plan", "(no profile)")
                }
            }

            Section("Weekly Check-In") {
                row("Due now", engineState.snapshot.checkInDue ? "yes" : "no")
            }
        }
        .navigationTitle("Engine (debug)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
