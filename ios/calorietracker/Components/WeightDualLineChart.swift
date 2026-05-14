import SwiftUI

/// A dual-line weight chart that plots raw daily scale readings alongside the
/// algorithmic smoothed trend, closing the spec-parity gap where only the
/// trend line was visible.
///
/// Layout (top to bottom):
/// - legend row: "Scale" pill (muted) + "Trend" pill (solid)
/// - chart area drawn with hand-built `Path` nodes — no Charts import
/// - x-axis date labels pinned to the leading/trailing edges
///
/// Both lines share the same y-range (union of all points, 2 % padded) so the
/// noisy scale line and the clean trend line are always visually comparable.
/// The trend path is drawn last, ensuring it renders on top of the scale path.
///
/// Drop this into any `surfaceCard`-wrapped container; the background is transparent.
struct WeightDualLineChart: View {

    // MARK: - Public API

    /// Daily scale-weight readings, oldest first. May contain gaps; the chart
    /// connects only consecutive points — it does not interpolate over missing days.
    let scaleSeries: [WeightPoint]

    /// Smoothed trend series, oldest first. Length is independent of `scaleSeries`
    /// — typically denser because the engine interpolates missing days.
    let trendSeries: [WeightPoint]

    /// When `true`, y-axis and legend labels show pounds. When `false`, kilograms.
    /// Internal storage is always in kg; conversion is display-only.
    let useImperial: Bool

    // MARK: - Nested type

    /// One (date, kg) observation on either series.
    struct WeightPoint: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let weightKg: Double

