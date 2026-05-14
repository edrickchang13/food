import SwiftUI
import BulkAIEngine

// MARK: - Equation Term

/// Identifies a tappable variable in the energy-balance equation.
private enum EquationTerm: String, Identifiable {
    case expenditure, avgIntake, trendDelta, constant, windowDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expenditure: "Expenditure"
        case .avgIntake:   "Average Intake"
        case .trendDelta:  "Trend Δ"
        case .constant:    "7700 kcal/kg"
        case .windowDays:  "Window Days"
        }
    }

    var body: String {
        switch self {
        case .expenditure:
            return "What your body actually burns per day — including BMR, NEAT, and whatever activity the last two weeks looked like. The engine learns this from your real intake plus your weight trend; it doesn't trust any formula in isolation."
        case .avgIntake:
            return "The mean calories per day across the days you logged in the window. The engine ignores empty days so a Saturday off doesn't drag your average down."
        case .trendDelta:
            return "How much your weight trend moved during the window. Trend weight is a smoothed line through your daily weigh-ins, so single-day water swings don't trip the engine. Positive means trending up; negative means trending down."
        case .constant:
            return "Energy density of body-weight change. One kilogram of body mass averages about 7700 kcal. The engine uses this to convert weight movement into the kcal surplus or deficit it implies."
        case .windowDays:
            return "How many days the engine averaged over. Default is 14 — long enough to smooth out daily noise, short enough that your expenditure responds to real changes."
        }
    }
}

// MARK: - Term Explainer Sheet

