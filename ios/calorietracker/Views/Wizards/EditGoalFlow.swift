import SwiftUI

// MARK: - EditGoalFlow

/// Top-level orchestrator for the two-step Edit Goal wizard.
///
/// Step 0: `EditGoal_WeightAndRate` — target weight ruler and rate picker.
/// Step 1: `EditGoal_Review` — confirmation diff cards.
///
/// The wizard reads initial values from `ProfileStore` and writes the final
/// draft back on "Done". A `WizardProgressUnderline` underpin the nav bar
/// for continuous animated step feedback.
struct EditGoalFlow: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ProfileStore.self) var profileStore
    @AppStorage("useMetric") var useMetric: Bool = false

    @State var currentStep: Int = 0
    @State var draftGoalWeightKg: Double = 0
    @State var draftWeeklyChangeKg: Double = 0.5
    @State var draftIsCustomRate: Bool = false

    // MARK: - Helpers

    private var useImperial: Bool { !useMetric }

    private var standardRates: [Double] { [0.25, 0.5, 0.75] }

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
        profileStore.profile.goalWeightKg = draftGoalWeightKg
        profileStore.profile.weeklyChangeKg = draftWeeklyChangeKg
        profileStore.profile.save()
        dismiss()
    }

    // MARK: - Initialise draft from store

    private func loadDraftFromStore() {
        let profile = profileStore.profile
        draftGoalWeightKg = profile.goalWeightKg ?? profile.weightKg
        let savedRate = profile.weeklyChangeKg ?? 0.5
        draftWeeklyChangeKg = savedRate
        draftIsCustomRate = !standardRates.contains(savedRate)
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
