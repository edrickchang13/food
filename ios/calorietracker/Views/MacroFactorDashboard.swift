import SwiftUI
import BulkAIEngine

// MARK: - Calorie half-ring gauge

/// Half-circle gauge matching MacroFactor's dashboard hero. Open-bottom ring
/// with three labels: remaining (left), consumed (center, large), target (right).
/// Foreground arc fills proportionally to consumed/target, capped at 100%.
struct CalorieRingHero: View {
    let consumed: Int
    let target: Int

    var remaining: Int { max(0, target - consumed) }
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                // Background arc
                halfRing
                    .stroke(
                        AppColors.calorie.opacity(0.12),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                // Foreground arc
                halfRing
                    .trim(from: 0, to: progress * 0.5)
                    .stroke(
                        AppColors.calorie,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)

                // Center label
                VStack(spacing: 0) {
                    Text("\(consumed)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: consumed)
                    Text("Consumed")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .offset(y: 6)
            }
            .frame(height: 180)

            // Side labels under the arc (Remaining ← center → Target)
            HStack {
                sideLabel("\(remaining)", "Remaining")
                Spacer()
                sideLabel("\(target)", "Target")
            }
            .padding(.horizontal, 24)
        }
    }

    private var halfRing: Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: 90, y: 90),
                radius: 78,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )
        }
    }

    @ViewBuilder
    private func sideLabel(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(caption)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Macro horizontal bars

struct MacroProgressBar: View {
    let label: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(8, geo.size.width * progress), height: 6)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
            Text("\(current) / \(target)\(unit)")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacroBarsRow: View {
    let protein: (current: Int, target: Int)
    let fat: (current: Int, target: Int)
    let carbs: (current: Int, target: Int)

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MacroProgressBar(label: "Protein", current: protein.current, target: protein.target,
                             unit: "g", color: .red)
            MacroProgressBar(label: "Fat", current: fat.current, target: fat.target,
                             unit: "g", color: .yellow)
            MacroProgressBar(label: "Carbs", current: carbs.current, target: carbs.target,
                             unit: "g", color: .green)
        }
    }
}

// MARK: - Habit heatmap (7-day)

struct HabitHeatmap30Day: View {
    let dailyActivity: [Bool]   // most recent 30 days, true if active
    let thisWeekCount: Int
    let label: String
    let icon: String
    let color: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Text("Last 30 days")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<min(30, dailyActivity.count), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(dailyActivity[i] ? color : color.opacity(0.18))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            HStack {
                Text("\(thisWeekCount)/7")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("this week")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Insights row (Expenditure + Weight Trend pills)

struct EngineInsightsRow: View {
    let expenditure: ExpenditureEstimate?
    let trendKg: Double?
    let useMetric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("INSIGHTS & ANALYTICS")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                Text("See All")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)
            }
            HStack(spacing: 12) {
                insightPill(
                    title: "Expenditure",
                    value: expenditure.map { "\(Int($0.kcalPerDay)) kcal" } ?? "—",
                    subtitle: "Last 14 days",
                    icon: "flame.fill",
                    color: AppColors.calorie
                )
                insightPill(
                    title: "Weight Trend",
                    value: trendKg.map { formatWeight($0) } ?? "—",
                    subtitle: "EWMA smoothed",
                    icon: "scalemass",
                    color: .purple
                )
            }
        }
    }

    private func insightPill(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(subtitle)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatWeight(_ kg: Double) -> String {
        if useMetric {
            return String(format: "%.1f kg", kg)
        }
        return String(format: "%.1f lb", kg * 2.20462)
    }
}

// MARK: - The whole dashboard

/// Top-level MacroFactor-style dashboard composed from the small pieces above.
/// Reads from FoodStore, EngineState, ProfileStore. Today only (selectedDate
/// handling stays in HomeView for the food log section below).
struct MacroFactorDashboard: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(EngineState.self) private var engineState
    @Environment(WeightStore.self) private var weightStore
    @AppStorage("useMetric") private var useMetric = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            nutritionCard
            insightsRow
            habitsRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Text("Dashboard")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
        }
    }

    private var nutritionCard: some View {
        let profile = UserProfile.load() ?? .default
        let kcalTarget = engineState.snapshot.dailyPlan.map { Int($0.kcalTarget) } ?? profile.effectiveCalories
        let proteinTarget = engineState.snapshot.dailyPlan.map { Int($0.macros.proteinG) } ?? profile.effectiveProtein
        let fatTarget = engineState.snapshot.dailyPlan.map { Int($0.macros.fatG) } ?? profile.effectiveFat
        let carbsTarget = engineState.snapshot.dailyPlan.map { Int($0.macros.carbsG) } ?? profile.effectiveCarbs
        return VStack(spacing: 22) {
            CalorieRingHero(consumed: foodStore.todayCalories, target: kcalTarget)
            MacroBarsRow(
                protein: (foodStore.todayProtein, proteinTarget),
                fat: (foodStore.todayFat, fatTarget),
                carbs: (foodStore.todayCarbs, carbsTarget)
            )
        }
        .padding(20)
        .background(AppColors.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var insightsRow: some View {
        EngineInsightsRow(
            expenditure: engineState.snapshot.expenditure,
            trendKg: engineState.snapshot.currentTrendKg,
            useMetric: useMetric
        )
    }

    private var habitsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HABITS")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            HStack(spacing: 12) {
                HabitHeatmap30Day(
                    dailyActivity: weighInActivity(),
                    thisWeekCount: thisWeekCount(weighInActivity()),
                    label: "Weigh-In",
                    icon: "scalemass",
                    color: .green
                )
                HabitHeatmap30Day(
                    dailyActivity: foodLogActivity(),
                    thisWeekCount: thisWeekCount(foodLogActivity()),
                    label: "Food Logging",
                    icon: "fork.knife",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Activity helpers (most recent 30 days as [Bool], today at index 0)

    private func weighInActivity() -> [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<30).map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return weightStore.entries.contains { calendar.isDate($0.date, inSameDayAs: day) }
        }
    }

    private func foodLogActivity() -> [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<30).map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return foodStore.entries.contains { calendar.isDate($0.timestamp, inSameDayAs: day) }
        }
    }

    private func thisWeekCount(_ activity: [Bool]) -> Int {
        // Index 0 is today, so the first 7 entries cover the last 7 days.
        return activity.prefix(7).filter { $0 }.count
    }
}
