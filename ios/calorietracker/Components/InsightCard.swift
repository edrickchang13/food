import SwiftUI

/// Dashboard analytics tile.
///
/// Layout:
/// - top row: small SF Symbol icon + title label, with optional subtitle
/// - middle: optional sparkline drawn as a `Path` in the accent color
/// - bottom: large numeric value on the leading edge, chevron on the trailing edge
///
/// Designed to be dropped into a 2-column grid. Tapping the card invokes `onTap`.
struct InsightCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color
    let sparkline: [Double]?
    let valueText: String
    let onTap: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        accent: Color,
        sparkline: [Double]? = nil,
        valueText: String,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.sparkline = sparkline
        self.valueText = valueText
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let sparkline, !sparkline.isEmpty {
                    SparklineShape(points: sparkline)
                        .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 36)
                        .overlay(alignment: .leading) {
                            // Tiny dotted markers along the line, matching MacroFactor's look.
                            SparklineDots(points: sparkline, color: accent)
                        }
                        .accessibilityHidden(true)
                } else {
                    // Reserve roughly the same vertical space so cards line up in a grid.
                    Color.clear.frame(height: 36)
                }

                bottomRow
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(subtitle.map { ", \($0)" } ?? ""), \(valueText)")
        .surfaceCard()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(valueText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

/// Sparkline path drawn through normalized points.
private struct SparklineShape: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }

        let minValue = points.min() ?? 0
        let maxValue = points.max() ?? 0
        let range = max(maxValue - minValue, 0.0001)

        let stepX = rect.width / CGFloat(points.count - 1)

        var path = Path()
        for (index, value) in points.enumerated() {
            let normalized = (value - minValue) / range
            let x = stepX * CGFloat(index)
            let y = rect.height - (CGFloat(normalized) * rect.height)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

/// Filled dots at each sparkline data point. MacroFactor uses this treatment.
private struct SparklineDots: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let minValue = points.min() ?? 0
            let maxValue = points.max() ?? 0
            let range = max(maxValue - minValue, 0.0001)
            let stepX = proxy.size.width / CGFloat(max(points.count - 1, 1))

            ForEach(Array(points.enumerated()), id: \.offset) { index, value in
                let normalized = (value - minValue) / range
                let x = stepX * CGFloat(index)
                let y = proxy.size.height - (CGFloat(normalized) * proxy.size.height)
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
    }
}

#Preview("Dashboard Tiles") {
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    return ScrollView {
        LazyVGrid(columns: columns, spacing: 12) {
            InsightCard(
                title: "Expenditure",
                subtitle: "Last 7 Days",
                icon: "flame.fill",
                accent: BulkAITheme.Color.expenditure,
                sparkline: [2950, 2980, 2970, 3010, 2995, 2987, 2987],
                valueText: "2987 kcal",
                onTap: {}
            )

            InsightCard(
                title: "Weight Trend",
                subtitle: "Last 7 Days",
                icon: "scalemass.fill",
                accent: BulkAITheme.Color.weightTrend,
                sparkline: [178.4, 178.6, 178.8, 179.0, 179.0, 179.1, 179.1],
                valueText: "179.1 lbs",
                onTap: {}
            )

            InsightCard(
                title: "Goal Progress",
                subtitle: "Last 372 Days",
                icon: "target",
                accent: BulkAITheme.Color.bodyMetrics,
                sparkline: nil,
                valueText: "81 %",
                onTap: {}
            )
        }
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
