import SwiftUI
import BulkAIEngine

/// MacroFactor-style dashboard: a horizontal pager of three hero cards over a
/// scrollable analytics list, with a floating search bar pinned above the tab
/// bar. Reads data from the existing stores via @Environment and feeds each
/// card / section purely parametrically — the dashboard owns no business logic
/// of its own.
struct DashboardView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(EngineState.self) private var engineState
    @Environment(ProfileStore.self) private var profileStore

    @State private var pagerIndex: Int = 2          // start on Daily Nutrition (today)
    @State private var weeklySelectedIndex: Int = 6 // today (rightmost of 7 days)
    @State private var weeklyMode: Int = 0          // 0 = Consumed, 1 = Remaining
    @State private var energyMode: Int = 0          // 0 = Expenditure, 1 = Targets
    @State private var dailyMode: Int = 0           // 0 = Consumed, 1 = Remaining
    @State private var searchQuery: String = ""
    @State private var showStrategy: Bool = false
    @State private var showEditGoal: Bool = false
    @State private var showSetProgram: Bool = false

    private var profile: UserProfile { profileStore.profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    pager
                    InsightsAnalyticsGrid(
                        expenditure: insightExpenditure,
                        weightTrend: insightWeightTrend,
                        energyBalance: insightEnergyBalance,
                        goalProgress: insightGoalProgress,
                        onSeeAll: { /* TODO Phase G */ }
                    )
                    HabitsSection(
                        weighInData: weighInHabitData(),
                        weighInThisWeek: "\(weighInsThisWeek())/7",
                        foodLoggingData: foodLoggingHabitData(),
                        foodLoggingThisWeek: "\(foodLogsThisWeek())/7",
                        onWeighInTap: { /* TODO */ },
                        onFoodLoggingTap: { /* TODO */ }
                    )
                    BodyMetricsRow(
                        scaleWeight: scaleWeightCard,
                        bodyFat: bodyFatCard,
                        onSeeAll: { /* TODO */ }
                    )
                    NutritionGrid(
                        calories: NutritionGrid.MacroTotal(
                            consumed: foodStore.todayCalories,
                            target: profile.effectiveCalories,
                            unit: "kcal"
                        ),
                        protein: NutritionGrid.MacroTotal(
                            consumed: foodStore.todayProtein,
                            target: profile.effectiveProtein,
                            unit: "g"
                        ),
                        fat: NutritionGrid.MacroTotal(
                            consumed: foodStore.todayFat,
                            target: profile.effectiveFat,
                            unit: "g"
                        ),
                        carbs: NutritionGrid.MacroTotal(
                            consumed: foodStore.todayCarbs,
                            target: profile.effectiveCarbs,
                            unit: "g"
                        ),
                        onSeeAll: { /* TODO */ },
                        onTapMacro: { _ in /* TODO */ }
                    )
                    GeneralSection(
                        stepsHistory: [3200, 2100, 4500, 1800, 2800, 3600, 2400],
                        stepsValue: "2800 steps",
                        onStepsTap: { /* TODO HealthKit wiring */ },
                        onSeeAll: { /* TODO */ }
                    )
                    MoreSection(
                        onCustomizeDashboard: { /* TODO Phase G */ },
                        onNutritionDataManager: { /* TODO Phase G */ },
                        onStrategy: { showStrategy = true },
                        onEditGoal: { showEditGoal = true },
                        onSetProgram: { showSetProgram = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)   // room for the floating search bar + tab bar
            }
            .background(BulkAITheme.Color.background)

            DashboardSearchBar(
                query: $searchQuery,
                onBarcodeTap: { /* TODO Phase D camera flow */ },
                onAITap: { /* TODO Phase D AI flow */ }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(BulkAITheme.Color.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showStrategy) {
            StrategyView()
        }
        .sheet(isPresented: $showEditGoal) {
            EditGoalFlow()
        }
        .sheet(isPresented: $showSetProgram) {
            SetProgramFlow()
        }
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $pagerIndex) {
            WeeklyNutritionCard(
                dateLabel: todayLabelAllCaps(),
                week: weekTotals(),
                targets: dailyTargets(),
                selectedIndex: $weeklySelectedIndex,
                consumedVsRemaining: $weeklyMode
            )
            .tag(0)

            EnergyBalanceCard(
                dailyNutrition: lastNDaysIntake(30),
                dailyTargets: Array(repeating: profile.effectiveCalories, count: 30),
                dailyExpenditure: lastNDaysExpenditure(30),
                mode: $energyMode
            )
            .tag(1)

            DailyNutritionCard(
                consumed: (
                    kcal: foodStore.todayCalories,
                    protein: foodStore.todayProtein,
                    fat: foodStore.todayFat,
                    carbs: foodStore.todayCarbs
                ),
                target: (
                    kcal: profile.effectiveCalories,
                    protein: profile.effectiveProtein,
                    fat: profile.effectiveFat,
                    carbs: profile.effectiveCarbs
                ),
                mode: $dailyMode
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 500)
    }

    // MARK: - Insight tile builders

    private var insightExpenditure: InsightsAnalyticsGrid.Insight {
        InsightsAnalyticsGrid.Insight(
            title: "Expenditure",
            subtitle: "Last 7 Days",
            icon: "flame.fill",
            accent: BulkAITheme.Color.expenditure,
            sparkline: flatSparkline(value: engineState.snapshot.expenditure?.kcalPerDay ?? 0, count: 7),
            valueText: "\(Int(engineState.snapshot.expenditure?.kcalPerDay ?? 0)) kcal",
            onTap: {}
        )
    }

    private var insightWeightTrend: InsightsAnalyticsGrid.Insight {
        let trendKgs = engineState.snapshot.trend.suffix(7).map { $0.kg }
        let latest = engineState.snapshot.currentTrendKg ?? weightStore.latestEntry?.weightKg ?? 0
        return InsightsAnalyticsGrid.Insight(
            title: "Weight Trend",
            subtitle: "Last 7 Days",
            icon: "scalemass.fill",
            accent: BulkAITheme.Color.weightTrend,
            sparkline: trendKgs.isEmpty ? nil : trendKgs,
            valueText: String(format: "%.1f lbs", latest * 2.20462),
            onTap: {}
        )
    }

    private var insightEnergyBalance: InsightsAnalyticsGrid.Insight {
        let intake = lastNDaysIntake(7)
        let avgIntake = intake.isEmpty ? 0 : intake.reduce(0, +) / max(intake.count, 1)
        let exp = Int(engineState.snapshot.expenditure?.kcalPerDay ?? 0)
        let delta = avgIntake - exp
        let label = delta >= 0 ? "+\(delta) kcal surplus" : "\(delta) kcal deficit"
        return InsightsAnalyticsGrid.Insight(
            title: "Energy Balance",
            subtitle: "Last 7 Days",
            icon: "chart.bar.fill",
            accent: BulkAITheme.Color.macroCalories,
            sparkline: intake.map { Double($0) },
            valueText: label,
            onTap: {}
        )
    }

    private var insightGoalProgress: InsightsAnalyticsGrid.Insight {
        InsightsAnalyticsGrid.Insight(
            title: "Goal Progress",
            subtitle: "Tracking",
            icon: "target",
            accent: BulkAITheme.Color.macroCarbs,
            sparkline: nil,
            valueText: "—",
            onTap: {}
        )
    }

    // MARK: - Body metrics

    private var scaleWeightCard: (history: [Double], current: String, onTap: () -> Void) {
        let recent = weightStore.entries
            .sorted(by: { $0.date > $1.date })
            .prefix(7)
            .map { $0.weightKg * 2.20462 }
            .reversed()
        let current = String(format: "%.1f lbs", (weightStore.latestEntry?.weightKg ?? 0) * 2.20462)
        return (history: Array(recent), current: current, onTap: {})
    }

    private var bodyFatCard: (history: [Double?], current: String, onTap: () -> Void)? {
        let entries = bodyFatStore.entries
        guard !entries.isEmpty || profile.bodyFatPercentage != nil else { return nil }
        let recent = entries
            .sorted(by: { $0.date > $1.date })
            .prefix(7)
            .map { Double?.some($0.bodyFatFraction * 100) }
            .reversed()
        let currentFraction = bodyFatStore.latestEntry?.bodyFatFraction ?? profile.bodyFatPercentage ?? 0
        let current = String(format: "%.1f %%", currentFraction * 100)
        return (history: Array(recent), current: current, onTap: {})
    }

    // MARK: - Habit data

    private func weighInHabitData() -> [Date: Double] {
        var result: [Date: Double] = [:]
        let calendar = Calendar.current
        for entry in weightStore.entries {
            let day = calendar.startOfDay(for: entry.date)
            result[day, default: 0] = 1
        }
        return result
    }

    private func weighInsThisWeek() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let logged = Set(weightStore.entries
            .filter { $0.date >= weekAgo }
            .map { calendar.startOfDay(for: $0.date) })
        return logged.count
    }

    private func foodLoggingHabitData() -> [Date: Double] {
        var result: [Date: Double] = [:]
        let calendar = Calendar.current
        for entry in foodStore.entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            result[day, default: 0] += 1
        }
        return result
    }

    private func foodLogsThisWeek() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let logged = Set(foodStore.entries
            .filter { $0.timestamp >= weekAgo }
            .map { calendar.startOfDay(for: $0.timestamp) })
        return logged.count
    }

    // MARK: - Week/30-day helpers

    private func weekTotals() -> [WeeklyNutritionCard.DayTotals] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            let entries = foodStore.entries(for: day)
            return WeeklyNutritionCard.DayTotals(
                weekday: letters[weekdayIndex],
                kcal: entries.reduce(0) { $0 + $1.calories },
                protein: entries.reduce(0) { $0 + $1.protein },
                fat: entries.reduce(0) { $0 + $1.fat },
                carbs: entries.reduce(0) { $0 + $1.carbs }
            )
        }
    }

    private func dailyTargets() -> WeeklyNutritionCard.DayTotals {
        WeeklyNutritionCard.DayTotals(
            weekday: "",
            kcal: profile.effectiveCalories,
            protein: profile.effectiveProtein,
            fat: profile.effectiveFat,
            carbs: profile.effectiveCarbs
        )
    }

    private func lastNDaysIntake(_ n: Int) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<n).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return foodStore.calories(for: day)
        }
    }

    private func lastNDaysExpenditure(_ n: Int) -> [Int] {
        let value = Int(engineState.snapshot.expenditure?.kcalPerDay ?? Double(profile.dailyCalories))
        return Array(repeating: value, count: n)
    }

    private func flatSparkline(value: Double, count: Int) -> [Double] {
        Array(repeating: value, count: count)
    }

    private func todayLabelAllCaps() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: .now).uppercased()
    }
}
