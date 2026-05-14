import SwiftUI

/// Small top-of-screen progress indicator shared by the Edit Goal and Set
/// Program wizards. Renders one short pill per step; the active step is a
/// solid white pill and earlier/later steps are muted on the dark track.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6476.PNG` (Edit Goal
/// step 1) — MacroFactor sits this underline just below the navigation
/// bar above the wizard content.
///
/// API:
/// - `stepCount`: total wizard steps, e.g. `2`
/// - `currentStep`: 0-based current step; clamped to `0..<stepCount`
///
/// The component is purely presentational. It animates between steps when
/// the parent updates `currentStep` so wizard navigation feels continuous.
struct WizardProgressUnderline: View {
    let stepCount: Int
    let currentStep: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pillHeight: CGFloat = 4
    private static let pillSpacing: CGFloat = 6

    private var clampedStep: Int {
        min(max(currentStep, 0), max(stepCount - 1, 0))
    }

    var body: some View {
        HStack(spacing: Self.pillSpacing) {
            ForEach(0..<max(stepCount, 1), id: \.self) { index in
                pill(active: index == clampedStep)
            }
        }
        .frame(height: Self.pillHeight)
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(clampedStep + 1) of \(stepCount)")
    }

    private func pill(active: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(active ? Color.white : BulkAITheme.Color.surfaceElevated)
            .frame(maxWidth: .infinity)
            .frame(height: Self.pillHeight)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: active)
    }
}

#Preview("WizardProgressUnderline") {
    VStack(spacing: BulkAITheme.Spacing.xl) {
        WizardProgressUnderline(stepCount: 2, currentStep: 0)
        WizardProgressUnderline(stepCount: 2, currentStep: 1)
        WizardProgressUnderline(stepCount: 3, currentStep: 1)
        WizardProgressUnderline(stepCount: 4, currentStep: 2)
    }
    .padding(.vertical, BulkAITheme.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
