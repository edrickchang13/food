import Foundation

public enum CheckInDecision: String, Codable, Sendable {
    case accepted
    case adjusted
    case skipped
}

public struct CheckInProposal: Equatable, Codable, Sendable {
    public let day: CalendarDay
    public let proposedPlan: DailyPlan
    public let priorExpenditureKcalPerDay: Double
    public let newExpenditure: ExpenditureEstimate
    public let trendDeltaKg: Double?

    public init(
        day: CalendarDay,
        proposedPlan: DailyPlan,
        priorExpenditureKcalPerDay: Double,
        newExpenditure: ExpenditureEstimate,
        trendDeltaKg: Double?
    ) {
        self.day = day
        self.proposedPlan = proposedPlan
        self.priorExpenditureKcalPerDay = priorExpenditureKcalPerDay
        self.newExpenditure = newExpenditure
        self.trendDeltaKg = trendDeltaKg
    }
}

public struct CheckInRecord: Equatable, Codable, Sendable {
    public let day: CalendarDay
    public let decision: CheckInDecision
    public let proposal: CheckInProposal
    /// The plan actually applied (may differ from the proposed plan if the user adjusted).
    /// `nil` when the check-in was skipped.
    public let appliedPlan: DailyPlan?

    public init(day: CalendarDay, decision: CheckInDecision, proposal: CheckInProposal, appliedPlan: DailyPlan?) {
        self.day = day
        self.decision = decision
        self.proposal = proposal
        self.appliedPlan = appliedPlan
    }
}

public enum WeeklyCheckIn {
    public static let cadenceDays: Int = 7

    /// True if a check-in should be offered today.
    ///
    /// - If there has been no check-in yet, the user must have completed onboarding at least
    ///   `cadenceDays` ago (the engine needs data to compute against).
    /// - Otherwise, at least `cadenceDays` must have elapsed since the last check-in regardless
    ///   of whether the user accepted, adjusted, or skipped.
    public static func isDue(
        lastCheckInDay: CalendarDay?,
        onboardingDay: CalendarDay,
        today: CalendarDay,
        calendar: Calendar = .bulkAI
    ) -> Bool {
        if let last = lastCheckInDay {
            return today.daysSince(last, in: calendar) >= cadenceDays
        }
        return today.daysSince(onboardingDay, in: calendar) >= cadenceDays
    }

    /// Builds a proposal from the engine's current view of the world. The caller decides whether
    /// to show it, and records the user's response with `recordDecision(...)`.
    public static func makeProposal(
        today: CalendarDay,
        priorExpenditureKcalPerDay: Double,
        newExpenditure: ExpenditureEstimate,
        weightKg: Double,
        leanBodyMassKg: Double?,
        target: WeeklyTarget,
        trend: [TrendPoint],
        calendar: Calendar = .bulkAI
    ) -> CheckInProposal {
        let plan = TargetMacros.plan(
            expenditureKcalPerDay: newExpenditure.kcalPerDay,
            weightKg: weightKg,
            leanBodyMassKg: leanBodyMassKg,
            target: target
        )
        let trendDelta = weekOverWeekTrendDelta(trend: trend, today: today, calendar: calendar)
        return CheckInProposal(
            day: today,
            proposedPlan: plan,
            priorExpenditureKcalPerDay: priorExpenditureKcalPerDay,
            newExpenditure: newExpenditure,
            trendDeltaKg: trendDelta
        )
    }

    public static func recordDecision(
        proposal: CheckInProposal,
        decision: CheckInDecision,
        adjustedPlan: DailyPlan? = nil
    ) -> CheckInRecord {
        let applied: DailyPlan?
        switch decision {
        case .accepted: applied = proposal.proposedPlan
        case .adjusted: applied = adjustedPlan ?? proposal.proposedPlan
        case .skipped: applied = nil
        }
        return CheckInRecord(
            day: proposal.day,
            decision: decision,
            proposal: proposal,
            appliedPlan: applied
        )
    }

    private static func weekOverWeekTrendDelta(
        trend: [TrendPoint],
        today: CalendarDay,
        calendar: Calendar
    ) -> Double? {
        guard let latest = trend.last(where: { $0.day <= today }) else { return nil }
        let priorDay = today.adding(days: -7, in: calendar)
        guard let prior = trend.last(where: { $0.day <= priorDay }) else { return nil }
        return latest.kg - prior.kg
    }
}
