import Foundation

/// The user's chosen relationship with the coaching engine. Determines whether the engine
/// owns the targets, shares ownership with the user, or stays silent.
public enum ProgramMode: String, Codable, Sendable, CaseIterable {
    /// Engine sets and auto-adjusts everything; user accepts weekly proposals.
    case coached
    /// Engine sets the weekly calorie budget; user can redistribute across days.
    case collaborative
    /// User sets all targets manually; engine tracks expenditure silently in the background.
    case manual

    /// Whether the engine writes its own targets into the user's plan.
    public var autoAdjustsTargets: Bool { self != .manual }

    /// Whether the weekly check-in flow surfaces a UI prompt to the user.
    public var promptsWeeklyCheckIn: Bool { self != .manual }

    /// Whether the user can redistribute the weekly calorie budget across individual days.
    public var allowsManualDailyDistribution: Bool { self == .collaborative }
}
