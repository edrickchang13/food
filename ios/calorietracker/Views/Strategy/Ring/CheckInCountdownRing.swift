import SwiftUI

/// A Strategy-screen wrapper around `CountdownRing` that binds engine state to
/// the ring's visual and adds the two-column "GOAL / CHECK-IN" metadata row
/// below it.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6473.PNG` — the green arc
/// fills as the 7-day cadence elapses; zero days shows "Check-in today" in
/// the subtitle and a fully filled ring.
///
/// The entire component is a `Button` so it routes to the check-in flow on tap.
struct CheckInCountdownRing: View {

    // MARK: Input

    /// Whole days remaining until the next check-in (0 means due today).
    let daysRemaining: Int
    /// Fraction of the 7-day cadence that has elapsed. Clamped to 0…1 internally.
    let progress: Double
    /// All-caps label for the left metadata column (pass `"GOAL"`).
    let goalLabel: String
    /// Human-readable goal description — e.g. "Maintain weight".
    let goalValue: String
    /// All-caps label for the right metadata column (pass `"CHECK-IN"`).
    let checkInLabel: String
    /// Day-of-week or "Today" when the check-in is due — e.g. "Sunday".
    let checkInValue: String
    /// Called when the user taps the component.
    var onTap: () -> Void

    // MARK: Derived

    private var centerTitle: String {
        String(daysRemaining)
    }

    private var centerSubtitle: String {
        switch daysRemaining {
        case 0: return "Check-in today"
        case 1: return "DAY until check-in"
        default: return "DAYS until check-in"
        }
    }

    // MARK: Body

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: BulkAITheme.Spacing.lg) {
                CountdownRing(
                    progress: progress,
                    centerTitle: centerTitle,
                    centerSubtitle: centerSubtitle,
                    accent: BulkAITheme.Color.macroCarbs,
                    size: 200
                )

                metadataRow
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Check-in countdown, \(daysRemaining) days remaining")
    }

    // MARK: Metadata

    private var metadataRow: some View {
        HStack(spacing: 0) {
            metadataColumn(label: goalLabel, value: goalValue)
            Spacer()
            metadataColumn(label: checkInLabel, value: checkInValue)
        }
        .padding(.horizontal, BulkAITheme.Spacing.xl)
    }

    private func metadataColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            Text(label.uppercased())
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)

            Text(value)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview("CheckInCountdownRing") {
    VStack(spacing: BulkAITheme.Spacing.xxl) {
        // 7 days remaining — fresh cadence start, ring empty.
        CheckInCountdownRing(
            daysRemaining: 7,
            progress: 0,
            goalLabel: "GOAL",
            goalValue: "Maintain weight",
            checkInLabel: "CHECK-IN",
            checkInValue: "Sunday",
            onTap: { }
        )

        Divider().background(.white.opacity(0.08))

        // 3 days remaining — ~57 % elapsed.
        CheckInCountdownRing(
            daysRemaining: 3,
            progress: 0.57,
            goalLabel: "GOAL",
            goalValue: "Lose 0.5 kg/wk",
            checkInLabel: "CHECK-IN",
            checkInValue: "Sunday",
            onTap: { }
        )

        Divider().background(.white.opacity(0.08))

        // 0 days remaining — check-in due today, ring full.
        CheckInCountdownRing(
            daysRemaining: 0,
            progress: 1,
            goalLabel: "GOAL",
            goalValue: "Lose 0.5 kg/wk",
            checkInLabel: "CHECK-IN",
            checkInValue: "Today",
            onTap: { }
        )
    }
    .padding(BulkAITheme.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
