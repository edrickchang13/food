import SwiftUI
import BulkAIEngine

/// Top-level Strategy screen. Composes the components produced in Phase E:
///
/// - `StrategyHeader` — collapsing big "STRATEGY" wordmark
/// - `ActionPillCarousel` — horizontal scroll of 5 navigation pills
/// - `CheckInCountdownRing` — circular countdown to the next weekly check-in
/// - `CoachedProgramCard` — 7-day macro plan via MacroWeekChart
/// - `WeightGoalCard` — 3-column current / goal / weekly stats
///
/// Reads engine + profile state through the existing `@Environment` stores so
/// the screen stays parametric — every section is driven by snapshot data.
///
/// Reference screens live under `~/Downloads/macrofactor-screens/`:
/// IMG_6473.PNG / IMG_6474.PNG / IMG_6475.PNG.
struct StrategyView: View {
    @Environment(EngineState.self) private var engineState
    @Environment(ProfileStore.self) private var profileStore
    @AppStorage("useMetric") private var useMetric: Bool = false

    @State private var scrollOffset: CGFloat = 0
    @State private var pendingAction: StrategyAction?

    /// Pixels of upward scroll before the big header collapses to the compact strip.
    private static let collapseThreshold: CGFloat = 56

    private var profile: UserProfile { profileStore.profile }

    var body: some View {
        ZStack(alignment: .top) {
            scrollContent

            // Header overlay so the compact strip can pin to the top of the
            // screen while the big wordmark scrolls with content.
            StrategyHeader(isCollapsed: scrollOffset < -Self.collapseThreshold)
                .allowsHitTesting(scrollOffset < -Self.collapseThreshold)
        }
        .background(BulkAITheme.Color.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.name),
                message: Text("This flow ships in Phase F."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: BulkAITheme.Spacing.lg) {
                // The big STRATEGY title lives inside the scroll so it pushes
                // the rest of the content down. The compact strip in the top
                // overlay covers it once the user scrolls past the threshold.
                StrategyHeader(isCollapsed: false)

                ActionPillCarousel(
                    onNewGoal: { pendingAction = .newGoal },
                    onEditGoal: { pendingAction = .editGoal },
                    onNewProgram: { pendingAction = .newProgram },
                    onEditProgram: { pendingAction = .editProgram },
                    onChangeCheckInDay: { pendingAction = .changeCheckInDay }
                )

                CheckInCountdownRing(
                    daysRemaining: engineState.daysUntilCheckIn,
                    progress: engineState.checkInProgress,
                    goalLabel: "GOAL",
                    goalValue: goalLabel,
                    checkInLabel: "CHECK-IN",
                    checkInValue: checkInLabel,
                    onTap: { pendingAction = .checkIn }
                )
                .padding(.horizontal, BulkAITheme.Spacing.md)
                .padding(.vertical, BulkAITheme.Spacing.md)

                inProgressSection
                    .padding(.horizontal, BulkAITheme.Spacing.md)

                // Bottom padding leaves clearance for the global tab bar.
                Color.clear.frame(height: 100)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, newValue in
            scrollOffset = -newValue
        }
    }

    // MARK: - Sections

    private var inProgressSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            Text("IN PROGRESS")
                .font(BulkAITheme.Typography.caption2)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))

            CoachedProgramCard(
                plan: engineState.snapshot.dailyPlan,
                weekdayLetters: ["S", "M", "T", "W", "T", "F", "S"],
                onTap: { pendingAction = .editProgram }
            )

            WeightGoalCard(
                currentWeightKg: profile.weightKg,
                goalWeightKg: profile.goalWeightKg,
                weeklyChangeKg: profile.weeklyChangeKg,
                useImperial: !useMetric,
                onTap: { pendingAction = .editGoal }
            )
        }
    }

    // MARK: - Derived labels

    /// Short, human-friendly goal label shown under the countdown ring.
    /// Phase E surfaces the macro goal + signed weekly rate; Phase F+G
    /// expand this into multi-line goal copy once richer goals exist.
    private var goalLabel: String {
        switch profile.goal {
        case .maintain:
            return "Maintain weight"
        case .lose, .gain:
            let kg = profile.weeklyChangeKg ?? 0
            let sign = profile.goal == .lose ? "−" : "+"
            if useMetric {
                return "\(sign)\(formattedRate(kg)) kg/wk"
            }
            let lb = kg * 2.20462
            return "\(sign)\(formattedRate(lb)) lb/wk"
        }
    }

    /// Check-in day label. When due today, swap in "Today" so the metadata
    /// row keeps a consistent visual weight rather than dropping a day name.
    private var checkInLabel: String {
        if engineState.daysUntilCheckIn == 0 {
            return "Today"
        }
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: engineState.daysUntilCheckIn, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    private func formattedRate(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs.rounded() == abs { return String(Int(abs)) }
        return String(format: "%.1f", abs)
    }
}

/// Five enum cases driving Strategy's placeholder alerts. Each pill /
/// card route maps to one. Phase F replaces the alert with a real
/// destination per case.
private enum StrategyAction: Identifiable {
    case newGoal, editGoal, newProgram, editProgram, changeCheckInDay, checkIn

    var id: String { name }

    var name: String {
        switch self {
        case .newGoal: "New Goal"
        case .editGoal: "Edit Goal"
        case .newProgram: "New Program"
        case .editProgram: "Edit Program"
        case .changeCheckInDay: "Change Check-In Day"
        case .checkIn: "Check-In"
        }
    }
}