        init(id: UUID = UUID(), date: Date, weightKg: Double) {
            self.id = id
            self.date = date
            self.weightKg = weightKg
        }
    }

    // MARK: - Private computed properties

    private var allPoints: [WeightPoint] { scaleSeries + trendSeries }
    private var earliestDate: Date? { allPoints.map(\.date).min() }
    private var latestDate: Date? { allPoints.map(\.date).max() }

    /// Total time span in seconds. Guards against a single-point degenerate case.
    private var timeSpan: TimeInterval {
        guard let earliest = earliestDate, let latest = latestDate else { return 1 }
        return max(latest.timeIntervalSince(earliest), 1)
    }

    /// Raw min/max across both series before padding.
    private var rawYMin: Double { allPoints.map(\.weightKg).min() ?? 0 }
    private var rawYMax: Double { allPoints.map(\.weightKg).max() ?? 1 }

    /// Padded range guards against zero-range collapse.
    private var yRange: Double { max(rawYMax - rawYMin, 0.0001) }

    /// Shared y-axis bounds with 2 % padding so lines don't kiss the edges.
    private var yMin: Double { rawYMin - yRange * 0.02 }
    private var yMax: Double { rawYMax + yRange * 0.02 }

    // MARK: - Body

    var body: some View {
        if allPoints.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                legend
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        scaleLinePath(in: proxy.size)
                            .stroke(
                                BulkAITheme.Color.weightTrend.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                            )
                        scaleDots(in: proxy.size)
                        trendLinePath(in: proxy.size)
                            .stroke(
                                BulkAITheme.Color.weightTrend,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        yAxisLabels(in: proxy.size)
                    }
                }
                xAxisLabels
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 12) {
            legendPill(label: "Scale", color: BulkAITheme.Color.weightTrend.opacity(0.4))
            legendPill(label: "Trend", color: BulkAITheme.Color.weightTrend)
        }
    }

    @ViewBuilder
    private func legendPill(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Scale line path

    /// Thin muted path connecting raw daily weigh-ins. Drawn before the trend
    /// path so the trend always renders on top in z-order.
    private func scaleLinePath(in size: CGSize) -> Path {
        buildLinePath(for: scaleSeries, in: size)
    }

    // MARK: - Scale dots

    /// Small filled circles at each scale-series point, same muted color as
    /// the scale line. Mirrors the dot treatment in `InsightCard`'s sparkline.
    @ViewBuilder
    private func scaleDots(in size: CGSize) -> some View {
        // `@ViewBuilder` doesn't permit bare `return`, so use a conditional
        // `if let` to short-circuit when there's no time axis to anchor to.
        if let earliest = earliestDate {
            ForEach(scaleSeries) { point in
                let x = xPosition(for: point.date, earliest: earliest, width: size.width)
                let y = yPosition(for: point.weightKg, height: size.height)
                Circle()
                    .fill(BulkAITheme.Color.weightTrend.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .position(x: x, y: y)
            }
        }
    }

    // MARK: - Trend line path

    /// Thicker solid path through the smoothed trend series. Drawn after the
    /// scale path so it is always visible even when the two lines cross.
    private func trendLinePath(in size: CGSize) -> Path {
        buildLinePath(for: trendSeries, in: size)
    }

    // MARK: - Y-axis labels

    /// Two floating labels (yMax near top, yMin near bottom) with monospaced
    /// digits so values don't shift horizontally as they update.
    @ViewBuilder
    private func yAxisLabels(in size: CGSize) -> some View {
        Text(formattedWeight(yMax))
            .font(BulkAITheme.Typography.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
            .position(x: size.width / 2, y: 8)
        Text(formattedWeight(yMin))
            .font(BulkAITheme.Typography.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
            .position(x: size.width / 2, y: size.height - 8)
    }

    // MARK: - X-axis labels

    /// Earliest date on the leading edge, latest date on the trailing edge.
    private var xAxisLabels: some View {
        HStack {
            if let earliest = earliestDate {
                Text(formatDate(earliest))
                    .font(BulkAITheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            if let latest = latestDate {
                Text(formatDate(latest))
                    .font(BulkAITheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("No weight data yet")
            .font(BulkAITheme.Typography.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    // MARK: - Path builder (shared)

    /// Builds a connected `Path` through `points` mapped into `size`.
    /// Points are expected oldest-first; the path uses straight line segments,
    /// mirroring `SparklineShape` in `InsightCard`.
    private func buildLinePath(for points: [WeightPoint], in size: CGSize) -> Path {
        guard points.count >= 2, let earliest = earliestDate else { return Path() }
        var path = Path()
        for (index, point) in points.enumerated() {
            let pt = CGPoint(
                x: xPosition(for: point.date, earliest: earliest, width: size.width),
                y: yPosition(for: point.weightKg, height: size.height)
            )
            if index == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    // MARK: - Coordinate helpers

    private func xPosition(for date: Date, earliest: Date, width: CGFloat) -> CGFloat {
        CGFloat(date.timeIntervalSince(earliest) / timeSpan) * width
    }

    private func yPosition(for weightKg: Double, height: CGFloat) -> CGFloat {
        // Invert: higher weight → smaller y (top of frame).
        height - CGFloat((weightKg - yMin) / (yMax - yMin)) * height
    }

    // MARK: - Formatting helpers

    private func formattedWeight(_ kg: Double) -> String {
        let display = useImperial ? kg * 2.20462 : kg
        return "\(String(format: "%.1f", display)) \(useImperial ? "lb" : "kg")"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("WeightDualLineChart — all states") {
    let calendar = Calendar.current
    let today = Date()

    // Variant 1: 30-day realistic — scale shows daily noise around a slowly rising trend.
    let thirtyDayScale: [WeightDualLineChart.WeightPoint] = (0 ..< 30).map { offset in
        let date = calendar.date(byAdding: .day, value: -29 + offset, to: today)!
        let baseline = 79.38 + Double(offset) * (1.36 / 29) // 175 → 178 lb in kg
        return WeightDualLineChart.WeightPoint(date: date, weightKg: baseline + Double.random(in: -0.23 ... 0.23))
    }
    let thirtyDayTrend: [WeightDualLineChart.WeightPoint] = (0 ..< 30).map { offset in
        let date = calendar.date(byAdding: .day, value: -29 + offset, to: today)!
        return WeightDualLineChart.WeightPoint(date: date, weightKg: 79.38 + Double(offset) * (1.36 / 29))
    }

    // Variant 2: Sparse scale (5 weigh-ins) paired with a dense interpolated trend.
    let sparseScale: [WeightDualLineChart.WeightPoint] = [0, 6, 13, 21, 29].map { offset in
        let date = calendar.date(byAdding: .day, value: -29 + offset, to: today)!
        return WeightDualLineChart.WeightPoint(date: date, weightKg: 81.65 + Double(offset) * (0.91 / 29))
    }
    let sparseTrend: [WeightDualLineChart.WeightPoint] = (0 ..< 30).map { offset in
        let date = calendar.date(byAdding: .day, value: -29 + offset, to: today)!
        return WeightDualLineChart.WeightPoint(date: date, weightKg: 81.65 + Double(offset) * (0.91 / 29))
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            sectionLabel("30-Day Realistic (imperial)")
            WeightDualLineChart(scaleSeries: thirtyDayScale, trendSeries: thirtyDayTrend, useImperial: true)
                .chartCard()

            sectionLabel("Sparse Scale / Dense Trend (kg)")
            WeightDualLineChart(scaleSeries: sparseScale, trendSeries: sparseTrend, useImperial: false)
                .chartCard()

            sectionLabel("Empty State")
            WeightDualLineChart(scaleSeries: [], trendSeries: [], useImperial: true)
                .chartCard()
        }
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}

// Preview helpers — file-private so they don't pollute the module namespace.
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(BulkAITheme.Typography.caption)
        .foregroundStyle(.white.opacity(0.6))
}

private extension View {
    func chartCard() -> some View {
        self
            .padding(16)
            .background(BulkAITheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md))
    }
}
