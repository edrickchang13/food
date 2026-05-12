import Foundation
import Observation
import BulkAIEngine

/// A snapshot of everything the engine currently knows. Re-computed by `refresh()`
/// whenever the underlying stores change or the day rolls over.
struct EngineSnapshot {
    var trend: [TrendPoint]
    var currentTrendKg: Double?
    var expenditure: ExpenditureEstimate?
    var dailyPlan: DailyPlan?
    var checkInDue: Bool
}

/// Bridges the existing app stores (UserProfile / WeightStore / FoodStore) into BulkAIEngine.
///
/// This is a thin adapter. All the math lives in the engine package; this class just
/// converts data shapes, persists the previous expenditure estimate, and surfaces
/// computed values for the UI.
@Observable
final class EngineState {
    @ObservationIgnored private let weightStore: WeightStore
    @ObservationIgnored private let foodStore: FoodStore

    private(set) var snapshot: EngineSnapshot = EngineSnapshot(
        trend: [],
        currentTrendKg: nil,
        expenditure: nil,
        dailyPlan: nil,
        checkInDue: false
    )

    private let priorExpenditureKey = "engine.priorExpenditureKcalPerDay"
    private let onboardingDateKey = "engine.onboardingDate"
    private let lastCheckInKey = "engine.lastCheckInDate"

    init(weightStore: WeightStore, foodStore: FoodStore) {
        self.weightStore = weightStore
        self.foodStore = foodStore
        observeStores()
        refresh()
    }

    // MARK: - Recompute

    func refresh(now: Date = .now) {
        guard let profile = UserProfile.load() else {
            snapshot = EngineSnapshot(trend: [], currentTrendKg: nil, expenditure: nil, dailyPlan: nil, checkInDue: false)
            return
        }

        let calendar = Calendar.bulkAI
        let today = CalendarDay(date: now, calendar: calendar)

        let trend = WeightTrend.compute(
            logs: Self.mapWeightLogs(weightStore.entries, calendar: calendar)
        )

        let bmr = profile.bmr
        let prior = persistedPriorExpenditure() ?? profile.tdee

        let expenditure = Expenditure.estimate(
            intakeLogs: Self.mapDailyIntakes(foodStore.entries, calendar: calendar),
            trend: trend,
            priorKcalPerDay: prior,
            bmrKcalPerDay: bmr,
            referenceDay: today,
            calendar: calendar
        )

        let target = Self.weeklyTarget(from: profile)
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: expenditure.kcalPerDay,
            weightKg: profile.weightKg,
            leanBodyMassKg: profile.bodyFatPercentage.map { (1 - $0) * profile.weightKg },
            target: target
        )

        let onboardingDay = persistedOnboardingDay() ?? today
        let lastCheckIn = persistedLastCheckInDay()
        let due = WeeklyCheckIn.isDue(
            lastCheckInDay: lastCheckIn,
            onboardingDay: onboardingDay,
            today: today,
            calendar: calendar
        )

        snapshot = EngineSnapshot(
            trend: trend,
            currentTrendKg: trend.last?.kg,
            expenditure: expenditure,
            dailyPlan: plan,
            checkInDue: due
        )
    }

    /// Persists the new prior. Call this after the user accepts a weekly check-in proposal.
    func commitNewPriorExpenditure(_ kcalPerDay: Double, on day: CalendarDay) {
        UserDefaults.standard.set(kcalPerDay, forKey: priorExpenditureKey)
        persist(day: day, forKey: lastCheckInKey)
    }

    /// Record that onboarding completed today, so check-in cadence has an anchor.
    func recordOnboardingComplete(on day: CalendarDay = CalendarDay(date: .now, calendar: .bulkAI)) {
        persist(day: day, forKey: onboardingDateKey)
    }

    // MARK: - Mappers (static so they're unit-testable in isolation)

    static func mapWeightLogs(_ entries: [WeightEntry], calendar: Calendar = .bulkAI) -> [WeightLog] {
        entries.map {
            WeightLog(day: CalendarDay(date: $0.date, calendar: calendar), kg: $0.weightKg)
        }
    }

    static func mapDailyIntakes(_ entries: [FoodEntry], calendar: Calendar = .bulkAI) -> [DailyIntake] {
        // FoodEntry.calories is per-entry kcal. We sum per day so the engine sees one
        // logical row per logged day (matches the "kcalIn[]" shape the formula expects).
        var dailyTotals: [CalendarDay: Double] = [:]
        for entry in entries {
            let day = CalendarDay(date: entry.timestamp, calendar: calendar)
            dailyTotals[day, default: 0] += Double(entry.calories)
        }
        return dailyTotals
            .map { DailyIntake(day: $0.key, kcal: $0.value) }
            .sorted { $0.day < $1.day }
    }

    static func weeklyTarget(from profile: UserProfile) -> WeeklyTarget {
        let goal: Goal = {
            switch profile.goal {
            case .lose: return .lose
            case .gain: return .gain
            case .maintain: return .maintain
            }
        }()
        // Convert kg/week to fraction of bodyweight per week.
        let kgPerWeek = profile.weeklyChangeKg ?? 0
        let weightKg = max(profile.weightKg, 1)
        let fraction = goal == .maintain ? 0 : kgPerWeek / weightKg
        return WeeklyTarget(goal: goal, weeklyRateAsFractionOfBodyweight: fraction)
    }

    // MARK: - Persistence helpers

    private func persistedPriorExpenditure() -> Double? {
        let stored = UserDefaults.standard.double(forKey: priorExpenditureKey)
        return stored > 0 ? stored : nil
    }

    private func persistedOnboardingDay() -> CalendarDay? {
        readDay(forKey: onboardingDateKey)
    }

    private func persistedLastCheckInDay() -> CalendarDay? {
        readDay(forKey: lastCheckInKey)
    }

    private func readDay(forKey key: String) -> CalendarDay? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return CalendarDay(year: parts[0], month: parts[1], day: parts[2])
    }

    private func persist(day: CalendarDay, forKey key: String) {
        UserDefaults.standard.set(day.description, forKey: key)
    }

    // MARK: - Wiring

    private func observeStores() {
        weightStore.onEntryAdded = { [weak self] _ in self?.refresh() }
        weightStore.onEntryDeleted = { [weak self] _ in self?.refresh() }
        foodStore.onEntriesChanged = { [weak self] in self?.refresh() }
    }
}
