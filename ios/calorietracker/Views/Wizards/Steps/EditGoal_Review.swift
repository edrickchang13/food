import SwiftUI

// MARK: - EditGoal_Review

/// Step 2 of the Edit Goal wizard — confirmation diff cards.
///
/// References: `~/Downloads/macrofactor-screens/IMG_6477.PNG` and `IMG_6478.PNG`
///
/// Displays a header banner plus three `DiffRowCard`s showing the before/after
/// for goal weight, weekly rate, and estimated daily budget. Wrapped in a
/// `ScrollView` so notes below the cards remain accessible on small screens.
struct EditGoal_Review: View {

    let currentWeightKg: Double
    let originalGoalWeightKg: Double?
    let draftGoalWeightKg: Double
    let originalWeeklyChangeKg: Double?
    let draftWeeklyChangeKg: Double
    let useImperial: Bool

    // MARK: - Constants

    private let lbPerKg: Double = 2.20462

    // MARK: - Formatting helpers

    private func formatWeight(_ kg: Double) -> String {
        if useImperial {
            let lb = kg * lbPerKg
            return "\(Int(lb.rounded())) lb"
        }
        return String(format: "%.1f kg", kg)
    }

    private func formatRate(_ kgPerWeek: Double) -> String {
        guard kgPerWeek != 0 else { return "Maintain" }
        if useImperial {
            let lbPerWeek = kgPerWeek * lbPerKg
            return String(format: "%.1f lb / wk", lbPerWeek)
        }
        return String(format: "%.2f kg / wk", kgPerWeek)
    }

    private func estimatedBudget(weeklyChangeKg rate: Double) -> String {
        let maintenance = currentWeightKg * 33
        let deficitPerDay = (abs(rate) * 7700) / 7
        let budget: Double
        if rate < 0 {
            budget = maintenance - deficitPerDay
        } else {
            budget = maintenance + deficitPerDay
        }
        return "\(Int(budget.rounded())) kcal"
    }

    // MARK: - Row values

    private var originalGoalWeight: String {
        formatWeight(originalGoalWeightKg ?? currentWeightKg)
    }

    private var draftGoalWeight: String {
        formatWeight(draftGoalWeightKg)
    }

    private var originalRate: String {
        formatRate(originalWeeklyChangeKg ?? 0)
    }

    private var draftRate: String {
        formatRate(draftWeeklyChangeKg)
    }

    private var originalBudget: String {
        estimatedBudget(weeklyChangeKg: originalWeeklyChangeKg ?? 0)
    }

    private var draftBudget: String {
        estimatedBudget(weeklyChangeKg: draftWeeklyChangeKg)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                header
                diffCards
            }
            .padding(BulkAITheme.Spacing.lg)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Review Changes")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
            Text("These are the changes we're about to apply.")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Diff cards

    private var diffCards: some View {
        VStack(spacing: BulkAITheme.Spacing.md) {
            DiffRowCard(
                label: "Goal Weight",
                currentValue: originalGoalWeight,
                newValue: draftGoalWeight
            )

            DiffRowCard(
                label: "Weekly Rate",
                currentValue: originalRate,
                newValue: draftRate
            )

            DiffRowCard(
                label: "Daily Budget",
                currentValue: originalBudget,
                newValue: draftBudget,
                note: "This is an estimate based on your current weight. Your actual budget will be updated each week during check-in."
            )
        }
    }
}

// MARK: - Preview

#Preview("EditGoal_Review – changes present") {
    EditGoal_Review(
        currentWeightKg: 86.0,
        originalGoalWeightKg: 79.4,
        draftGoalWeightKg: 80.7,
        originalWeeklyChangeKg: 0.5,
        draftWeeklyChangeKg: 0.35,
        useImperial: false
    )
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}

#Preview("EditGoal_Review – imperial / no prior goal") {
    EditGoal_Review(
        currentWeightKg: 86.0,
        originalGoalWeightKg: nil,
        draftGoalWeightKg: 79.5,
        originalWeeklyChangeKg: nil,
        draftWeeklyChangeKg: 0.5,
        useImperial: true
    )
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
