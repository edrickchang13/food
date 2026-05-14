import SwiftUI

// MARK: - StandardRateTier

/// Named percent-of-bodyweight weekly-rate tiers for the goal-rate picker.
///
/// Standard 0.45 %/wk maps to roughly +0.86 lb/wk at 190 lb (86 kg),
/// matching the MacroFactor reference. Slower and Faster bracket it at
/// 0.25 %/wk and 0.65 %/wk respectively.
enum StandardRateTier: String, CaseIterable, Identifiable {
    case slower, standard, faster

    var id: String { rawValue }

    /// Fraction of bodyweight gained or lost per week (e.g. 0.0045 = 0.45 %).
    var fractionPerWeek: Double {
        switch self {
        case .slower:   return 0.0025
        case .standard: return 0.0045
        case .faster:   return 0.0065
        }
    }

    var displayName: String {
        switch self {
        case .slower:   return "Slower"
        case .standard: return "Standard"
        case .faster:   return "Faster"
        }
    }

    /// Absolute rate in kg/wk for a given bodyweight.
    func weeklyRateKg(forBodyweightKg weightKg: Double) -> Double {
        weightKg * fractionPerWeek
    }
}

// MARK: - EditGoalFlow

/// Top-level orchestrator for the two-step Edit Goal wizard.
///
/// Step 0: `EditGoal_WeightAndRate` — target weight ruler and rate picker.
/// Step 1: `EditGoal_Review` — confirmation diff cards.
///
/// The wizard reads initial values from `ProfileStore` and writes the final
/// draft back on "Done". A `WizardProgressUnderline` underpins the nav bar
/// for continuous animated step feedback.
///
/// Rate selection is now percent-of-bodyweight: Standard = 0.45 %/wk,
/// Slower = 0.25 %/wk, Faster = 0.65 %/wk. Custom retains a free Slider.
struct EditGoalFlow: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ProfileStore.self) var profileStore
    @AppStorage("useMetric") var useMetric: Bool = false

    @State var currentStep: Int = 0
    @State var draftGoalWeightKg: Double = 0
    @State var draftWeeklyChangeKg: Double = 0.5
    @State var draftIsCustomRate: Bool = false
    @State var draftStandardTier: StandardRateTier = .standard

    // MARK: - Helpers

    private var useImperial: Bool { !useMetric }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WizardProgressUnderline(stepCount: 2, currentStep: currentStep)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeOut, value: currentStep)

                bottomButton
            }
            .background(BulkAITheme.Color.background)
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear(perform: loadDraftFromStore)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            EditGoal_WeightAndRate(
                targetWeightKg: $draftGoalWeightKg,
                weeklyChangeKg: $draftWeeklyChangeKg,
                isCustomRate: $draftIsCustomRate,
                standardTier: $draftStandardTier,
                currentWeightKg: profileStore.profile.weightKg,
                useImperial: useImperial
            )
        default:
            EditGoal_Review(
                currentWeightKg: profileStore.profile.weightKg,
                originalGoalWeightKg: profileStore.profile.goalWeightKg,
                draftGoalWeightKg: draftGoalWeightKg,
                originalWeeklyChangeKg: profileStore.profile.weeklyChangeKg,
                draftWeeklyChangeKg: draftWeeklyChangeKg,
                useImperial: useImperial
            )
        }
    }

    // MARK: - Bottom button

    private var bottomButton: some View {
        Button(action: handleButtonTap) {
            Text(currentStep == 0 ? "Next" : "Done")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BulkAITheme.Spacing.md)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
        }
        .padding(.horizontal, BulkAITheme.Spacing.lg)
        .padding(.bottom, BulkAITheme.Spacing.lg)
        .background(.white.opacity(0.04))
    }

    // MARK: - Actions

    private func handleButtonTap() {
        if currentStep == 0 {
            withAnimation(.easeOut) {
                currentStep = 1
            }
        } else {
            commitAndDismiss()
        }
    }

    private func commitAndDismiss() {
        // ProfileStore exposes `profile` as private(set) post-P22 — direct
        // field mutation on the store-owned value is no longer permitted.
        // Take a local mutable copy, apply the wizard's two draft fields,
        // round-trip through the new save(_:) API.
        var draft = profileStore.profile
        draft.goalWeightKg = draftGoalWeightKg
        draft.weeklyChangeKg = draftWeeklyChangeKg
        profileStore.save(draft)
        dismiss()
    }

    // MARK: - Initialise draft from store

    /// Detects whether a saved kg/wk rate matches a named tier for the user's
    /// current bodyweight, using a ±0.05 kg/wk tolerance to survive floating-
    /// point round-trips. Returns nil if no tier matches (=> Custom).
    private func tierFor(rateKg: Double, weightKg: Double) -> StandardRateTier? {
        let tolerance: Double = 0.05
        for tier in StandardRateTier.allCases {
            let tierKg = tier.weeklyRateKg(forBodyweightKg: weightKg)
            if abs(tierKg - rateKg) < tolerance { return tier }
        }
        return nil
    }

    private func loadDraftFromStore() {
        let profile = profileStore.profile
        draftGoalWeightKg = profile.goalWeightKg ?? profile.weightKg
        let savedRate = profile.weeklyChangeKg ?? StandardRateTier.standard.weeklyRateKg(forBodyweightKg: profile.weightKg)
        draftWeeklyChangeKg = savedRate
        if let matched = tierFor(rateKg: savedRate, weightKg: profile.weightKg) {
            draftIsCustomRate = false
            draftStandardTier = matched
        } else {
            draftIsCustomRate = true
            draftStandardTier = .standard
        }
    }
}

// MARK: - Preview

#Preview("EditGoalFlow – step 0") {
    let store = ProfileStore()
    return EditGoalFlow()
        .environment(store)
        .preferredColorScheme(.dark)
}

#Preview("EditGoalFlow – step 1") {
    let store = ProfileStore()
    let flow = EditGoalFlow()
    // Jump straight to review for easier visual iteration.
    return flow
        .onAppear { }
        .environment(store)
        .preferredColorScheme(.dark)
}
