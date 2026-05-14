import SwiftUI

/// Two-screen flow: a list of saved recipes (with totals), and a build/edit screen
/// where the user assembles ingredients. URL import is a button on the builder.
struct RecipesView: View {
    @Environment(RecipeStore.self) private var recipeStore
    @State private var editingRecipe: Recipe?
    @State private var showNewRecipeSheet = false
    @State private var loggingRecipe: Recipe?

    var body: some View {
        List {
            if recipeStore.recipes.isEmpty {
                Section {
                    Text("Build a recipe once, log it as a meal whenever you make it. You can also paste a URL to import ingredients from schema.org-compatible recipe sites.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(recipeStore.sortedRecipes) { recipe in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name)
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Text("\(recipe.caloriesPerServing) kcal/serving · \(recipe.ingredients.count) ingredient\(recipe.ingredients.count == 1 ? "" : "s")")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("Log to food log") { loggingRecipe = recipe }
                            Button("Edit") { editingRecipe = recipe }
                            Button("Delete", role: .destructive) {
                                recipeStore.delete(recipe)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(BulkAITheme.Color.accent)
                        }
                    }
                }
                .onDelete { idx in
                    let sorted = recipeStore.sortedRecipes
                    for i in idx { recipeStore.delete(sorted[i]) }
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewRecipeSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showNewRecipeSheet) {
            RecipeBuilderView(recipe: nil) { newRecipe in
                recipeStore.add(newRecipe)
            }
        }
        .sheet(item: $editingRecipe) { recipe in
            RecipeBuilderView(recipe: recipe) { updated in
                recipeStore.update(updated)
            }
        }
        .sheet(item: $loggingRecipe) { recipe in
            LogRecipeSheet(recipe: recipe)
        }
    }
}

// MARK: - Builder

private struct RecipeBuilderView: View {
    let recipe: Recipe?
    let onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var servings: Int
    @State private var ingredients: [RecipeIngredient]
    @State private var notes: String
    @State private var sourceURLString: String
    @State private var showImportSheet = false

    init(recipe: Recipe?, onSave: @escaping (Recipe) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _name = State(initialValue: recipe?.name ?? "")
        _servings = State(initialValue: recipe?.servings ?? 1)
        _ingredients = State(initialValue: recipe?.ingredients ?? [])
        _notes = State(initialValue: recipe?.notes ?? "")
        _sourceURLString = State(initialValue: recipe?.sourceURL?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    Stepper(value: $servings, in: 1...50) {
                        HStack { Text("Servings"); Spacer(); Text("\(servings)") }
                    }
                }
                Section {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import from URL", systemImage: "link")
                    }
                }
                Section {
                    if ingredients.isEmpty {
                        Text("No ingredients yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($ingredients) { $ing in
                            NavigationLink {
                                IngredientEditor(ingredient: $ing)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ing.name.isEmpty ? "Unnamed" : ing.name)
                                            .font(.system(.body, design: .rounded))
                                        Text(String(format: "%.0f g · %.0f kcal", ing.grams, ing.totalCalories))
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .onDelete { idx in
                            ingredients.remove(atOffsets: idx)
                        }
                    }
                    Button {
                        ingredients.append(RecipeIngredient(name: "", grams: 0))
                    } label: {
                        Label("Add ingredient", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    if !ingredients.isEmpty {
                        Text("Totals: \(Int(totalCalories)) kcal · P \(Int(totalProtein))g · C \(Int(totalCarbs))g · F \(Int(totalFat))g · \(perServingString)")
                            .font(.system(.caption, design: .rounded))
                    }
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let result = Recipe(
                            id: recipe?.id ?? UUID(),
                            name: name,
                            servings: servings,
                            ingredients: ingredients,
                            sourceURL: URL(string: sourceURLString),
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(result)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showImportSheet) {
                URLImportSheet { imported in
                    name = imported.name
                    servings = imported.servings
                    ingredients = imported.ingredients
                    sourceURLString = imported.sourceURL?.absoluteString ?? ""
                }
            }
        }
    }

    private var totalCalories: Double { ingredients.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + $1.totalProtein } }
    private var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.totalCarbs } }
    private var totalFat: Double { ingredients.reduce(0) { $0 + $1.totalFat } }

    private var perServingString: String {
        let kcal = Int((totalCalories / Double(servings)).rounded())
        return "\(kcal) kcal/serving"
    }
}

private struct IngredientEditor: View {
    @Binding var ingredient: RecipeIngredient

    var body: some View {
        Form {
            Section("Ingredient") {
                TextField("Name", text: $ingredient.name)
                HStack {
                    Text("Grams in recipe")
                    Spacer()
                    TextField("0", value: $ingredient.grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            Section("Per 100 g") {
                macroField(label: "Calories", value: $ingredient.caloriesPer100g)
                macroField(label: "Protein", value: $ingredient.proteinPer100g)
                macroField(label: "Carbs", value: $ingredient.carbsPer100g)
                macroField(label: "Fat", value: $ingredient.fatPer100g)
            }
            Section {
                Text("Macros per 100g times grams in recipe gives the contribution to the recipe total.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(ingredient.name.isEmpty ? "Ingredient" : ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func macroField(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}

// MARK: - Logging

private struct LogRecipeSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodStore.self) private var foodStore

    @State private var servings: Double = 1
    @State private var mealType: MealType = .currentMeal
    @State private var date: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("\(recipe.name)") {
                    HStack {
                        Text("Servings to log")
                        Spacer()
                        Stepper(
                            value: $servings,
                            in: 0.25...20,
                            step: 0.25
                        ) {
                            Text(String(format: "%.2f", servings))
                                .monospacedDigit()
                        }
                    }
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Will log") {
                    let multiplier = servings / Double(recipe.servings)
                    statRow("Calories", "\(Int((recipe.totalCalories * multiplier).rounded())) kcal")
                    statRow("Protein", "\(Int((recipe.totalProtein * multiplier).rounded())) g")
                    statRow("Carbs", "\(Int((recipe.totalCarbs * multiplier).rounded())) g")
                    statRow("Fat", "\(Int((recipe.totalFat * multiplier).rounded())) g")
                }
            }
            .navigationTitle("Log recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log") {
                        let entry = recipe.makeFoodEntry(
                            servings: servings,
                            mealType: mealType,
                            date: date
                        )
                        foodStore.addEntry(entry)
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
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - URL import sheet

private struct URLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImported: (Recipe) -> Void

    @State private var urlString: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://...", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
                Section {
                    Text("Supports any site that embeds schema.org Recipe JSON-LD (NYT Cooking, AllRecipes, Serious Eats, etc). Ingredient macros aren't included in the schema, so you'll edit each row to fill those in.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await runImport() }
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Import")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                    }
                    .disabled(isImporting || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func runImport() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let recipe = try await RecipeImporter.importRecipe(from: urlString)
            onImported(recipe)
            dismiss()
        } catch let error as RecipeImporter.ImportError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Couldn't import: \(error.localizedDescription)"
        }
    }
}
