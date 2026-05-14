import SwiftUI

struct EditFoodEntryView: View {
    private enum ScrollTarget: Hashable {
        case quantity
    }

    let entry: FoodEntry
    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss

    // Base values (the entry's nutrition at its logged serving size)
    private let baseCalories: Int
    private let baseProtein: Int
    private let baseCarbs: Int
    private let baseFat: Int
    private let baseServingSizeGrams: Double
    private let baseSugar: Double?
    private let baseAddedSugar: Double?
    private let baseFiber: Double?
    private let baseSaturatedFat: Double?
    private let baseMonounsaturatedFat: Double?
    private let basePolyunsaturatedFat: Double?
    private let baseCholesterol: Double?
    private let baseSodium: Double?
    private let basePotassium: Double?
    private let servingUnitOptions: [ServingUnitOption]

    @State private var name: String
    @State private var servingSizeGrams: Double
    @State private var servingSizeText: String
    @State private var selectedServingUnitID: String
    @State private var quantityFocusRequest = 0
    @State private var isQuantityEditing = false
    @State private var mealType: MealType

    // User-editable micronutrient overrides. When non-nil these win at save
    // time over the scaled baseline values, letting users correct the data
    // from any food database without being forced to accept scaled math.
    @State private var editedSugar: Double?
    @State private var editedAddedSugar: Double?
    @State private var editedFiber: Double?
    @State private var editedSaturatedFat: Double?
    @State private var editedMonounsaturatedFat: Double?
    @State private var editedPolyunsaturatedFat: Double?
    @State private var editedCholesterol: Double?
    @State private var editedSodium: Double?
    @State private var editedPotassium: Double?

    private var scale: Double {
        guard baseServingSizeGrams > 0 else { return 1 }
        return servingSizeGrams / baseServingSizeGrams
    }

