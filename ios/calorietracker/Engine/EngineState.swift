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

    // `pendingRefresh` is only ever read/written from `scheduleDebouncedRefresh()`,
    // which is always called from store callbacks that run on the main thread.
    // `nonisolated(unsafe)` suppresses the Swift 6 cross-isolation warning; the
    // access pattern is safe by construction.
    @ObservationIgnored nonisolated(unsafe) private var pendingRefresh: Task<Void, Never>?
    private static let debounceWindow: Duration = .milliseconds(250)

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
    private let programModeKey = "engine.programMode"

    /// The user's chosen relationship with the coaching engine. Persisted to UserDefaults.
    /// Default is `.coached` so users coming from a fresh install get the full experience.
    var programMode: ProgramMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: programModeKey),
               let mode = ProgramMode(rawValue: raw) {
                return mode
            }
            return .coached
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: programModeKey)
            refresh()
        }
    }

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

        // Mirror the countdown into the App Group so CheckInCountdownWidget
        // can render the same numbers as the Strategy tab. Computed values
        // use the same anchor logic as `daysUntilCheckIn` / `checkInProgress`.
        CountdownSnapshotWriter.write(
            daysUntilCheckIn: daysUntilCheckIn,
            progress: checkInProgress
        )
    }

    /// User accepted (or adjusted) the proposal: advance the cadence AND update the
    /// prior expenditure to the new estimate so next week's ±15% clamp anchors here.
    func commitAcceptedCheckIn(newExpenditureKcalPerDay: Double, on day: CalendarDay) {
        UserDefaults.standard.set(newExpenditureKcalPerDay, forKey: priorExpenditureKey)
        persist(day: day, forKey: lastCheckInKey)
        refresh()
    }

    /// User skipped the proposal: advance the cadence so we don't re-prompt for 7 days,
    /// but do NOT update the prior expenditure. The next calc still anchors to the
    /// last value the user actually accepted.
    func commitSkippedCheckIn(on day: CalendarDay) {
        persist(day: day, forKey: lastCheckInKey)
        refresh()
    }

    /// Record that onboarding completed today, so check-in cadence has an anchor.
    func recordOnboardingComplete(on day: CalendarDay = CalendarDay(date: .now, calendar: .bulkAI)) {
        persist(day: day, forKey: onboardingDateKey)
        refresh()
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

    // MARK: - Check-in countdown (public surface for Strategy view)

    /// Number of whole days remaining until the next weekly check-in is due.
    /// Returns 0 when due today or overdue. Anchored to last accepted/skipped
    /// check-in, or to the onboarding date when the user hasn't checked in yet.
    var daysUntilCheckIn: Int {
        let calendar = Calendar.bulkAI
        let today = CalendarDay(date: .now, calendar: calendar)
        let anchor = persistedLastCheckInDay() ?? persistedOnboardingDay() ?? today
        let elapsed = today.daysSince(anchor, in: calendar)
        let remaining = WeeklyCheckIn.cadenceDays - elapsed
        return max(0, remaining)
    }

    /// Fraction of the current 7-day cadence that has elapsed. `1.0` when due
    /// today (the countdown ring fills the full circle), `0.0` immediately
    /// after a check-in. Used by the Strategy countdown ring.
    var checkInProgress: Double {
        let elapsed = WeeklyCheckIn.cadenceDays - daysUntilCheckIn
        return min(1.0, max(0.0, Double(elapsed) / Double(WeeklyCheckIn.cadenceDays)))
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

    /// Cancels any in-flight debounce task and starts a new 250 ms trailing-edge
    /// window. Only store-change callbacks use this path; direct callers (e.g.
    /// `commitAcceptedCheckIn`) keep calling `refresh()` synchronously so they
    /// see an up-to-date snapshot immediately.
    private func scheduleDebouncedRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.debounceWindow)
            } catch {
                // Task was cancelled (a newer change arrived); do nothing.
                return
            }
            guard !Task.isCancelled else { return }
            self?.refresh()
            // Release the Task reference so observers (and the unit test)
            // can distinguish "debounce idle" from "debounce armed". The
            // next store change immediately reassigns this.
            self?.pendingRefresh = nil
        }
    }

    private func observeStores() {
        weightStore.onEntryAdded = { [weak self] _ in self?.scheduleDebouncedRefresh() }
        weightStore.onEntryDeleted = { [weak self] _ in self?.scheduleDebouncedRefresh() }
        foodStore.onEntriesChanged = { [weak self] in self?.scheduleDebouncedRefresh() }
    }

#if DEBUG
    /// Exposed for unit testing the debounce mechanism only. Not part of the public API.
    var pendingRefreshForTesting: Task<Void, Never>? { pendingRefresh }
#endif
}
