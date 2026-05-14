import SwiftUI
import BulkAIEngine

// MARK: - SetProgram_Summary

/// Step 2 of the Set Program wizard — macro week chart and rationale timeline.
///
/// References: `~/Downloads/macrofactor-screens/IMG_6480.PNG` (chart),
/// `IMG_6481.PNG` (rationale scrolled).
///
/// Shows the resolved `DailyPlan` as a seven-day `MacroWeekChart`, then
/// explains each target through a `NumberedTimeline`. Falls back to a
/// 2400/150/75/270 placeholder when `plan` is nil.
struct SetProgram_Summary: View {

    let preference: ProgramPreference
    let plan: DailyPlan?

    // MARK: - Resolved values (placeholder when plan is nil)

    private var kcal: Int { Int((plan?.kcalTarget ?? 2400).rounded()) }
    private var proteinG: Int { Int((plan?.macros.proteinG ?? 150).rounded()) }
    private var fatG: Int { Int((plan?.macros.fatG ?? 75).rounded()) }
    private var carbsG: Int { Int((plan?.macros.carbsG ?? 270).rounded()) }

    // MARK: - Chart data

    private static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var chartDays: [DayMacros] {
        Self.weekdays.map { weekday in
            DayMacros(
                weekday: weekday,
                kcal: kcal,
                proteinG: proteinG,
                fatG: fatG,
                carbsG: carbsG
            )
        }
    }

    // MARK: - Timeline steps

    private var timelineSteps: [NumberedTimeline.TimelineStep] {
        [
            NumberedTimeline.TimelineStep(
                number: 1,
                title: "Calorie target",
                accentValue: "\(kcal) kcal",
                accentColor: BulkAITheme.Color.macroCalories,
                description: "Set from your expenditure estimate and weekly weight-change rate."
            ),
            NumberedTimeline.TimelineStep(
                number: 2,
                title: "Protein floor",
                accentValue: "\(proteinG)g",
                accentColor: BulkAITheme.Color.macroProtein,
                description: "Protein anchored to your lean mass so you keep muscle while losing fat."
            ),
            NumberedTimeline.TimelineStep(
                number: 3,
                title: "Fat floor",
                accentValue: "\(fatG)g",
                accentColor: BulkAITheme.Color.macroFat,
                description: "Fat held above a hormonal-health minimum so the engine never shaves it."
            ),
            NumberedTimeline.TimelineStep(
                number: 4,
                title: "Carb budget",
                accentValue: "\(carbsG)g",
                accentColor: BulkAITheme.Color.macroCarbs,
                description: "Carbs fill the remainder. They flex day-to-day on dynamic plans."
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                header
                MacroWeekChart(days: chartDays)
                rationaleSection
            }
            .padding(BulkAITheme.Spacing.lg)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Your new program")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
            Text("Generated for your \(preference.displayName) style.")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var rationaleSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
            Text("WHY THIS PLAN")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .kerning(1.2)

            NumberedTimeline(steps: timelineSteps)
        }
    }
}

// MARK: - Preview

#Preview("SetProgram_Summary – with plan") {
    let plan = DailyPlan(
        kcalTarget: 2850,
        macros: MacroTargets(proteinG: 178, fatG: 82, carbsG: 303),
        floorApplied: false
    )
    return ScrollView {
        SetProgram_Summary(preference: .coached, plan: plan)
    }
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}

#Preview("SetProgram_Summary – no plan (placeholder)") {
    return ScrollView {
        SetProgram_Summary(preference: .balanced, plan: nil)
    }
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
