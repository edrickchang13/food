import SwiftUI

/// Sheet presented by the center + button on the custom tab bar. Surfaces the
/// fastest paths to log food: free-text via AI / database search, or jumping
/// to the camera/voice flows on the Home tab.
struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodStore.self) private var foodStore
    @Environment(FoodDatabaseService.self) private var foodDatabase

    @State private var description: String = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var selectedItem: FoodDatabaseItem?
    @State private var loggedFeedback: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCopy
                    textInputCard
                    if isAnalyzing { analyzingRow }
                    if let errorMessage { errorBanner(errorMessage) }
                    if let loggedFeedback { successBanner(loggedFeedback) }
                    searchResultsSection
                }
                .padding(20)
            }
            .background(AppColors.appBackground)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedItem) { item in
                QuickAddPortionSheet(item: item) { entry in
                    foodStore.addEntry(entry)
                    loggedFeedback = "Logged \(entry.name)."
                    description = ""
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                inputFocused = true
            }
        }
    }

    // MARK: - Sections

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Type what you ate")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Bulk AI checks 6,900+ verified foods + Open Food Facts as you type, then falls back to AI parsing for free-form descriptions.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var textInputCard: some View {
        VStack(spacing: 12) {
            TextField("e.g. 150g chicken breast", text: $description, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .focused($inputFocused)
                .padding(14)
                .background(AppColors.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .autocorrectionDisabled(false)

            Button {
                Task { await aiAnalyze() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Parse with AI")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.calorie)
            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
        }
    }

    private var analyzingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Calling Gemini…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.system(.subheadline, design: .rounded))
        }
    }

    private var searchResultsSection: some View {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let local = trimmed.isEmpty ? [] : foodDatabase.search(trimmed, limit: 15)
        return Group {
            if !local.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Matches in database")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    VStack(spacing: 0) {
                        ForEach(local) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                row(for: item)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                            }
                            .buttonStyle(.plain)
                            if item.id != local.last?.id {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                    .background(AppColors.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: FoodDatabaseItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            sourceBadge(for: item.source)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(Int(item.caloriesPer100g)) kcal · P \(Int(item.proteinPer100g)) / C \(Int(item.carbsPer100g)) / F \(Int(item.fatPer100g)) per 100g")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func sourceBadge(for source: FoodDatabaseSource) -> some View {
        switch source {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        case .aiEstimated:
            Image(systemName: "sparkle")
                .foregroundStyle(.tint)
                .font(.system(size: 14))
        }
    }

    // MARK: - AI parse

    private func aiAnalyze() async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        loggedFeedback = nil
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await GeminiService.analyzeTextInput(
                description: trimmed,
                foodDatabase: foodDatabase
            )
            let entry = FoodEntry(
                name: result.name,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                timestamp: .now,
                source: .textInput,
                mealType: MealType.currentMeal,
                sugar: result.sugar,
                addedSugar: result.addedSugar,
                fiber: result.fiber,
                saturatedFat: result.saturatedFat,
                monounsaturatedFat: result.monounsaturatedFat,
                polyunsaturatedFat: result.polyunsaturatedFat,
                cholesterol: result.cholesterol,
                sodium: result.sodium,
                potassium: result.potassium,
                servingSizeGrams: result.servingSizeGrams
            )
            foodStore.addEntry(entry)
            loggedFeedback = "Logged \(result.calories) kcal — \(result.name)."
            description = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Picks portion size for a database item, then constructs a FoodEntry.
struct QuickAddPortionSheet: View {
    let item: FoodDatabaseItem
    let onLog: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var grams: Double = 100
    @State private var mealType: MealType = .currentMeal

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    Stepper(value: $grams, in: 5...2000, step: 5) {
                        HStack {
                            Text("Portion")
                            Spacer()
                            Text("\(Int(grams)) g").monospacedDigit()
                        }
                    }
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }
                Section("Will log") {
                    let multiplier = grams / 100
                    statRow("Calories", "\(Int((item.caloriesPer100g * multiplier).rounded())) kcal")
                    statRow("Protein", "\(Int((item.proteinPer100g * multiplier).rounded())) g")
                    statRow("Carbs", "\(Int((item.carbsPer100g * multiplier).rounded())) g")
                    statRow("Fat", "\(Int((item.fatPer100g * multiplier).rounded())) g")
                }
            }
            .navigationTitle("Log portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log") {
                        let multiplier = grams / 100
                        let entry = FoodEntry(
                            name: "\(Int(grams))g \(item.name.lowercased())",
                            calories: Int((item.caloriesPer100g * multiplier).rounded()),
                            protein: Int((item.proteinPer100g * multiplier).rounded()),
                            carbs: Int((item.carbsPer100g * multiplier).rounded()),
                            fat: Int((item.fatPer100g * multiplier).rounded()),
                            timestamp: .now,
                            source: .manual,
                            mealType: mealType,
                            fiber: item.fiberPer100g.map { $0 * multiplier },
                            servingSizeGrams: grams
                        )
                        onLog(entry)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
