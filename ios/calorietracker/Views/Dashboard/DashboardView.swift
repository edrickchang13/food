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

    /// Optional callback fired when a Weekly Nutrition day column is
    /// tapped. ContentView wires this to switch the global tab to Food
    /// Log and update its selected date so users can drill into a
    /// specific day's chart from the Dashboard.
    var onSelectFoodLogDay: ((Date) -> Void)? = nil

    @State private var pagerIndex: Int = 2          // start on Daily Nutrition (today)
    @State private var weeklySelectedIndex: Int = 6 // today (rightmost of 7 days)
    @State private var weeklyMode: Int = 0          // 0 = Consumed, 1 = Remaining
    @State private var energyMode: Int = 0          // 0 = Expenditure, 1 = Targets
    @State private var dailyMode: Int = 0           // 0 = Consumed, 1 = Remaining
    @State private var searchQuery: String = ""
    @State private var showStrategy: Bool = false
    @State private var showEditGoal: Bool = false
    @State private var showSetProgram: Bool = false
    @State private var showTDEEExplainer: Bool = false
    @State private var showLogWeight: Bool = false
    @State private var showLogBodyFat: Bool = false
    @State private var showAllWeights: Bool = false
    @State private var showBodyMeasurements: Bool = false
    @State private var showBodyFatDetail: Bool = false
    @State private var showFoodDatabase: Bool = false
    @State private var foodEntryRoute: FoodEntryRoute?
    @State private var inlineAlert: InlineAlert?

    /// Where to open `FoodEntrySheet` from. Stored as an Identifiable so
    /// `.sheet(item:)` reads as "open at this tab".
    private struct FoodEntryRoute: Identifiable {
        let id = UUID()
        let tabIndex: Int
    }

    /// Simple alert payload for the "coming in a later phase" stubs so taps
    /// never feel dead — the user gets a definitive answer instead of silence.
    private struct InlineAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    // Memoized aggregations — recomputed only when the underlying store
    // arrays change, not on every body call (which runs 5+ times per frame
    // during scroll at 3,806 entries = ~19k+ iterations per frame otherwise).
    @State private var cachedWeekTotals: [WeeklyNutritionCard.DayTotals] = []
    @State private var cachedLast30DaysIntake: [Int] = []
    @State private var cachedWeighInHabitData: [Date: Double] = [:]
    @State private var cachedFoodLoggingHabitData: [Date: Double] = [:]
    @State private var cachedWeighInsThisWeek: Int = 0
    @State private var cachedFoodLogsThisWeek: Int = 0
    @State private var cachedStepsHistory: [Int] = []
    @State private var cachedStepsToday: Int = 0

    // Cached formatter — DateFormatter construction allocates ~40 KB of
    // ICU data on iOS; doing it in a computed var runs it on every body call.
    private static let todayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private var profile: UserProfile { profileStore.profile }

    /// True while the first frame's aggregations haven't completed — the
    /// `recomputeAggregations()` call on `.onAppear` flips both caches non-empty.
    /// Pager cards and insight tiles shimmer until this flips false so users
    /// don't see a flash of zeros while the page hydrates.
    private var isHydrating: Bool {
        cachedWeekTotals.isEmpty || cachedLast30DaysIntake.isEmpty
    }

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
                        onSeeAll: { showTDEEExplainer = true }
                    )
                    HabitsSection(
                        weighInData: cachedWeighInHabitData,
                        weighInThisWeek: "\(cachedWeighInsThisWeek)/7",
                        foodLoggingData: cachedFoodLoggingHabitData,
                        foodLoggingThisWeek: "\(cachedFoodLogsThisWeek)/7",
                        onWeighInTap: { showLogWeight = true },
                        onFoodLoggingTap: { foodEntryRoute = FoodEntryRoute(tabIndex: 0) }
                    )
                    BodyMetricsRow(
                        scaleWeight: scaleWeightCard,
                        bodyFat: bodyFatCard,
                        onSeeAll: { showBodyMeasurements = true }
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
                        onSeeAll: { foodEntryRoute = FoodEntryRoute(tabIndex: 4) },
                        onTapMacro: { _ in foodEntryRoute = FoodEntryRoute(tabIndex: 4) }
                    )
                    GeneralSection(
                        stepsHistory: cachedStepsHistory,
                        stepsValue: cachedStepsToday > 0 ? "\(cachedStepsToday) steps" : "—",
                        onStepsTap: {
                            inlineAlert = InlineAlert(
                                title: "Connect Apple Health",
                                message: "Step counts wire up in P15. Until then, the sparkline shows a placeholder week."
                            )
                        },
                        onSeeAll: {
                            inlineAlert = InlineAlert(
                                title: "Activity details",
                                message: "Full activity history arrives once Apple Health is wired in P15."
                            )
                        }
                    )
                    MoreSection(
                        onCustomizeDashboard: {
                            inlineAlert = InlineAlert(
                                title: "Customize Dashboard",
                                message: "Section reorder + visibility toggles ship in a later phase."
                            )
                        },
                        onNutritionDataManager: { showFoodDatabase = true },
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
                onBarcodeTap: { foodEntryRoute = FoodEntryRoute(tabIndex: 3) },
                onAITap: { foodEntryRoute = FoodEntryRoute(tabIndex: 2) }
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
        .sheet(isPresented: $showTDEEExplainer) {
            DynamicTDEEExplainer()
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet(
                currentWeightKg: weightStore.latestEntry?.weightKg ?? profile.weightKg
            ) { weightKg in
                weightStore.addEntry(WeightEntry(weightKg: weightKg))
            }
        }
        .sheet(isPresented: $showLogBodyFat) {
            let seed = bodyFatStore.latestEntry?.bodyFatFraction
                ?? profile.bodyFatPercentage
                ?? 0.20
            LogBodyFatSheet(currentFraction: seed) { fraction in
                bodyFatStore.addEntry(BodyFatEntry(bodyFatFraction: fraction))
            }
        }
        .sheet(isPresented: $showAllWeights) {
            AllWeightHistoryView(
                entries: weightStore.entries.sorted { $0.date > $1.date },
                useMetric: false,
                onDelete: { entry in weightStore.deleteEntry(entry) }
            )
        }
        .sheet(isPresented: $showBodyMeasurements) {
            NavigationStack { BodyMeasurementsView() }
        }
        // BodyFatDetailView: sparkline + history list + log-new CTA, the
        // body-fat sibling of WeightDetailView. Reached from the body-fat
        // tile tap on the Body Metrics card.
        .sheet(isPresented: $showBodyFatDetail) {
            BodyFatDetailView()
        }
        .sheet(isPresented: $showFoodDatabase) {
            NavigationStack { FoodDatabaseView() }
        }
        .sheet(item: $foodEntryRoute) { route in
            FoodEntrySheet(initialTab: route.tabIndex)
        }
        .alert(item: $inlineAlert) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("Got it"))
            )
        }
        .onAppear { recomputeAggregations() }
        // `FoodEntry` is not `Equatable`; observe count + the last-entry id as a
        // cheap proxy — any add, delete, or update changes at least one of these.
        .onChange(of: foodStore.entries.count) { recomputeAggregations() }
        .onChange(of: foodStore.entries.last?.id) { recomputeAggregations() }
        .onChange(of: weightStore.entries.count) { recomputeAggregations() }
        .task {
            if let history = await StepReader.last7Days() {
                cachedStepsHistory = history
            }
            if let today = await StepReader.today() {
                cachedStepsToday = today
            }
        }
    }

    // MARK: - Aggregation recompute

    private func recomputeAggregations() {
        cachedWeekTotals = weekTotals()
        cachedLast30DaysIntake = lastNDaysIntake(30)
        cachedWeighInHabitData = weighInHabitData()
        cachedFoodLoggingHabitData = foodLoggingHabitData()
        cachedWeighInsThisWeek = weighInsThisWeek()
        cachedFoodLogsThisWeek = foodLogsThisWeek()
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $pagerIndex) {
            WeeklyNutritionCard(
                dateLabel: Self.todayLabelFormatter.string(from: .now).uppercased(),
                week: cachedWeekTotals,
                targets: dailyTargets(),
                selectedIndex: $weeklySelectedIndex,
                consumedVsRemaining: $weeklyMode,
                isLoading: isHydrating,
                onSelectDay: { dayIndex in
                    // Map column index (0..<7, 6 = today) to a calendar
                    // date and forward to the parent so it can switch to
                    // the Food Log tab on that day. Routes via a shared
                    // notification because Dashboard and FoodLogView are
                    // sibling tabs in ContentView's tab-switching ZStack
                    // and don't share a binding.
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: .now)
                    let offset = -(6 - dayIndex)
                    let target = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    onSelectFoodLogDay?(target)
                }
            )
            .tag(0)

            EnergyBalanceCard(
                dailyNutrition: cachedLast30DaysIntake,
                dailyTargets: Array(repeating: profile.effectiveCalories, count: 30),
                dailyExpenditure: lastNDaysExpenditure(30),
                mode: $energyMode,
                isLoading: isHydrating
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
                mode: $dailyMode,
                isLoading: isHydrating
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
            onTap: { showTDEEExplainer = true },
            isLoading: isHydrating
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
            onTap: { showAllWeights = true },
            isLoading: isHydrating
        )
    }

    private var insightEnergyBalance: InsightsAnalyticsGrid.Insight {
        // Reuse the cached 30-day array; last 7 entries are the trailing week.
        let intake = cachedLast30DaysIntake.suffix(7).map { $0 }
        let avgIntake = intake.isEmpty ? 0 : intake.reduce(0, +) / max(intake.count, 1)
        let exp = Int(engineState.snapshot.expenditure?.kcalPerDay ?? 0)
        let delta = avgIntake - exp
        // Compact label so the tile's bottom row stays single-line and the
        // 2x2 grid keeps consistent row baselines. The sign already carries
        // surplus / deficit meaning; tapping opens DynamicTDEEExplainer for
        // the long-form interpretation.
        let label = delta >= 0 ? "+\(delta) kcal" : "\(delta) kcal"
        return InsightsAnalyticsGrid.Insight(
            title: "Energy Balance",
            subtitle: "Last 7 Days",
            icon: "chart.bar.fill",
            accent: BulkAITheme.Color.macroCalories,
            sparkline: intake.map { Double($0) },
            valueText: label,
            onTap: { showTDEEExplainer = true },
            isLoading: isHydrating
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
            onTap: { showStrategy = true },
            isLoading: isHydrating
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
        // Tap on the scale-weight card opens the log-weight sheet so the user
        // can record today's reading from the dashboard without bouncing into
        // Settings or the Progress tab first.
        return (history: Array(recent), current: current, onTap: { showLogWeight = true })
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
        // Route to the new BodyFatDetailView (sparkline + history + log CTA)
        // instead of jumping straight to the log sheet. The detail view's
        // own toolbar + bottom pill expose the log-new flow without losing
        // the trend context.
        return (history: Array(recent), current: current, onTap: { showBodyFatDetail = true })
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

}
