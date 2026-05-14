import SwiftUI

/// A vertical list of numbered steps connected by a thin line, mirroring
/// MacroFactor's "How was your program designed?" rationale view
/// (`~/Downloads/macrofactor-screens/IMG_6481.PNG`).
///
/// Each step renders a 28pt white circle with a black numeral, a bold title,
/// a colored sub-value, and a paragraph of description. A subtle vertical
/// connector is drawn behind the circles, running from the bottom of one
/// circle to the top of the next.
///
/// The connector is drawn in a `ZStack` underlay sized via a `GeometryReader`
/// so it lines up regardless of how much copy each step contains. We pin the
/// connector horizontally to the same offset as the circle centers, then
/// inset it vertically by half a circle plus a small gap on each end.
struct NumberedTimeline: View {

    /// One row in the timeline.
    struct TimelineStep: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let accentValue: String
        let accentColor: Color
        let description: String

        init(
            number: Int,
            title: String,
            accentValue: String,
            accentColor: Color,
            description: String
        ) {
            self.number = number
            self.title = title
            self.accentValue = accentValue
            self.accentColor = accentColor
            self.description = description
        }
    }

    let steps: [TimelineStep]

    private let circleSize: CGFloat = 28
    private let rowSpacing: CGFloat = BulkAITheme.Spacing.lg
    private let columnGap: CGFloat = BulkAITheme.Spacing.md

    var body: some View {
        ZStack(alignment: .topLeading) {
            connector
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(steps) { step in
                    row(for: step)
                }
            }
        }
    }

    @ViewBuilder
    private var connector: some View {
        if steps.count > 1 {
            // Inset by half a circle on top and bottom so the line only spans
            // the gap between circles, not behind them. Horizontal offset
            // pins the line to the circle's vertical center.
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1.5)
                .padding(.leading, (circleSize / 2) - 0.75)
                .padding(.vertical, circleSize / 2)
        }
    }

    private func row(for step: TimelineStep) -> some View {
        HStack(alignment: .top, spacing: columnGap) {
            numberCircle(step.number)
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
                Text(step.title)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                Text(step.accentValue)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(step.accentColor)
                Text(step.description)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, BulkAITheme.Spacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func numberCircle(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: circleSize, height: circleSize)
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
    }
}

#Preview("Set Program rationale") {
    ScrollView {
        NumberedTimeline(steps: [
            .init(
                number: 1,
                title: "Estimated Expenditure",
                accentValue: "2987 kcal",
                accentColor: BulkAITheme.Color.macroCalories,
                description: "Looking back over your nutrition and weight history, we determined that your daily energy expenditure is approximately 2987 kcal."
            ),
            .init(
                number: 2,
                title: "Average Target",
                accentValue: "3414 kcal",
                accentColor: BulkAITheme.Color.macroCarbs,
                description: "Your goal is to gain weight at a rate of 0.48% of body weight per week, so your daily average Calorie goal should be around 3414 Calories."
            ),
            .init(
                number: 3,
                title: "Target Protein",
                accentValue: "1.06 g/lb",
                accentColor: BulkAITheme.Color.macroProtein,
                description: "Given that you have a goal of gaining weight and prefer a high amount of protein, consuming 1.06 g/lb of body weight of protein is a good daily average given your lifestyle and training."
            ),
            .init(
                number: 4,
                title: "Diet Type",
                accentValue: "Balanced",
                accentColor: BulkAITheme.Color.macroFat,
                description: "Finally, we distributed your remaining Calories between carbs and fat in accordance with the Balanced Diet."
            )
        ])
        .padding(BulkAITheme.Spacing.lg)
    }
    .background(BulkAITheme.Color.background)
}
