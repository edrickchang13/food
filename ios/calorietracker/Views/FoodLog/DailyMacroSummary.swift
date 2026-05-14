import SwiftUI

/// Row of four thin progress pills (kcal / P / F / C) plus a two-dot page
/// indicator, matching the band beneath the week strip in `IMG_6465.PNG`.
///
/// Each pill shows an inline label and `value/target` formatted as integers,
/// with a `ThinProgressBar` rail beneath. Colors follow `BulkAITheme.Color`'s
/// macro convention:
/// - kcal → `macroCalories` (blue, with a flame glyph instead of a letter)
/// - protein → `macroProtein` (coral)
/// - fat → `macroFat` (mustard)
/// - carbs → `macroCarbs` (mint)
///
/// The two-dot page indicator is purely visual for now. Phase C does not own
/// the horizontal pager that will eventually toggle this row's content; the
/// dot reservation simply matches the reference design so the row spacing
/// does not shift when paging arrives later.
struct DailyMacroSummary: View {

    // Calorie totals
    let caloriesConsumed: Double
    let caloriesTarget: Double

    // Macro totals (grams)
    let proteinConsumed: Double
    let proteinTarget: Double
    let fatConsumed: Double
    let fatTarget: Double
    let carbsConsumed: Double
    let carbsTarget: Double

    var body: some View {
        VStack(spacing: BulkAITheme.Spacing.sm) {
            HStack(alignment: .top, spacing: BulkAITheme.Spacing.sm) {
                pill(
                    label: .icon("flame.fill"),
                    consumed: caloriesConsumed,
                    target: caloriesTarget,
                    accent: BulkAITheme.Color.macroCalories
                )
                pill(
                    label: .letter("P"),
                    consumed: proteinConsumed,
                    target: proteinTarget,
                    accent: BulkAITheme.Color.macroProtein
                )
                pill(
                    label: .letter("F"),
                    consumed: fatConsumed,
                    target: fatTarget,
                    accent: BulkAITheme.Color.macroFat
                )
                pill(
                    label: .letter("C"),
                    consumed: carbsConsumed,
                    target: carbsTarget,
                    accent: BulkAITheme.Color.macroCarbs
                )
            }

            pageIndicator
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(BulkAITheme.Color.background)
    }

    // MARK: Pill

    private enum PillLabel {
        case icon(String)
        case letter(String)
    }

    private func pill(
        label: PillLabel,
        consumed: Double,
        target: Double,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                switch label {
                case .icon(let systemName):
                    Image(systemName: systemName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                case .letter(let text):
                    Text(text)
                        .font(BulkAITheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(formattedPair(consumed: consumed, target: target))
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ThinProgressBar(
                value: consumed,
                total: target,
                accent: accent,
                height: 3
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: label, consumed: consumed, target: target))
    }

    // MARK: Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 5, height: 5)
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: 5, height: 5)
        }
        .accessibilityHidden(true)
    }

    // MARK: Formatting

    private func formattedPair(consumed: Double, target: Double) -> String {
        "\(Self.integerString(consumed)) / \(Self.integerString(target))"
    }

    private static func integerString(_ value: Double) -> String {
        let rounded = value.rounded()
        // Guard against -0.0 and NaN. Integer truncation is fine here because
        // the MacroFactor reference shows whole numbers throughout.
        guard rounded.isFinite else { return "0" }
        return String(Int(rounded))
    }

    private func accessibilityLabel(
        for label: PillLabel,
        consumed: Double,
        target: Double
    ) -> String {
        let name: String
        switch label {
        case .icon:
            name = "Calories"
        case .letter(let letter):
            switch letter {
            case "P": name = "Protein"
            case "F": name = "Fat"
            case "C": name = "Carbohydrates"
            default: name = letter
            }
        }
        return "\(name) \(Self.integerString(consumed)) of \(Self.integerString(target))"
    }
}

#Preview("DailyMacroSummary — empty day") {
    VStack {
        DailyMacroSummary(
            caloriesConsumed: 0,
            caloriesTarget: 3415,
            proteinConsumed: 0,
            proteinTarget: 190,
            fatConsumed: 0,
            fatTarget: 113,
            carbsConsumed: 0,
            carbsTarget: 407
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}

#Preview("DailyMacroSummary — partial day") {
    VStack {
        DailyMacroSummary(
            caloriesConsumed: 1840,
            caloriesTarget: 3415,
            proteinConsumed: 92,
            proteinTarget: 190,
            fatConsumed: 61,
            fatTarget: 113,
            carbsConsumed: 220,
            carbsTarget: 407
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
