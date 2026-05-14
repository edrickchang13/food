import SwiftUI

/// Second hero card of the Dashboard pager. Mirrors MacroFactor's IMG_6456 / IMG_6457:
/// a 30-bar single-hue column chart with a dotted reference line at the user's
/// target (mustard yellow) or expenditure (brown), an equation row beneath,
/// and a "Expenditure / Targets" toggle that swaps the reference line + middle term.
struct EnergyBalanceCard: View {

    let dailyNutrition: [Int]
    let dailyTargets: [Int]
    let dailyExpenditure: [Int]
    @Binding var mode: Int

    // MARK: Layout constants

    private let chartHeight: CGFloat = 140
    private let barCount: Int = 30
    private let barCornerRadius: CGFloat = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            header
            chart
                .frame(height: chartHeight)
            lastNDaysLabel
            equationRow
            toggleRow
        }
        .surfaceCard(padding: BulkAITheme.Spacing.md)
    }

    // MARK: - Header

    private var header: some View {
        Text("Energy Balance")
            .font(BulkAITheme.Typography.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastNDaysLabel: some View {
        Text("Last 30 Days")
            .font(BulkAITheme.Typography.caption2)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Chart

    private var chart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let nutrition = paddedNutrition
            let reference = paddedReference
            let peak = chartCeiling(nutrition: nutrition, reference: reference)

            let count = max(barCount, 1)
            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(count - 1)
            let barWidth = max((width - totalSpacing) / CGFloat(count), 1)

            // Reference line vertical position from the top.
            let avgReference = average(reference)
            let referenceY = max(
                0,
                height - (CGFloat(avgReference) / CGFloat(peak)) * height
            )

            ZStack(alignment: .bottomLeading) {
                // Bars
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let value = nutrition[index]
                        let barHeight = max(
                            (CGFloat(value) / CGFloat(peak)) * height,
                            2
                        )
                        RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                            .fill(BulkAITheme.Color.macroCalories)
                            .frame(width: barWidth, height: barHeight)
                    }
                }
                .frame(width: width, height: height, alignment: .bottom)

                // Dotted reference line overlay.
                DottedLine()
                    .stroke(
                        referenceColor,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4])
                    )
                    .frame(width: width, height: 1)
                    .offset(y: -(height - referenceY))
            }
            .frame(width: width, height: height, alignment: .bottomLeading)
        }
    }

    // MARK: - Equation row

    private var equationRow: some View {
        let avgNutrition = average(paddedNutrition)
        let avgReference = average(paddedReference)
        let avgDifference = avgNutrition - avgReference

        return HStack(alignment: .top, spacing: 0) {
            equationColumn(
                value: avgNutrition,
                label: "Nutrition",
                icon: .barChart,
                tint: BulkAITheme.Color.macroCalories
            )
            equationOperator("−")
            equationColumn(
                value: avgReference,
                label: middleLabel,
                icon: .checkmark,
                tint: referenceColor
            )
            equationOperator("=")
            equationColumn(
                value: avgDifference,
                label: "Difference",
                icon: .none,
                tint: nil
            )
        }
    }

    private enum EquationIcon {
        case barChart
        case checkmark
        case none
    }

    @ViewBuilder
    private func equationColumn(value: Int, label: String, icon: EquationIcon, tint: Color?) -> some View {
        VStack(spacing: 4) {
            Text(formatted(value))
                .font(BulkAITheme.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .monospacedDigit()

            HStack(spacing: 4) {
                iconView(for: icon, tint: tint)
                Text(label)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func iconView(for icon: EquationIcon, tint: Color?) -> some View {
        switch icon {
        case .barChart:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint ?? .white)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(tint ?? .white)
        case .none:
            EmptyView()
        }
    }

    private func equationOperator(_ glyph: String) -> some View {
        Text(glyph)
            .font(BulkAITheme.Typography.title3)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 2)
            .frame(width: 18)
    }

    // MARK: - Toggle row

    private var toggleRow: some View {
        HStack {
            Spacer()
            SegmentedToggle(
                options: ("Expenditure", "Targets"),
                selection: $mode
            )
            Spacer()
        }
        .padding(.top, BulkAITheme.Spacing.xxs)
    }

    // MARK: - Helpers

    private var referenceColor: Color {
        // Mode 0 = Expenditure → brown sparkline color.
        // Mode 1 = Targets → mustard yellow.
        mode == 0 ? BulkAITheme.Color.expenditure : BulkAITheme.Color.macroFat
    }

    private var middleLabel: String {
        mode == 0 ? "Expenditure" : "Targets"
    }

    private var paddedNutrition: [Int] {
        pad(dailyNutrition, to: barCount)
    }

    private var paddedReference: [Int] {
        let source = mode == 0 ? dailyExpenditure : dailyTargets
        return pad(source, to: barCount)
    }

    private func pad(_ values: [Int], to count: Int) -> [Int] {
        if values.count >= count {
            return Array(values.suffix(count))
        }
        return Array(repeating: 0, count: count - values.count) + values
    }

    private func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(values.count)).rounded())
    }

    private func chartCeiling(nutrition: [Int], reference: [Int]) -> Int {
        let peak = max(
            nutrition.max() ?? 0,
            reference.max() ?? 0
        )
        // Headroom so the dotted line never crashes into the top edge.
        return max(Int(Double(peak) * 1.1), 1)
    }

    private func formatted(_ value: Int) -> String {
        // Render negative numbers with a unicode minus rather than a hyphen for visual weight.
        if value < 0 {
            return "\u{2212}\(abs(value))"
        }
        return "\(value)"
    }
}

// MARK: - DottedLine

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Preview

private struct EnergyBalanceCardPreviewHarness: View {
    @State private var mode: Int = 1

    private let nutrition: [Int] = [
        3100, 3300, 2900, 3500, 2700, 2800, 3000,
        3200, 3100, 2950, 3400, 3050, 2850, 3150,
        3250, 3000, 2920, 3380, 2780, 3120, 3060,
        3220, 3010, 2880, 3420, 2810, 3140, 3080,
        3170, 2963
    ]

    private let targets: [Int] = Array(repeating: 3515, count: 30)
    private let expenditure: [Int] = Array(repeating: 2973, count: 30)

    var body: some View {
        ScrollView {
            EnergyBalanceCard(
                dailyNutrition: nutrition,
                dailyTargets: targets,
                dailyExpenditure: expenditure,
                mode: $mode
            )
            .padding(BulkAITheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("EnergyBalanceCard") {
    EnergyBalanceCardPreviewHarness()
}
