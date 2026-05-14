import SwiftUI

/// A Strategy-screen card summarising the user's weight goal: current weight,
/// goal weight, and weekly rate of change.
///
/// Supports imperial (lb) and metric (kg) display. Tapping the entire card
/// invokes `onTap` so the parent can push a goal-editor destination.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6475.PNG` — the "Weight Goal"
/// card sits below the Coached Program card on the Strategy screen.
struct WeightGoalCard: View {

    // MARK: Inputs

    let currentWeightKg: Double
    /// `nil` when no goal has been set.
    let goalWeightKg: Double?
    /// `nil` or `0` is displayed as "Maintain". Negative = loss, positive = gain.
    let weeklyChangeKg: Double?
    let useImperial: Bool
    let onTap: () -> Void

    // MARK: Constants

    private let kgToLb: Double = 2.20462

    // MARK: Body

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Weight goal: current \(formattedWeight(currentWeightKg)), " +
            "target \(goalWeightKg.map { formattedWeight($0) } ?? "none"), " +
            "weekly \(weeklyString)"
        )
    }

    // MARK: Card content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            headerRow
            titleRow
            statColumns
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
            Text("GOAL")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var titleRow: some View {
        Text("Weight Goal")
            .font(BulkAITheme.Typography.title3)
            .foregroundStyle(.white)
    }

    private var statColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(label: "CURRENT", value: formattedWeight(currentWeightKg))
            Spacer()
            statColumn(label: "GOAL", value: goalWeightKg.map { formattedWeight($0) } ?? "\u{2014}")
            Spacer()
            statColumn(label: "WEEKLY", value: weeklyString)
        }
        .padding(.top, BulkAITheme.Spacing.xxs)
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            Text(label)
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Formatting helpers

    /// Formats a kilogram value, converting to pounds when `useImperial` is true.
    private func formattedWeight(_ kg: Double) -> String {
        if useImperial {
            let lb = kg * kgToLb
            return String(format: "%.1f lb", lb)
        } else {
            return String(format: "%.1f kg", kg)
        }
    }

    /// Formatted signed weekly rate string, e.g. "\u{2212}0.5 kg", "+1.1 lb", or "Maintain".
    private var weeklyString: String {
        guard let changeKg = weeklyChangeKg, changeKg != 0 else {
            return "Maintain"
        }
        if useImperial {
            let changeLb = changeKg * kgToLb
            let sign = changeLb < 0 ? "\u{2212}" : "+"
            return String(format: "%@%.1f lb", sign, abs(changeLb))
        } else {
            let sign = changeKg < 0 ? "\u{2212}" : "+"
            return String(format: "%@%.1f kg", sign, abs(changeKg))
        }
    }
}

// MARK: - Preview

#Preview("Imperial — losing") {
    WeightGoalCard(
        currentWeightKg: 165.3 / 2.20462,
        goalWeightKg: 155.0 / 2.20462,
        weeklyChangeKg: -0.5,
        useImperial: true,
        onTap: {}
    )
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(BulkAITheme.Color.background)
}

#Preview("Metric — gaining") {
    WeightGoalCard(
        currentWeightKg: 75.0,
        goalWeightKg: 80.0,
        weeklyChangeKg: 0.5,
        useImperial: false,
        onTap: {}
    )
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(BulkAITheme.Color.background)
}

#Preview("Metric — maintain, no target") {
    WeightGoalCard(
        currentWeightKg: 75.0,
        goalWeightKg: nil,
        weeklyChangeKg: nil,
        useImperial: false,
        onTap: {}
    )
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(BulkAITheme.Color.background)
}
