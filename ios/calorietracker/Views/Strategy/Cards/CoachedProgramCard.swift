import SwiftUI
import BulkAIEngine

/// A Strategy-screen card displaying the user's current 7-day coached macro program.
///
/// The card projects a single `DailyPlan` across all seven days (Phase E behaviour;
/// varying-by-day plans arrive in Phase G). Tapping the entire card invokes `onTap`
/// so the parent can push a program-editor destination.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6474.PNG` — the "Coached Program"
/// card appears below the action pill carousel.
struct CoachedProgramCard: View {

    // MARK: Inputs

    /// The current coached plan. `nil` while the engine has not produced a plan yet.
    let plan: DailyPlan?
    /// One-letter weekday abbreviations, length must be 7 (e.g. `["S","M","T","W","T","F","S"]`).
    let weekdayLetters: [String]
    let onTap: () -> Void

    // MARK: Body

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coached program, tap to edit")
    }

    // MARK: Card content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            headerRow
            titleRow
            bodyContent
        }
        .padding(BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                .fill(BulkAITheme.Color.surface)
        )
    }

    // MARK: Sub-views

    private var headerRow: some View {
        HStack {
            Text("PROGRAM")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var titleRow: some View {
        Text("Coached Program")
            .font(BulkAITheme.Typography.title3)
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let plan {
            MacroWeekChart(days: buildDays(from: plan))
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
            Text("No program yet")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BulkAITheme.Spacing.xl)
    }

    // MARK: Helpers

    /// Projects the same `DailyPlan` across every day of the week.
    private func buildDays(from plan: DailyPlan) -> [DayMacros] {
        let letters = weekdayLetters.count == 7 ? weekdayLetters : ["S", "M", "T", "W", "T", "F", "S"]
        return letters.map { letter in
            DayMacros(
                weekday: letter,
                kcal: Int(plan.kcalTarget.rounded()),
                proteinG: Int(plan.macros.proteinG.rounded()),
                fatG: Int(plan.macros.fatG.rounded()),
                carbsG: Int(plan.macros.carbsG.rounded())
            )
        }
    }
}

// MARK: - Preview

#Preview("With plan") {
    let plan = DailyPlan(
        kcalTarget: 3414,
        macros: MacroTargets(proteinG: 190, fatG: 113, carbsG: 407),
        floorApplied: false
    )
    return CoachedProgramCard(
        plan: plan,
        weekdayLetters: ["S", "M", "T", "W", "T", "F", "S"],
        onTap: {}
    )
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(BulkAITheme.Color.background)
}

#Preview("No plan yet") {
    CoachedProgramCard(
        plan: nil,
        weekdayLetters: ["S", "M", "T", "W", "T", "F", "S"],
        onTap: {}
    )
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(BulkAITheme.Color.background)
}
