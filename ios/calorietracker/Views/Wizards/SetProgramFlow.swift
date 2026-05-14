import SwiftUI
import BulkAIEngine

// MARK: - ProgramPreference

/// The six macro-distribution styles the user can choose in the Set Program wizard.
enum ProgramPreference: String, CaseIterable, Identifiable {
    case coached
    case balanced
    case standardFloor
    case cardioAndLifting
    case distributeEvenly
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coached: "Coached"
        case .balanced: "Balanced"
        case .standardFloor: "Standard Floor"
        case .cardioAndLifting: "Cardio & Lifting"
        case .distributeEvenly: "Distribute Evenly"
        case .high: "High"
        }
    }

    var systemImage: String {
        switch self {
        case .coached: "target"
        case .balanced: "scalemass.fill"
        case .standardFloor: "chart.bar.fill"
        case .cardioAndLifting: "figure.run"
        case .distributeEvenly: "equal.circle"
        case .high: "chart.line.uptrend.xyaxis"
        }
    }

    var subtitle: String {
        switch self {
        case .coached: "AI handles macros for you"
        case .balanced: "Equal fat and carb split"
        case .standardFloor: "Protein + fat floors only"
        case .cardioAndLifting: "Higher carbs on active days"
        case .distributeEvenly: "Same targets every day"
        case .high: "Aggressive protein target"
        }
    }
}

// MARK: - SetProgramFlow

/// Top-level orchestrator for the two-step Set Program wizard.
///
/// Step 0: `SetProgram_Preferences` — 2-column preference grid.
/// Step 1: `SetProgram_Summary` — macro chart + rationale timeline.
///
/// On "Done" the wizard writes the resolved macro plan into `ProfileStore` and
/// dismisses. A `WizardProgressUnderline` underpins the nav bar for continuous
/// animated step feedback.
struct SetProgramFlow: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ProfileStore.self) var profileStore
    @Environment(EngineState.self) var engineState

    @State var currentStep: Int = 0
    @State var selectedPreference: ProgramPreference = .coached

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
            .navigationTitle("Set Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            SetProgram_Preferences(selection: $selectedPreference)
        default:
            SetProgram_Summary(
                preference: selectedPreference,
                plan: engineState.snapshot.dailyPlan
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
            withAnimation(.easeOut) { currentStep = 1 }
        } else {
            commitAndDismiss()
        }
    }

    private func commitAndDismiss() {
        let plan = engineState.snapshot.dailyPlan
        profileStore.profile.customCalories = Int((plan?.kcalTarget ?? 2400).rounded())
        profileStore.profile.customProtein = Int((plan?.macros.proteinG ?? 150).rounded())
        profileStore.profile.customFat = Int((plan?.macros.fatG ?? 75).rounded())
        profileStore.profile.customCarbs = Int((plan?.macros.carbsG ?? 270).rounded())
        profileStore.profile.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("SetProgramFlow – step 0") {
    let store = ProfileStore()
    let engine = EngineState(weightStore: WeightStore(), foodStore: FoodStore())
    return SetProgramFlow()
        .environment(store)
        .environment(engine)
        .preferredColorScheme(.dark)
}

#Preview("SetProgramFlow – step 1") {
    let store = ProfileStore()
    let engine = EngineState(weightStore: WeightStore(), foodStore: FoodStore())
    return SetProgramFlow(currentStep: 1, selectedPreference: .balanced)
        .environment(store)
        .environment(engine)
        .preferredColorScheme(.dark)
}
