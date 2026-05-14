import SwiftUI

struct OptionalNutrientGoalsSettingsView: View {
    let profile: UserProfile
    let useMetric: Bool

    @AppStorage(OptionalNutrientGoals.storageKey) private var storedGoalsData = Data()
    @State private var goals: OptionalNutrientGoals = .current
    @State private var editingNutrient: OptionalNutrient?
    @State private var isSuggesting = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await suggestGoals() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(BulkAITheme.Color.accent)
                            .frame(width: 22)
                        Text(isSuggesting ? "Analyzing" : "Suggest with AI")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isSuggesting {
                            ProgressView()
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSuggesting)

                Button {
                    save(.defaults)
                } label: {
                    Label {
                        Text("Reset Defaults")
                    } icon: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(BulkAITheme.Color.accent)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Separate from calorie, protein, carb, and fat goals.")
            }
            .listRowBackground(BulkAITheme.Color.surface)

            Section("Other Nutrients") {
                ForEach(OptionalNutrient.allCases) { nutrient in
                    Button {
                        editingNutrient = nutrient
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: nutrient.iconName)
                                .foregroundStyle(BulkAITheme.Color.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nutrient.displayName)
                                    .foregroundStyle(.primary)
                                Text(nutrient.goalStyle.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(goals.goal(for: nutrient)) \(nutrient.unit)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(BulkAITheme.Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(BulkAITheme.Color.background)
        .navigationTitle("Other Nutrients")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            goals = OptionalNutrientGoals.decoded(from: storedGoalsData)
        }
        .onChange(of: storedGoalsData) { _, newData in
            goals = OptionalNutrientGoals.decoded(from: newData)
        }
        .sheet(item: $editingNutrient) { nutrient in
            NutritionPickerSheet(
                label: nutrient.displayName,
                unit: nutrient.unit,
                currentValue: goals.goal(for: nutrient),
                range: nutrient.range,
                step: nutrient.step
            ) { value in
                save(goals.settingGoal(value, for: nutrient))
            }
        }
        .alert("AI Suggestion Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(_ newGoals: OptionalNutrientGoals) {
        let normalized = newGoals.mergedWithDefaults()
        goals = normalized
        storedGoalsData = normalized.encodedData
    }

    @MainActor
    private func suggestGoals() async {
        guard !isSuggesting else { return }
        isSuggesting = true
        defer { isSuggesting = false }

        do {
            let suggested = try await GeminiService.suggestOptionalNutrientGoals(
                profile: profile,
                currentGoals: goals,
                useMetric: useMetric
            )
            save(suggested)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