/// Presents the definition and current value for one equation variable.
private struct TermExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let term: EquationTerm
    let value: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
                    Text(term.title)
                        .font(BulkAITheme.Typography.title3)
                        .foregroundStyle(.white)

                    Text(value)
                        .font(BulkAITheme.Typography.display)
                        .foregroundStyle(BulkAITheme.Color.accent)
                        .monospacedDigit()

                    Text(term.body)
                        .font(BulkAITheme.Typography.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BulkAITheme.Spacing.lg)
            }
            .background(BulkAITheme.Color.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Dynamic TDEE Explainer

/// Shows the energy-balance equation with the user's live numbers plugged in.
///
/// Each variable is tappable and reveals a sheet that explains what the engine
/// is actually doing — this is Phase G's "engine math is visible" pitch.
/// All values are read from `EngineState` and `FoodStore`; no init arguments needed.
struct DynamicTDEEExplainer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(EngineState.self) var engineState
    @Environment(FoodStore.self) var foodStore
    @AppStorage("useMetric") var useMetric: Bool = false

    @State private var selectedTerm: EquationTerm?

    // MARK: - Derived values

    private var windowDays: Int {
        let trend = engineState.snapshot.trend
        return trend.count >= Expenditure.defaultWindowDays ? Expenditure.defaultWindowDays : max(1, trend.count)
    }

    /// Mean kcal/day over the last 14 logged days (ignores empty days).
    private var avgIntakeKcal: Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(windowDays - 1), to: calendar.startOfDay(for: .now)) ?? .now

        var dailyTotals: [Date: Int] = [:]
        for entry in foodStore.entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            guard day >= cutoff else { continue }
            dailyTotals[day, default: 0] += entry.calories
        }

        guard !dailyTotals.isEmpty else { return 0 }
        let total = dailyTotals.values.reduce(0, +)
        return total / dailyTotals.count
    }

    /// kg change of the smoothed trend over the window.
    private var trendDeltaKg: Double {
        let trend = engineState.snapshot.trend
        guard trend.count >= 2 else { return 0 }

        let last = trend[trend.count - 1]
        let cutoffIndex = max(0, trend.count - windowDays)
        let first = trend[cutoffIndex]
        return last.kg - first.kg
    }

    private var expenditureKcal: Int {
        guard let kcal = engineState.snapshot.expenditure?.kcalPerDay else { return 0 }
        return Int(kcal.rounded())
    }

    // MARK: - Formatted display values

    private var expenditureDisplay: String {
        expenditureKcal > 0 ? "\(expenditureKcal)" : "—"
    }

    private var avgIntakeDisplay: String {
        avgIntakeKcal > 0 ? "\(avgIntakeKcal)" : "—"
    }

    private var trendDeltaDisplay: String {
        String(format: "%+.1f kg", trendDeltaKg)
    }

    private var windowDaysDisplay: String { "\(windowDays)" }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xl) {
                    heroSection
                    if let exp = engineState.snapshot.expenditure, exp.status == .holding {
                        holdingCard(estimate: exp)
                    }
                    equationCard
                    footerSection
                }
                .padding(.horizontal, BulkAITheme.Spacing.lg)
                .padding(.vertical, BulkAITheme.Spacing.xl)
            }
            .background(BulkAITheme.Color.background.ignoresSafeArea())
            .navigationTitle("Energy Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(item: $selectedTerm) { term in
            TermExplainerSheet(term: term, value: displayValue(for: term))
        }
    }

    // MARK: - Sections

    /// Surfaced above the equation card whenever the engine is in its
    /// Holding state. Tells the user that the displayed expenditure is the
    /// PRIOR estimate held in place — not a fresh computation — because the
    /// past 7 days don't have enough food + weight data to update reliably.
    private func holdingCard(estimate: ExpenditureEstimate) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            HStack(spacing: BulkAITheme.Spacing.sm) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BulkAITheme.Color.macroFat)
                Text("Holding")
                    .font(BulkAITheme.Typography.title3)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }

            Text(estimate.holdingReason ?? "Need more food + weight logs in the past 7 days.")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: BulkAITheme.Spacing.md) {
                metric(label: "FOOD LOGS",
                       value: "\(estimate.foodLogDays) / \(Expenditure.minIntakeDaysForFreshEstimate)")
                metric(label: "WEIGHT LOGS",
                       value: "\(estimate.weightLogDays) / \(Expenditure.minTrendDaysForFreshEstimate)")
                Spacer(minLength: 0)
            }
            .padding(.top, BulkAITheme.Spacing.xxs)
        }
        .padding(BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg)
                .fill(BulkAITheme.Color.macroFat.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg)
                        .stroke(BulkAITheme.Color.macroFat.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.6)
            Text(value)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Your engine math, exposed.")
                .font(BulkAITheme.Typography.title)
                .foregroundStyle(.white)

            Text("Every weekly check-in starts here. Tap any term to see what the engine is doing.")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var equationCard: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                    symbolRow
                    valueRow
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BulkAITheme.Spacing.lg)
        .background(BulkAITheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous))
    }

    // Row 1: symbol/label tokens
    private var symbolRow: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            termButton("expenditure", color: BulkAITheme.Color.macroCalories, term: .expenditure)
            opText("=")
            termButton("avg intake", color: BulkAITheme.Color.macroCarbs, term: .avgIntake)
            opText("−")
            opText("(")
            termButton("trend Δ", color: BulkAITheme.Color.macroProtein, term: .trendDelta)
            opText("×")
            termButton("7700", color: BulkAITheme.Color.macroFat, term: .constant)
            opText(")")
            opText("/")
            termButton("window days", color: .white.opacity(0.9), term: .windowDays)
        }
    }

    // Row 2: numeric values aligned below symbols
    private var valueRow: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            valueText(expenditureDisplay)
            valueSpacer("=")
            valueText(avgIntakeDisplay)
            valueSpacer("−")
            valueSpacer("(")
            valueText(trendDeltaDisplay)
            valueSpacer("×")
            valueText("7700")
            valueSpacer(")")
            valueSpacer("/")
            valueText(windowDaysDisplay)
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("WHY THIS MATTERS")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.2)

            Text("Most apps use a static TDEE formula — they ask your age and weight once and never update. Bulk AI rebuilds expenditure every week from the data you actually logged. When your math is wrong, you'll see it here, not three months later on the scale.")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sub-view helpers

    @ViewBuilder
    private func termButton(_ label: String, color: Color, term: EquationTerm) -> some View {
        Button {
            selectedTerm = term
        } label: {
            Text(label)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func opText(_ symbol: String) -> some View {
        Text(symbol)
            .font(BulkAITheme.Typography.headline)
            .foregroundStyle(.white.opacity(0.45))
    }

    @ViewBuilder
    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(BulkAITheme.Typography.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))
    }

    /// Invisible spacer that mirrors the width of an operator token so values
    /// stay vertically aligned beneath their corresponding symbol.
    @ViewBuilder
    private func valueSpacer(_ symbol: String) -> some View {
        Text(symbol)
            .font(BulkAITheme.Typography.headline)
            .hidden()
    }

    // MARK: - Helpers

    private func displayValue(for term: EquationTerm) -> String {
        switch term {
        case .expenditure: return expenditureDisplay
        case .avgIntake:   return avgIntakeDisplay
        case .trendDelta:  return trendDeltaDisplay
        case .constant:    return "7700 kcal/kg"
        case .windowDays:  return windowDaysDisplay
        }
    }
}

// MARK: - Preview

#Preview("DynamicTDEEExplainer — populated") {
    // Realistic dummy data: 14 trend points, a handful of food entries.
    let engineState = EngineState(
        weightStore: WeightStore(),
        foodStore: FoodStore()
    )

    DynamicTDEEExplainer()
        .environment(engineState)
        .environment(FoodStore())
        .preferredColorScheme(.dark)
}

#Preview("DynamicTDEEExplainer — no data") {
    DynamicTDEEExplainer()
        .environment(EngineState(weightStore: WeightStore(), foodStore: FoodStore()))
        .environment(FoodStore())
        .preferredColorScheme(.dark)
}
