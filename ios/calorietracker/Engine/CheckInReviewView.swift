import SwiftUI
import BulkAIEngine

/// The weekly check-in review screen. Surfaces (a) the last 7 days of intake and
/// trend, (b) the engine's new expenditure estimate vs. the prior, (c) the proposed
/// daily plan, and gives the user three exits: Accept, Adjust, Skip.
///
/// Adherence-neutral: this view never references "you went over on Tuesday" or
/// "you fell short by X" — it only shows trend weight and average intake.
struct CheckInReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EngineState.self) private var engineState
    @Environment(FoodStore.self) private var foodStore

    var onDecision: ((CheckInDecision) -> Void)?

    @State private var showAdjustSheet = false

    private var snapshot: EngineSnapshot { engineState.snapshot }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    weeklySummaryCard
                    expenditureCard
                    proposedPlanCard
                    decisionButtons
                }
                .padding(20)
            }
            .background(AppColors.appBackground)
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { record(.skipped) }
                        .font(.system(.body, design: .rounded))
                }
            }
            .sheet(isPresented: $showAdjustSheet) {
                if let plan = snapshot.dailyPlan {
                    CheckInAdjustSheet(initialPlan: plan) { adjustedPlan in
                        applyPlan(adjustedPlan, decision: .adjusted)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.calorie)
            Text("It's been a week. Let's recalibrate.")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Bulk AI looks at your real intake and trend weight to recompute what your body is actually burning, then proposes new targets for the next week.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 6)
    }

    private var weeklySummaryCard: some View {
        card(title: "Last 7 days") {
            statRow(label: "Avg calories", value: avgCaloriesText)
            statRow(label: "Avg protein", value: avgProteinText)
            statRow(label: "Avg fat", value: avgFatText)
            statRow(label: "Avg carbs", value: avgCarbsText)
            Divider().padding(.vertical, 4)
            statRow(label: "Trend weight change", value: trendDeltaText)
        }
    }

    private var expenditureCard: some View {
        card(title: "Dynamic expenditure") {
            if let exp = snapshot.expenditure {
                statRow(label: "Previous estimate", value: "\(Int(exp.priorKcalPerDay)) kcal/day")
                statRow(label: "New estimate", value: "\(Int(exp.kcalPerDay)) kcal/day")
                statRow(
                    label: "Change",
                    value: formattedDelta(exp.kcalPerDay - exp.priorKcalPerDay, unit: "kcal/day")
                )
                Divider().padding(.vertical, 4)
                statRow(label: "Confidence", value: exp.confidence.rawValue.capitalized)
                if exp.clampApplied {
                    Text("A safety cap was applied. The engine never moves expenditure more than 15% in one week, and stays within physiologically reasonable BMR bounds.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } else {
                Text("Not enough data yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proposedPlanCard: some View {
        card(title: "Proposed plan for the next 7 days") {
            if let plan = snapshot.dailyPlan {
                statRow(label: "Daily calories", value: "\(Int(plan.kcalTarget)) kcal")
                statRow(label: "Protein", value: "\(Int(plan.macros.proteinG)) g")
                statRow(label: "Fat", value: "\(Int(plan.macros.fatG)) g")
                statRow(label: "Carbs", value: "\(Int(plan.macros.carbsG)) g")
                if plan.floorApplied {
                    Text("Your chosen rate would have pushed calories below the protein + fat floor. The engine raised the target to honor those floors.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } else {
                Text("No plan available.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var decisionButtons: some View {
        VStack(spacing: 10) {
            Button {
                if let plan = snapshot.dailyPlan {
                    applyPlan(plan, decision: .accepted)
                }
            } label: {
                Text("Accept and apply")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.calorie)
            .disabled(snapshot.dailyPlan == nil)

            Button("Adjust before applying") {
                showAdjustSheet = true
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .disabled(snapshot.dailyPlan == nil)
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Stats

    private var lastSevenDayEntries: [FoodEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return foodStore.entries.filter { $0.timestamp >= cutoff }
    }

    private var loggedDaysCount: Int {
        Set(lastSevenDayEntries.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
    }

    private func averageOver7Days<T: BinaryInteger>(_ keyPath: KeyPath<FoodEntry, T>) -> Int? {
        let days = loggedDaysCount
        guard days > 0 else { return nil }
        let total = lastSevenDayEntries.reduce(0) { $0 + Int($1[keyPath: keyPath]) }
        return total / days
    }

    private var avgCaloriesText: String {
        averageOver7Days(\.calories).map { "\($0) kcal" } ?? "no logs"
    }

    private var avgProteinText: String {
        averageOver7Days(\.protein).map { "\($0) g" } ?? "no logs"
    }

    private var avgFatText: String {
        averageOver7Days(\.fat).map { "\($0) g" } ?? "no logs"
    }

    private var avgCarbsText: String {
        averageOver7Days(\.carbs).map { "\($0) g" } ?? "no logs"
    }

    private var trendDeltaText: String {
        let trend = snapshot.trend
        guard let latest = trend.last else { return "no logs" }
        let cutoffDay = CalendarDay(date: .now, calendar: .bulkAI).adding(days: -7, in: .bulkAI)
        guard let priorPoint = trend.last(where: { $0.day <= cutoffDay }) else {
            return "need a week of logs"
        }
        let delta = latest.kg - priorPoint.kg
        return formattedDelta(delta, unit: "kg", decimals: 2)
    }

    private func formattedDelta(_ value: Double, unit: String, decimals: Int = 0) -> String {
        let formatter = "%+.\(decimals)f"
        return String(format: formatter, value) + " " + unit
    }

    // MARK: - Decision handlers

    private func record(_ decision: CheckInDecision) {
        let today = CalendarDay(date: .now, calendar: .bulkAI)
        switch decision {
        case .accepted, .adjusted:
            if let exp = snapshot.expenditure {
                engineState.commitAcceptedCheckIn(newExpenditureKcalPerDay: exp.kcalPerDay, on: today)
            }
        case .skipped:
            engineState.commitSkippedCheckIn(on: today)
        }
        onDecision?(decision)
        dismiss()
    }

    private func applyPlan(_ plan: DailyPlan, decision: CheckInDecision) {
        if var profile = UserProfile.load() {
            profile.customCalories = Int(plan.kcalTarget)
            profile.customProtein = Int(plan.macros.proteinG)
            profile.customFat = Int(plan.macros.fatG)
            profile.customCarbs = Int(plan.macros.carbsG)
            profile.save()
        }
        record(decision)
    }
}

/// Lightweight override sheet: lets the user nudge the proposed plan before applying.
private struct CheckInAdjustSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialPlan: DailyPlan
    let onApply: (DailyPlan) -> Void

    @State private var kcal: Double
    @State private var proteinG: Double
    @State private var fatG: Double
    @State private var carbsG: Double

    init(initialPlan: DailyPlan, onApply: @escaping (DailyPlan) -> Void) {
        self.initialPlan = initialPlan
        self.onApply = onApply
        _kcal = State(initialValue: initialPlan.kcalTarget)
        _proteinG = State(initialValue: initialPlan.macros.proteinG)
        _fatG = State(initialValue: initialPlan.macros.fatG)
        _carbsG = State(initialValue: initialPlan.macros.carbsG)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily calories") {
                    Stepper(value: $kcal, in: 800...6000, step: 25) {
                        Text("\(Int(kcal)) kcal")
                    }
                }
                Section("Macros") {
                    Stepper(value: $proteinG, in: 30...400, step: 5) {
                        HStack { Text("Protein"); Spacer(); Text("\(Int(proteinG)) g") }
                    }
                    Stepper(value: $fatG, in: 20...250, step: 5) {
                        HStack { Text("Fat"); Spacer(); Text("\(Int(fatG)) g") }
                    }
                    Stepper(value: $carbsG, in: 0...800, step: 5) {
                        HStack { Text("Carbs"); Spacer(); Text("\(Int(carbsG)) g") }
                    }
                }
                Section {
                    Text("These overrides become your new daily targets. The engine keeps tracking expenditure in the background and will surface another check-in in 7 days.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Adjust plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        let adjusted = DailyPlan(
                            kcalTarget: kcal,
                            macros: MacroTargets(proteinG: proteinG, fatG: fatG, carbsG: carbsG),
                            floorApplied: false
                        )
                        onApply(adjusted)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}