    private var scaledCalories: Int { Int(round(Double(baseCalories) * scale)) }
    private var scaledProtein: Int { Int(round(Double(baseProtein) * scale)) }
    private var scaledCarbs: Int { Int(round(Double(baseCarbs) * scale)) }
    private var scaledFat: Int { Int(round(Double(baseFat) * scale)) }
    private var scaledSugar: Double? { baseSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledAddedSugar: Double? { baseAddedSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledFiber: Double? { baseFiber.map { round($0 * scale * 10) / 10 } }
    private var scaledSaturatedFat: Double? { baseSaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledMonounsaturatedFat: Double? { baseMonounsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledPolyunsaturatedFat: Double? { basePolyunsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCholesterol: Double? { baseCholesterol.map { round($0 * scale * 10) / 10 } }
    private var scaledSodium: Double? { baseSodium.map { round($0 * scale * 10) / 10 } }
    private var scaledPotassium: Double? { basePotassium.map { round($0 * scale * 10) / 10 } }
    private var selectedServingOption: ServingUnitOption {
        ServingUnitOption.option(matching: selectedServingUnitID, in: servingUnitOptions)
    }
    private var selectedServingQuantity: Double? {
        Double(servingSizeText)
    }

    init(entry: FoodEntry) {
        self.entry = entry
        let serving = entry.servingSizeGrams ?? 100
        let normalizedServingUnitOptions = ServingUnitOption.normalizedOptions(entry.servingUnitOptions, totalGrams: serving)
        let initialServingUnitID = ServingUnitOption.initialUnitID(
            preferredUnit: entry.selectedServingUnit,
            options: normalizedServingUnitOptions
        )
        self.baseCalories = entry.calories
        self.baseProtein = entry.protein
        self.baseCarbs = entry.carbs
        self.baseFat = entry.fat
        self.baseServingSizeGrams = serving
        self.baseSugar = entry.sugar
        self.baseAddedSugar = entry.addedSugar
        self.baseFiber = entry.fiber
        self.baseSaturatedFat = entry.saturatedFat
        self.baseMonounsaturatedFat = entry.monounsaturatedFat
        self.basePolyunsaturatedFat = entry.polyunsaturatedFat
        self.baseCholesterol = entry.cholesterol
        self.baseSodium = entry.sodium
        self.basePotassium = entry.potassium
        self.servingUnitOptions = normalizedServingUnitOptions
        self._name = State(initialValue: entry.name)
        self._servingSizeGrams = State(initialValue: serving)
        self._servingSizeText = State(initialValue: ServingUnitOption.initialQuantityText(
            totalGrams: serving,
            selectedUnitID: initialServingUnitID,
            selectedQuantity: entry.selectedServingQuantity,
            options: normalizedServingUnitOptions
        ))
        self._selectedServingUnitID = State(initialValue: initialServingUnitID)
        self._mealType = State(initialValue: entry.mealType)
        // Seed editable overrides from the logged entry values so existing
        // data is visible and editable immediately without any user action.
        self._editedSugar = State(initialValue: entry.sugar)
        self._editedAddedSugar = State(initialValue: entry.addedSugar)
        self._editedFiber = State(initialValue: entry.fiber)
        self._editedSaturatedFat = State(initialValue: entry.saturatedFat)
        self._editedMonounsaturatedFat = State(initialValue: entry.monounsaturatedFat)
        self._editedPolyunsaturatedFat = State(initialValue: entry.polyunsaturatedFat)
        self._editedCholesterol = State(initialValue: entry.cholesterol)
        self._editedSodium = State(initialValue: entry.sodium)
        self._editedPotassium = State(initialValue: entry.potassium)
    }

    private static func formatGrams(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                        Section {
                            HStack {
                                Spacer()
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } else if let emoji = entry.emoji {
                        Section {
                            HStack {
                                Spacer()
                                Text(emoji)
                                    .font(.system(size: 80))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    Section("Food Details") {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Food name", text: $name)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("Serving") {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            ServingUnitEditor(
                                quantityText: $servingSizeText,
                                servingSizeGrams: $servingSizeGrams,
                                selectedUnitID: $selectedServingUnitID,
                                unitOptions: servingUnitOptions,
                                focusRequest: quantityFocusRequest,
                                onEditingChanged: { editing in
                                    isQuantityEditing = editing
                                },
                                onClear: {
                                    servingSizeText = ""
                                    quantityFocusRequest += 1
                                }
                            )
                        }
                        .id(ScrollTarget.quantity)
                        if !selectedServingOption.isGramUnit {
                            HStack {
                                Text("Total")
                                Spacer()
                                Text("~\(Self.formatGrams(servingSizeGrams)) g")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Nutrition") {
                        NutritionDisplayRow(label: "Calories", value: "\(scaledCalories)", unit: "kcal")
                        NutritionDisplayRow(label: "Protein", value: "\(scaledProtein)", unit: "g")
                        NutritionDisplayRow(label: "Carbs", value: "\(scaledCarbs)", unit: "g")
                        NutritionDisplayRow(label: "Fat", value: "\(scaledFat)", unit: "g")
                    }

                    Section {
                        DisclosureGroup("More Nutrition") {
                            OptionalNutritionEditRow(label: "Sugar", value: $editedSugar, unit: "g")
                            OptionalNutritionEditRow(label: "Added Sugar", value: $editedAddedSugar, unit: "g")
                            OptionalNutritionEditRow(label: "Fiber", value: $editedFiber, unit: "g")
                            OptionalNutritionEditRow(label: "Saturated Fat", value: $editedSaturatedFat, unit: "g")
                            OptionalNutritionEditRow(label: "Mono Fat", value: $editedMonounsaturatedFat, unit: "g")
                            OptionalNutritionEditRow(label: "Poly Fat", value: $editedPolyunsaturatedFat, unit: "g")
                            OptionalNutritionEditRow(label: "Cholesterol", value: $editedCholesterol, unit: "mg")
                            OptionalNutritionEditRow(label: "Sodium", value: $editedSodium, unit: "mg")
                            OptionalNutritionEditRow(label: "Potassium", value: $editedPotassium, unit: "mg")
                        }
                        .tint(AppColors.calorie)
                    }

                    Section("Meal") {
                        Picker("Meal Type", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { meal in
                                Label(meal.displayName, systemImage: meal.icon)
                                    .tag(meal)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.calorie)
                    }

                }
                .scrollContentBackground(.hidden)
                .background(AppColors.appBackground)
                .background(KeyboardDismissTapInstaller())
                .safeAreaInset(edge: .bottom) {
                    if isQuantityEditing {
                        Color.clear.frame(height: 12)
                    }
                }
                .onChange(of: isQuantityEditing) { _, editing in
                    guard editing else { return }
                    scrollQuantityIntoView(scrollProxy)
                }
                .navigationTitle("Edit Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveChanges)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .tint(AppColors.calorie)
                    }
                }
            }
        }
    }

    private func scrollQuantityIntoView(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(ScrollTarget.quantity, anchor: .bottom)
            }
        }
    }

    private func saveChanges() {
        let updated = FoodEntry(
            id: entry.id,
            name: name,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            timestamp: entry.timestamp,
            imageData: entry.imageData,
            emoji: entry.emoji,
            source: entry.source,
            mealType: mealType,
            sugar: editedSugar ?? scaledSugar,
            addedSugar: editedAddedSugar ?? scaledAddedSugar,
            fiber: editedFiber ?? scaledFiber,
            saturatedFat: editedSaturatedFat ?? scaledSaturatedFat,
            monounsaturatedFat: editedMonounsaturatedFat ?? scaledMonounsaturatedFat,
            polyunsaturatedFat: editedPolyunsaturatedFat ?? scaledPolyunsaturatedFat,
            cholesterol: editedCholesterol ?? scaledCholesterol,
            sodium: editedSodium ?? scaledSodium,
            potassium: editedPotassium ?? scaledPotassium,
            servingSizeGrams: servingSizeGrams,
            servingUnitOptions: servingUnitOptions,
            selectedServingUnit: servingUnitOptions.isEmpty ? nil : selectedServingOption.unit,
            selectedServingQuantity: servingUnitOptions.isEmpty ? nil : selectedServingQuantity
        )
        foodStore.updateEntry(updated)
        dismiss()
    }
}

// MARK: - Helpers

/// Editable micronutrient row. Wraps a `TextField` bound through a computed
/// `Binding<String>` so an `Optional<Double>` can be edited as plain text and
/// round-tripped back to the model. An empty field clears the value (sets
/// it to `nil`); a comma is accepted as a decimal separator for locale
/// compatibility.
private struct OptionalNutritionEditRow: View {
    let label: String
    @Binding var value: Double?
    let unit: String

    private var stringBinding: Binding<String> {
        Binding(
            get: {
                guard let value else { return "" }
                // Drop trailing .0 for clean editing.
                if value.rounded() == value { return String(Int(value)) }
                return String(format: "%.1f", value)
            },
            set: { newString in
                let trimmed = newString.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    value = nil
                } else if let parsed = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                    value = parsed
                }
                // If the string isn't parseable yet (mid-edit, e.g. "1.")
                // leave value unchanged so the binding doesn't fight the user.
            }
        )
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 8)
            TextField("—", text: stringBinding)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .frame(maxWidth: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
        }
    }
}
