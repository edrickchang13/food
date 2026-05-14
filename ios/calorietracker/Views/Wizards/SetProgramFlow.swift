import SwiftUI
import BulkAIEngine

// MARK: - ProgramPreference

/// The six diet-style preferences the user can choose in the Set Program wizard.
///
/// Matches the spec's four named diets (Balanced, Low Fat, Low Carb, Keto) plus
/// Coached (AI-driven) and High Protein. The 2x3 grid in `SetProgram_Preferences`
/// renders all six without layout changes.
enum ProgramPreference: String, CaseIterable, Identifiable {
    case coached
    case balanced
    case lowFat
    case lowCarb
    case keto
    case highProtein

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coached:     "Coached"
        case .balanced:    "Balanced"
        case .lowFat:      "Low Fat"
        case .lowCarb:     "Low Carb"
        case .keto:        "Keto"
        case .highProtein: "High Protein"
        }
    }

    var systemImage: String {
        switch self {
        case .coached:     "target"
        case .balanced:    "scalemass.fill"
        case .lowFat:      "drop.fill"
        case .lowCarb:     "leaf.fill"
        case .keto:        "flame.fill"
        case .highProtein: "figure.strengthtraining.traditional"
        }
    }

    var subtitle: String {
        switch self {
        case .coached:     "AI handles macros for you"
        case .balanced:    "Moderate of each macro"
        case .lowFat:      "Fat under 25% of calories"
        case .lowCarb:     "Carbs under 30% of calories"
        case .keto:        "~5% carb, ~70% fat"
        case .highProtein: "Protein boost for training"
        }
    }
}

// MARK: - SetProgramFlow

/// Top-level orchestrator for the two-step Set Program wizard.
///
/// Step 0: `SetProgram_Preferences` — 2-column preference grid.
/// Step 1: `SetProgram_Summary` — macro chart + rationale timeline.
///
/// On "Done" the wizard reshapes the engine's resolved plan to honor the
/// chosen diet preference, writes the result into `ProfileStore`, and dismisses.
/// A `WizardProgressUnderline` underpins the nav bar for continuous animated
/// step feedback.
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
        let kcal = plan?.kcalTarget ?? 2400
        let rawProtein = plan?.macros.proteinG ?? 150
        let rawFat = plan?.macros.fatG ?? 75
        let rawCarbs = plan?.macros.carbsG ?? 270
        let (p, f, c) = Self.reshape(
            kcal: kcal,
            proteinG: rawProtein,
            fatG: rawFat,
            carbsG: rawCarbs,
            preference: selectedPreference
        )
        profileStore.profile.customCalories = Int(kcal.rounded())
        profileStore.profile.customProtein = Int(p.rounded())
        profileStore.profile.customFat = Int(f.rounded())
        profileStore.profile.customCarbs = Int(c.rounded())
        profileStore.profile.save()
        dismiss()
    }

    // MARK: - Macro reshape

    /// Redistribute `(proteinG, fatG, carbsG)` to honor the selected diet preference
    /// while holding `kcal` constant. Pure function; returns a new tuple.
    ///
    /// Caloric coefficients: 4 kcal/g for protein and carbs, 9 kcal/g for fat.
    static func reshape(
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        preference: ProgramPreference
    ) -> (proteinG: Double, fatG: Double, carbsG: Double) {
        switch preference {
        case .coached, .balanced:
            // Engine default — no redistribution.
            return (proteinG, fatG, carbsG)

        case .lowFat:
            // Cap fat at 25% of calories. Roll remaining kcal into carbs.
            let cappedFat = min(fatG, kcal * 0.25 / 9)
            let leftover = kcal - proteinG * 4 - cappedFat * 9
            return (proteinG, cappedFat, max(0, leftover / 4))

        case .lowCarb:
            // Cap carbs at 30% of calories. Roll remaining kcal into fat.
            let cappedCarbs = min(carbsG, kcal * 0.30 / 4)
            let leftover = kcal - proteinG * 4 - cappedCarbs * 4
            return (proteinG, max(0, leftover / 9), cappedCarbs)

        case .keto:
            // 5% carb / 25% protein / 70% fat — fixed ratios from spec.
            let ketoCarbs = kcal * 0.05 / 4
            let ketoProtein = kcal * 0.25 / 4
            let ketoFat = kcal * 0.70 / 9
            return (ketoProtein, ketoFat, ketoCarbs)

        case .highProtein:
            // Bump protein to 35% of calories; pull from carbs first, then fat.
            let targetProtein = kcal * 0.35 / 4
            let extraKcal = max(0, targetProtein - proteinG) * 4
            let newCarbs = max(0, carbsG - extraKcal / 4)
            let pulledFromCarbs = (carbsG - newCarbs) * 4
            let stillNeeded = extraKcal - pulledFromCarbs
            let newFat = max(0, fatG - stillNeeded / 9)
            return (targetProtein, newFat, newCarbs)
        }
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
