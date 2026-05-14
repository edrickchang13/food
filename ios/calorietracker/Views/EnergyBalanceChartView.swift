import SwiftUI
import BulkAIEngine

/// 30-day Energy Balance card. For each of the last 30 days, plots
/// `balance = dailyCalories - expenditureKcalPerDay`. Surplus (positive) bars
/// extend up from the center zero-line tinted with `BulkAITheme.Color.accent`; deficit
/// (negative) bars extend down tinted `.green`. Today is the rightmost bar,
/// 30 days ago is the leftmost.
///
/// We use the same `expenditure.kcalPerDay` as a flat reference across all
/// 30 days because per-day expenditure history isn't tracked yet. Days with
/// no logged food count as 0 intake (= full-magnitude deficit) rather than
/// being skipped, so the chart stays visually continuous.
struct EnergyBalanceChartView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(EngineState.self) private var engineState

    private let dayCount = 30
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let expenditure = engineState.snapshot.expenditure?.kcalPerDay {
                let balances = computeBalances(expenditureKcalPerDay: expenditure)
                chart(balances: balances)
            } else {
                emptyState
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BulkAITheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Energy Balance")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Last 30 days")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let expenditure = engineState.snapshot.expenditure?.kcalPerDay {
                let balances = computeBalances(expenditureKcalPerDay: expenditure)
                statsCluster(balances: balances)
            }
        }
    }

    private func statsCluster(balances: [Double]) -> some View {
        HStack(alignment: .top, spacing: 14) {
            avgLabel(balances: balances)
            trendLabel(balances: balances)
        }
    }

    private func avgLabel(balances: [Double]) -> some View {
        let mean = balances.isEmpty ? 0 : balances.reduce(0, +) / Double(balances.count)
        return VStack(alignment: .trailing, spacing: 2) {
            Text("Avg")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(formatSignedKcal(mean))
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(mean >= 0 ? BulkAITheme.Color.accent : .green)
                .monospacedDigit()
        }
    }

    private func trendLabel(balances: [Double]) -> some View {
        // balances is ordered oldest → newest, so the last 7 are the most recent week
        // and the 7 before that are the previous week.
        let recentSeven = Array(balances.suffix(7))
        let priorStart = max(0, balances.count - 14)
        let priorEnd = max(0, balances.count - 7)
        let priorSeven = Array(balances[priorStart..<priorEnd])

        let recentAvg = recentSeven.isEmpty ? 0 : recentSeven.reduce(0, +) / Double(recentSeven.count)
        let priorAvg = priorSeven.isEmpty ? 0 : priorSeven.reduce(0, +) / Double(priorSeven.count)
        let delta = recentAvg - priorAvg
        let arrow = delta >= 0 ? "arrow.up" : "arrow.down"
        // Delta > 0 means the recent week skews more toward surplus (or less deficit).
        let color: Color = delta >= 0 ? BulkAITheme.Color.accent : .green

        return VStack(alignment: .trailing, spacing: 2) {
            Text("Trend")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            HStack(spacing: 3) {
                Image(systemName: arrow)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(formatSignedKcal(delta))
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Chart

    private func chart(balances: [Double]) -> some View {
        let maxMagnitude = max(1, balances.map { abs($0) }.max() ?? 1)
        return GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let midY = height / 2
            let count = max(1, balances.count)
            let totalSpacing: CGFloat = CGFloat(count - 1) * 3
            let barWidth = max(2, (width - totalSpacing) / CGFloat(count))

            ZStack(alignment: .topLeading) {
                // Zero line
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: width, height: 1)
                    .offset(y: midY)

                // Bars
                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array(balances.enumerated()), id: \.offset) { _, balance in
                        bar(balance: balance, maxMagnitude: maxMagnitude, midY: midY, barWidth: barWidth, totalHeight: height)
                    }
                }
                .frame(width: width, height: height, alignment: .center)
            }
        }
        .frame(height: 140)
    }

    private func bar(balance: Double, maxMagnitude: Double, midY: CGFloat, barWidth: CGFloat, totalHeight: CGFloat) -> some View {
        // Each bar occupies the full chart height; we fill from the zero line out.
        let halfHeight = totalHeight / 2
        let magnitude = CGFloat(abs(balance) / maxMagnitude)
        let length = max(1, magnitude * halfHeight)
        let isSurplus = balance >= 0
        let color: Color = isSurplus ? BulkAITheme.Color.accent : .green

        return VStack(spacing: 0) {
            // Top half — used by surplus bars
            VStack {
                Spacer(minLength: 0)
                if isSurplus {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: barWidth, height: length)
                }
            }
            .frame(height: halfHeight)
            // Bottom half — used by deficit bars
            VStack {
                if !isSurplus {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: barWidth, height: length)
                }
                Spacer(minLength: 0)
            }
            .frame(height: halfHeight)
        }
        .frame(width: barWidth, height: totalHeight)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("Not enough data yet")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - Data

    /// Returns 30 daily balances ordered oldest → newest (today is last).
    private func computeBalances(expenditureKcalPerDay: Double) -> [Double] {
        let today = calendar.startOfDay(for: .now)

        // Pre-group intake by start-of-day to avoid O(N*M) scanning.
        var intakeByDay: [Date: Int] = [:]
        for entry in foodStore.entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            intakeByDay[day, default: 0] += entry.calories
        }

        return (0..<dayCount).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return -expenditureKcalPerDay
            }
            let intake = Double(intakeByDay[day] ?? 0)
            return intake - expenditureKcalPerDay
        }
    }

    // MARK: - Formatting

    private func formatSignedKcal(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)" }
        return "\(rounded)" // negative sign is already included
    }
}
