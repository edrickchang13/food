import SwiftUI

/// Browse the bundled food database. Filter by category, search by name, tap
/// to enter a portion size and log directly to today's food log. Verified
/// items show a checkmark icon; AI-derived cache entries show a sparkle.
struct FoodDatabaseView: View {
    @Environment(FoodDatabaseService.self) private var foodDatabase
    @State private var searchText = ""
    @State private var categoryFilter: FoodDatabaseCategory?
    @State private var loggingItem: FoodDatabaseItem?
    @State private var remoteResults: [FoodDatabaseItem] = []
    @State private var isSearchingRemote = false
    @State private var searchTask: Task<Void, Never>?

    private var filteredItems: [FoodDatabaseItem] {
        let local = foodDatabase.search(searchText, limit: 200)
        let remoteIDs = Set(local.map { $0.id })
        let remoteOnly = remoteResults.filter { !remoteIDs.contains($0.id) }
        let base = local + remoteOnly
        guard let categoryFilter else { return base }
        return base.filter { $0.category == categoryFilter }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(label: "All", isSelected: categoryFilter == nil) {
                            categoryFilter = nil
                        }
                        ForEach(FoodDatabaseCategory.allCases, id: \.self) { cat in
                            categoryChip(label: cat.displayName, isSelected: categoryFilter == cat) {
                                categoryFilter = (categoryFilter == cat ? nil : cat)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                if filteredItems.isEmpty && !isSearchingRemote {
                    Text("No matches. Try a different search — Bulk AI also queries Open Food Facts for branded products as you type.")
                        .foregroundStyle(.secondary)
                        .font(.system(.subheadline, design: .rounded))
                } else {
                    ForEach(filteredItems) { item in
                        Button {
                            loggingItem = item
                        } label: {
                            row(for: item)
                        }
                    }
                    if isSearchingRemote {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching Open Food Facts…")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Food database")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .onChange(of: searchText) { _, newValue in
            // Cancel any in-flight remote search, debounce 300ms before firing
            // a new one so we don't hammer OFF on every keystroke.
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else {
                remoteResults = []
                isSearchingRemote = false
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                isSearchingRemote = true
                defer { isSearchingRemote = false }
                let results = await foodDatabase.searchIncludingRemote(trimmed, limit: 30)
                if Task.isCancelled { return }
                remoteResults = results
            }
        }
        .sheet(item: $loggingItem) { item in
            LogFoodDatabaseItemSheet(item: item)
        }
    }

    @ViewBuilder
    private func row(for item: FoodDatabaseItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    if !item.preparation.displayName.isEmpty {
                        Text("· \(item.preparation.displayName.lowercased())")
                            .foregroundStyle(.secondary)
                    }
                    sourceIcon(for: item.source)
                }
                .font(.system(.body, design: .rounded))
                Text("\(Int(item.caloriesPer100g)) kcal · P \(Int(item.proteinPer100g))g / C \(Int(item.carbsPer100g))g / F \(Int(item.fatPer100g))g per 100g")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func sourceIcon(for source: FoodDatabaseSource) -> some View {
        switch source {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(.caption2))
        case .aiEstimated:
            Image(systemName: "sparkle")
                .foregroundStyle(.tint)
                .font(.system(.caption2))
        }
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AppColors.calorie : AppColors.appCard)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LogFoodDatabaseItemSheet: View {
    let item: FoodDatabaseItem
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodStore.self) private var foodStore

    @State private var grams: Double = 100
    @State private var mealType: MealType = .currentMeal

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name + (item.preparation.displayName.isEmpty ? "" : ", \(item.preparation.displayName.lowercased())")) {
                    Stepper(value: $grams, in: 5...2000, step: 5) {
                        HStack { Text("Portion"); Spacer(); Text("\(Int(grams)) g").monospacedDigit() }
                    }
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                }
                Section("Will log") {
                    let multiplier = grams / 100
                    statRow("Calories", "\(Int((item.caloriesPer100g * multiplier).rounded())) kcal")
                    statRow("Protein", "\(Int((item.proteinPer100g * multiplier).rounded())) g")
                    statRow("Carbs", "\(Int((item.carbsPer100g * multiplier).rounded())) g")
                    statRow("Fat", "\(Int((item.fatPer100g * multiplier).rounded())) g")
                    if let fiber = item.fiberPer100g, fiber > 0 {
                        statRow("Fiber", String(format: "%.1f g", fiber * multiplier))
                    }
                }
            }
            .navigationTitle("Log to today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log") {
                        let multiplier = grams / 100
                        let entry = FoodEntry(
                            name: portionLabel,
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
                        foodStore.addEntry(entry)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private var portionLabel: String {
        let prep = item.preparation.displayName.lowercased()
        if prep.isEmpty {
            return "\(Int(grams))g \(item.name.lowercased())"
        }
        return "\(Int(grams))g \(item.name.lowercased()) (\(prep))"
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
