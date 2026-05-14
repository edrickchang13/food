import SwiftUI

/// A single day's macro plan, used as input to `MacroWeekChart`.
struct DayMacros: Identifiable, Sendable, Hashable {
    let id: UUID
    let weekday: String
    let kcal: Int
    let proteinG: Int
    let fatG: Int
    let carbsG: Int

    init(
        id: UUID = UUID(),
        weekday: String,
        kcal: Int,
        proteinG: Int,
        fatG: Int,
        carbsG: Int
    ) {
        self.id = id
        self.weekday = weekday
        self.kcal = kcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
    }
}

/// Seven-column stacked daily macro chart used by Strategy and Set Program screens.
///
/// Each column, from top to bottom:
/// - thin kcal pill (e.g. "3414")
/// - protein block (coral) with "<g> P" label
/// - fat block (yellow) with "<g> F" label
/// - carbs block (green) with "<g> C" label
///
/// Bar heights are proportional within each macro row across the 7 days, so a day
/// with higher protein than its peers reads as a taller protein block.
struct MacroWeekChart: View {
    let days: [DayMacros]

    /// Maximum height the chart should consume below the kcal pill row.
    private let maxStackHeight: CGFloat = 240
    /// Minimum block height so single-digit days remain readable.
    private let minBlockHeight: CGFloat = 32
    /// Spacing between rows (protein/fat/carbs blocks).
    private let rowSpacing: CGFloat = 4

    var body: some View {
        let proteinPeak = max(days.map(\.proteinG).max() ?? 0, 1)
        let fatPeak = max(days.map(\.fatG).max() ?? 0, 1)
        let carbsPeak = max(days.map(\.carbsG).max() ?? 0, 1)

        // Reserve a share of the total stack height per macro row.
        // Carbs columns tend to be the visually largest, so give them more vertical space.
        let proteinRowHeight = maxStackHeight * 0.28
        let fatRowHeight = maxStackHeight * 0.22
        let carbsRowHeight = maxStackHeight * 0.50

        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(days) { day in
                    VStack(spacing: rowSpacing) {
                        kcalPill(day.kcal)

                        macroBlock(
                            value: day.proteinG,
                            peak: proteinPeak,
                            rowHeight: proteinRowHeight,
                            label: "\(day.proteinG) P",
                            color: BulkAITheme.Color.macroProtein,
                            corners: .top
                        )

                        macroBlock(
                            value: day.fatG,
                            peak: fatPeak,
                            rowHeight: fatRowHeight,
                            label: "\(day.fatG) F",
                            color: BulkAITheme.Color.macroFat,
                            corners: .none
                        )

                        macroBlock(
                            value: day.carbsG,
                            peak: carbsPeak,
                            rowHeight: carbsRowHeight,
                            label: "\(day.carbsG) C",
                            color: BulkAITheme.Color.macroCarbs,
                            corners: .bottom
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 6) {
                ForEach(days) { day in
                    Text(day.weekday)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func kcalPill(_ kcal: Int) -> some View {
        Text("\(kcal)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(BulkAITheme.Color.macroCalories)
            )
    }

    @ViewBuilder
    private func macroBlock(
        value: Int,
        peak: Int,
        rowHeight: CGFloat,
        label: String,
        color: Color,
        corners: BlockCorners
    ) -> some View {
        let ratio = CGFloat(max(value, 0)) / CGFloat(peak)
        let height = max(minBlockHeight, rowHeight * ratio)

        ZStack {
            shape(for: corners)
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func shape(for corners: BlockCorners) -> some View {
        switch corners {
        case .top:
            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 8,
                style: .continuous
            )
        case .bottom:
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                topTrailingRadius: 0,
                style: .continuous
            )
        case .none:
            Rectangle()
        }
    }

    private enum BlockCorners {
        case top
        case bottom
        case none
    }
}

#Preview("7-Day Program") {
    let plan: [DayMacros] = [
        DayMacros(weekday: "M", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "T", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "W", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "T", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "F", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "S", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407),
        DayMacros(weekday: "S", kcal: 3414, proteinG: 190, fatG: 113, carbsG: 407)
    ]

    return VStack(alignment: .leading, spacing: 16) {
        Text("Your macro program is ready")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        MacroWeekChart(days: plan)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(BulkAITheme.Color.background)
}
