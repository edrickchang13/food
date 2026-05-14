import SwiftUI
import BulkAIEngine

// MARK: - Macro reshape (fileprivate mirror of SetProgramFlow.reshape)

/// Mirrors `SetProgramFlow.reshape` so the summary preview shows reshaped
/// macros before the user commits. Kept in sync by hand; both pure functions
/// with identical logic.
private func reshapedMacros(
    kcal: Double,
    proteinG: Double,
    fatG: Double,
    carbsG: Double,
    preference: ProgramPreference
) -> (proteinG: Double, fatG: Double, carbsG: Double) {
    SetProgramFlow.reshape(
        kcal: kcal,
        proteinG: proteinG,
        fatG: fatG,
        carbsG: carbsG,
        preference: preference
    )
}

// MARK: - SetProgram_Summary

/// Step 2 of the Set Program wizard — macro week chart and rationale timeline.
///
/// References: `~/Downloads/macrofactor-screens/IMG_6480.PNG` (chart),
/// `IMG_6481.PNG` (rationale scrolled).
///
/// Shows the resolved `DailyPlan` as a seven-day `MacroWeekChart` — with the
/// diet-preference reshape applied — then explains each target through a
/// `NumberedTimeline`. Falls back to a 2400/150/75/270 placeholder when
/// `plan` is nil.
struct SetProgram_Summary: View {

    let preference: ProgramPreference
    let plan: DailyPlan?

    // MARK: - Raw engine values (with nil fallback)

    private var rawKcal: Double { plan?.kcalTarget ?? 2400 }
    private var rawProtein: Double { plan?.macros.proteinG ?? 150 }
    private var rawFat: Double { plan?.macros.fatG ?? 75 }
    private var rawCarbs: Double { plan?.macros.carbsG ?? 270 }

    // MARK: - Reshaped values (what the user will actually get)

    private var reshaped: (proteinG: Double, fatG: Double, carbsG: Double) {
        reshapedMacros(
            kcal: rawKcal,
            proteinG: rawProtein,
            fatG: rawFat,
            carbsG: rawCarbs,
            preference: preference
        )
    }

    private var kcal: Int { Int(rawKcal.rounded()) }
    private var proteinG: Int { Int(reshaped.proteinG.rounded()) }
    private var fatG: Int { Int(reshaped.fatG.rounded()) }
    private var carbsG: Int { Int(reshaped.carbsG.rounded()) }

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
                description: calorieRationale
            ),
            NumberedTimeline.TimelineStep(
                number: 2,
                title: "Protein floor",
                accentValue: "\(proteinG)g",
                accentColor: BulkAITheme.Color.macroProtein,
                description: proteinRationale
            ),
            NumberedTimeline.TimelineStep(
                number: 3,
                title: "Fat floor",
                accentValue: "\(fatG)g",
                accentColor: BulkAITheme.Color.macroFat,
                description: fatRationale
            ),
            NumberedTimeline.TimelineStep(
                number: 4,
                title: "Carb budget",
                accentValue: "\(carbsG)g",
                accentColor: BulkAITheme.Color.macroCarbs,
                description: carbRationale
            )
        ]
    }

    // MARK: - Per-preference rationale copy

    private var calorieRationale: String {
        switch preference {
        case .coached, .balanced, .lowFat, .lowCarb, .highProtein:
            return "Set from your expenditure estimate and weekly weight-change rate."
        case .keto:
            return "Calorie target is unchanged. Keto works by shifting fuel source, not slashing calories."
        }
    }

    private var proteinRationale: String {
        switch preference {
        case .coached, .balanced, .lowFat, .lowCarb:
            return "Protein anchored to your lean mass so you keep muscle while losing fat."
        case .keto:
            return "Protein set to 25% of calories, enough for muscle retention without risking gluconeogenesis."
        case .highProtein:
            return "Protein bumped to 35% of calories for training. Carbs (then fat) absorb the offset."
        }
    }

    private var fatRationale: String {
        switch preference {
        case .coached, .balanced, .highProtein:
            return "Fat held above a hormonal-health minimum so the engine never shaves it."
        case .lowFat:
            return "Fat held below 25% of calories. Carbs absorb the slack."
        case .lowCarb:
            return "Fat fills the gap left by capping carbs. Calories stay on target."
        case .keto:
            return "Fat at ~70% of calories is the primary fuel source for ketosis."
        }
    }

    private var carbRationale: String {
        switch preference {
        case .coached, .balanced, .highProtein:
            return "Carbs fill the remainder. They flex day-to-day on dynamic plans."
        case .lowFat:
            return "Carbs absorb the slack from the fat cap. Total calories stay on target."
        case .lowCarb:
            return "Carbs capped at 30% of calories. Fat absorbs the slack."
        case .keto:
            return "Carbs held to ~5% of calories, below the threshold needed to sustain ketosis."
        }
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

#Preview("SetProgram_Summary – keto") {
    let plan = DailyPlan(
        kcalTarget: 2500,
        macros: MacroTargets(proteinG: 190, fatG: 80, carbsG: 300),
        floorApplied: false
    )
    return ScrollView {
        SetProgram_Summary(preference: .keto, plan: plan)
    }
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}

#Preview("SetProgram_Summary – low carb") {
    let plan = DailyPlan(
        kcalTarget: 2500,
        macros: MacroTargets(proteinG: 190, fatG: 80, carbsG: 300),
        floorApplied: false
    )
    return ScrollView {
        SetProgram_Summary(preference: .lowCarb, plan: plan)
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
