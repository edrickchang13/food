import SwiftUI

/// Third hero card of the Dashboard pager. Mirrors MacroFactor's IMG_6459:
/// a 3/4 arc gauge (~270°, opening at the bottom) with the consumed kcal number
/// inside, flanked by large Remaining and Target numbers, with thin macro
/// progress bars for Protein / Fat / Carbs underneath and a Consumed/Remaining
/// toggle at the bottom.
struct DailyNutritionCard: View {

    let consumed: (kcal: Int, protein: Int, fat: Int, carbs: Int)
    let target: (kcal: Int, protein: Int, fat: Int, carbs: Int)
    @Binding var mode: Int
    var isLoading: Bool = false

    // MARK: Layout constants

    private let arcDiameter: CGFloat = 180
    private let arcStrokeWidth: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            header
            topRow
            macroRows
            toggleRow
        }
        .surfaceCard(padding: BulkAITheme.Spacing.md)
    }

    // MARK: - Header

    private var header: some View {
        Text("Daily Nutrition")
            .font(BulkAITheme.Typography.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top row (Remaining | arc | Target)

    private var topRow: some View {
        HStack(alignment: .center, spacing: BulkAITheme.Spacing.sm) {
            sideStat(value: remaining, label: "Remaining")
                .frame(maxWidth: .infinity, alignment: .leading)

            arcGauge
                .frame(width: arcDiameter, height: arcDiameter * 0.85)

            sideStat(value: target.kcal, label: "Target")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sideStat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .skeleton(isLoading: isLoading)
            Text(label)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Arc gauge

    private var arcGauge: some View {
        let progress = target.kcal > 0
            ? min(max(Double(consumed.kcal) / Double(target.kcal), 0), 1)
            : 0

        return ZStack {
            ArcShape(startAngle: .degrees(135), endAngle: .degrees(45), fraction: 1)
                .stroke(
                    BulkAITheme.Color.surfaceElevated,
                    style: StrokeStyle(lineWidth: arcStrokeWidth, lineCap: .round)
                )

            ArcShape(startAngle: .degrees(135), endAngle: .degrees(45), fraction: progress)
                .stroke(
                    BulkAITheme.Color.macroCalories,
                    style: StrokeStyle(lineWidth: arcStrokeWidth, lineCap: .round)
                )
                .animation(.snappy, value: progress)
                .skeleton(isLoading: isLoading, cornerRadius: arcDiameter / 2)

            VStack(spacing: 2) {
                Text("\(centerValue)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .skeleton(isLoading: isLoading)
                Text(centerLabel)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: arcDiameter, height: arcDiameter)
    }

    // MARK: - Macro rows

    private var macroRows: some View {
        HStack(alignment: .top, spacing: BulkAITheme.Spacing.md) {
            macroColumn(
                label: "Protein",
                consumed: consumed.protein,
                target: target.protein,
                color: BulkAITheme.Color.macroProtein
            )
            macroColumn(
                label: "Fat",
                consumed: consumed.fat,
                target: target.fat,
                color: BulkAITheme.Color.macroFat
            )
            macroColumn(
                label: "Carbs",
                consumed: consumed.carbs,
                target: target.carbs,
                color: BulkAITheme.Color.macroCarbs
            )
        }
    }

    private func macroColumn(label: String, consumed: Int, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text(label)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))

            ThinProgressBar(
                value: Double(displayValue(consumed: consumed, target: target)),
                total: Double(target),
                accent: color
            )
            .skeleton(isLoading: isLoading, cornerRadius: 4)

            Text("\(displayValue(consumed: consumed, target: target)) / \(target)g")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
                .skeleton(isLoading: isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toggle row

    private var toggleRow: some View {
        HStack {
            Spacer()
            SegmentedToggle(
                options: ("Consumed", "Remaining"),
                selection: $mode
            )
            Spacer()
        }
        .padding(.top, BulkAITheme.Spacing.xxs)
    }

    // MARK: - Helpers

    private var remaining: Int {
        max(target.kcal - consumed.kcal, 0)
    }

    private var centerValue: Int {
        mode == 0 ? consumed.kcal : remaining
    }

    private var centerLabel: String {
        mode == 0 ? "Consumed" : "Remaining"
    }

    private func displayValue(consumed: Int, target: Int) -> Int {
        mode == 0 ? consumed : max(target - consumed, 0)
    }
}

// MARK: - ArcShape

/// A 3/4-circle arc drawn from `startAngle` clockwise to `endAngle`, optionally
/// truncated to a 0-1 fraction of its full sweep. Angles are in SwiftUI's
/// trailing-edge convention where 0° is east and angles increase clockwise.
private struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let normalized = max(min(fraction, 1), 0)
        let totalSweep: Double
        let rawDelta = endAngle.degrees - startAngle.degrees
        // Always interpret as a clockwise sweep. If end is "before" start numerically,
        // add a full revolution so we get the expected 270° arc.
        totalSweep = rawDelta < 0 ? rawDelta + 360 : rawDelta

        let drawEnd = startAngle.degrees + (totalSweep * normalized)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: .degrees(drawEnd),
            clockwise: false
        )
        return path
    }
}

// MARK: - Preview

private struct DailyNutritionCardPreviewHarness: View {
    @State private var consumedMode: Int = 0
    @State private var remainingMode: Int = 1

    var body: some View {
        ScrollView {
            VStack(spacing: BulkAITheme.Spacing.md) {
                DailyNutritionCard(
                    consumed: (kcal: 1820, protein: 110, fat: 64, carbs: 220),
                    target: (kcal: 3415, protein: 190, fat: 113, carbs: 407),
                    mode: $consumedMode
                )

                DailyNutritionCard(
                    consumed: (kcal: 1820, protein: 110, fat: 64, carbs: 220),
                    target: (kcal: 3415, protein: 190, fat: 113, carbs: 407),
                    mode: $remainingMode
                )
            }
            .padding(BulkAITheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("DailyNutritionCard") {
    DailyNutritionCardPreviewHarness()
}

private struct DailyNutritionCardLoadingPreviewHarness: View {
    @State private var mode: Int = 0

    var body: some View {
        ScrollView {
            DailyNutritionCard(
                consumed: (kcal: 1820, protein: 110, fat: 64, carbs: 220),
                target: (kcal: 3415, protein: 190, fat: 113, carbs: 407),
                mode: $mode,
                isLoading: true
            )
            .padding(BulkAITheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("DailyNutritionCard — loading") {
    DailyNutritionCardLoadingPreviewHarness()
}
