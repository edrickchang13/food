import SwiftUI

/// Body Metrics dashboard row — Scale Weight on the left, Visual Body Fat on
/// the right. Both cards show a small inline chart spanning the last seven
/// entries plus the current value. The body fat card is optional so we can
/// hide it for users who haven't opted into that metric.
struct BodyMetricsRow: View {

    let scaleWeight: (history: [Double], current: String, onTap: () -> Void)
    let bodyFat: (history: [Double?], current: String, onTap: () -> Void)?
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Body Metrics")
                    .font(BulkAITheme.Typography.title3)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Button(action: onSeeAll) {
                    Text("See All")
                        .font(BulkAITheme.Typography.caption)
                        .foregroundStyle(BulkAITheme.Color.accent)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: BulkAITheme.Spacing.sm) {
                scaleWeightCard

                if let bodyFat {
                    bodyFatCard(history: bodyFat.history, current: bodyFat.current, onTap: bodyFat.onTap)
                }
            }
        }
    }

    private var scaleWeightCard: some View {
        Button(action: scaleWeight.onTap) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                cardHeader(title: "Scale Weight", subtitle: "Last 7 Entries")

                LineSparkline(points: scaleWeight.history, color: BulkAITheme.Color.macroCarbs)
                    .frame(height: 44)

                cardFooter(value: scaleWeight.current)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .surfaceCard()
    }

    private func bodyFatCard(history: [Double?], current: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                cardHeader(title: "Visual Body Fat", subtitle: "Last 7 Entries")

                ScatterSparkline(points: history, color: BulkAITheme.Color.macroCarbs)
                    .frame(height: 44)

                cardFooter(value: current)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .surfaceCard()
    }

    private func cardHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func cardFooter(value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

// MARK: - Line sparkline

/// Compact line chart with point markers. Hand-rolled with `Path` + `Circle`
/// instead of Swift Charts so we stay buildable on Xcode 16.4 without
/// `Chart { ForEach + if let }` patterns that hit known compiler issues.
private struct LineSparkline: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let plot = normalize(points: points, in: proxy.size)

            ZStack {
                if plot.count >= 2 {
                    Path { path in
                        path.move(to: plot[0])
                        for index in 1..<plot.count {
                            path.addLine(to: plot[index])
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(plot.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(BulkAITheme.Color.surface)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle().stroke(color, lineWidth: 1.5)
                        )
                        .position(point)
                }
            }
        }
    }

    private func normalize(points: [Double], in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let minValue = points.min() ?? 0
        let maxValue = points.max() ?? 0
        let range = max(maxValue - minValue, 0.0001)

        // Single-point case: center it horizontally so the dot still renders.
        if points.count == 1 {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }

        let stepX = size.width / CGFloat(points.count - 1)
        return points.enumerated().map { index, value in
            let normalized = (value - minValue) / range
            return CGPoint(
                x: stepX * CGFloat(index),
                y: size.height - (CGFloat(normalized) * size.height)
            )
        }
    }
}

// MARK: - Scatter sparkline

/// Scatter-style sparkline for sparse series. Uses `[Double?]` so missing
/// entries skip rendering while still occupying their x-axis slot. Missing
/// values do not contribute to min/max so the present points still spread
/// across the available vertical range.
private struct ScatterSparkline: View {
    let points: [Double?]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let presentValues = points.compactMap { $0 }
            let minValue = presentValues.min() ?? 0
            let maxValue = presentValues.max() ?? 0
            let range = max(maxValue - minValue, 0.0001)
            let stepX = points.count > 1 ? proxy.size.width / CGFloat(points.count - 1) : 0
            let singleY = proxy.size.height / 2

            ZStack {
                // Faint horizontal baseline so the card doesn't feel empty when
                // there's only one dot — matches the reference screenshot.
                Path { path in
                    let y = proxy.size.height - 1
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(Color.white.opacity(0.06), lineWidth: 1)

                ForEach(Array(points.enumerated()), id: \.offset) { index, optional in
                    if let value = optional {
                        let normalized = presentValues.count > 1
                            ? (value - minValue) / range
                            : 0.5
                        let x = points.count > 1
                            ? stepX * CGFloat(index)
                            : proxy.size.width / 2
                        let y = presentValues.count > 1
                            ? proxy.size.height - (CGFloat(normalized) * proxy.size.height)
                            : singleY

                        Circle()
                            .fill(BulkAITheme.Color.surface)
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle().stroke(color, lineWidth: 1.5)
                            )
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

#Preview("Body Metrics") {
    let weightHistory: [Double] = [178.2, 178.6, 179.0, 178.7, 179.1, 178.9, 179.2]
    // Sparse: only the most recent entry is present, so the scatter chart
    // renders as a single dot on the right — mirroring IMG_6461.
    let bodyFatHistory: [Double?] = [nil, nil, nil, nil, nil, nil, 15.0]

    return ScrollView {
        BodyMetricsRow(
            scaleWeight: (history: weightHistory, current: "179.2 lbs", onTap: {}),
            bodyFat: (history: bodyFatHistory, current: "15.0 %", onTap: {}),
            onSeeAll: {}
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
