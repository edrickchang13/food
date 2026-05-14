import SwiftUI

/// Manual macro entry form for the Food Entry sheet's "Quick Add" tab.
///
/// Mirrors `IMG_6469` from the MacroFactor reference set: a large outlined
/// energy input paired with a fixed "kcal" unit dropdown, an informational
/// `Macro sum is X kcal` helper line, three side-by-side macro inputs
/// (Protein / Fat / Carbs) with a "g" suffix, and an optional Alcohol field.
/// Two stacked CTAs follow: a secondary "Quick Add" using the elevated
/// surface token, and a primary white "Log Foods" with black text.
///
/// The view is purely state-driven; the parent owns persistence. Both CTAs
/// build a `FoodEntry` from the current state with `name = "Quick Add"` and
/// `source = .manual`, then hand it to the caller. The macro sum is shown
/// as informational text only — it never blocks the save action.
struct QuickAddView: View {
    @State var energy: Double = 0
    @State var protein: Double = 0
    @State var fat: Double = 0
    @State var carbs: Double = 0
    @State var alcohol: Double = 0
    let onQuickAdd: (FoodEntry) -> Void
    let onLogFoods: (FoodEntry) -> Void

    /// Live recompute of the macro-derived kcal. 4/4/9 for P/C/F is the
    /// standard Atwater factor set the MacroFactor reference also uses.
    private var macroSumKcal: Int {
        Int((protein * 4) + (carbs * 4) + (fat * 9))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                energySection
                macroRow
                alcoholSection
                ctaStack
            }
            .padding(.horizontal, BulkAITheme.Spacing.lg)
            .padding(.top, BulkAITheme.Spacing.md)
            .padding(.bottom, BulkAITheme.Spacing.xxl)
        }
        .background(BulkAITheme.Color.background)
    }

    // MARK: - Sections

    private var energySection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Energy")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)

            HStack(spacing: BulkAITheme.Spacing.sm) {
                numericField(value: $energy, placeholder: "", outlined: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)

                unitDropdown
            }

            Text("Macro sum is \(macroSumKcal) kcal")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var macroRow: some View {
        HStack(alignment: .top, spacing: BulkAITheme.Spacing.sm) {
            macroColumn(title: "Protein", value: $protein)
            macroColumn(title: "Fat", value: $fat)
            macroColumn(title: "Carbs", value: $carbs)
        }
    }

    private var alcoholSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Alcohol")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)

            numericField(value: $alcohol, placeholder: "", outlined: false, suffix: "g")
                .frame(height: 48)
        }
    }

    private var ctaStack: some View {
        VStack(spacing: BulkAITheme.Spacing.sm) {
            Button {
                onQuickAdd(buildEntry())
            } label: {
                Text("Quick Add")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                            .fill(BulkAITheme.Color.surfaceElevated)
                    )
            }

            Button {
                onLogFoods(buildEntry())
            } label: {
                Text("Log Foods")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                            .fill(Color.white)
                    )
            }
        }
        .padding(.top, BulkAITheme.Spacing.xs)
    }

    // MARK: - Components

    private var unitDropdown: some View {
        // Visual-only dropdown for now. The schema is fixed to kcal because
        // FoodEntry stores Int kcal directly; if/when we add kJ support we
        // can wire a real Picker without changing the persisted model.
        HStack(spacing: BulkAITheme.Spacing.xxs) {
            Text("kcal")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm)
                .fill(BulkAITheme.Color.surfaceElevated)
        )
    }

    private func macroColumn(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text(title)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)

            numericField(value: value, placeholder: "", outlined: false, suffix: "g")
                .frame(height: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Single numeric input with a trailing unit suffix. `outlined` toggles
    /// between the large hero outlined Energy field and the muted filled
    /// macro fields. Using a TextField with `.decimalPad` keeps the keypad
    /// behaviour aligned with the reference screen.
    private func numericField(
        value: Binding<Double>,
        placeholder: String,
        outlined: Bool,
        suffix: String? = nil
    ) -> some View {
        let bindingString = Binding<String>(
            get: { value.wrappedValue == 0 ? "" : trimmedString(value.wrappedValue) },
            set: { newValue in
                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                value.wrappedValue = Double(cleaned) ?? 0
            }
        )

        return HStack(spacing: BulkAITheme.Spacing.xs) {
            TextField(placeholder, text: bindingString)
                .keyboardType(.decimalPad)
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
                .multilineTextAlignment(suffix == nil ? .leading : .trailing)
                .frame(maxWidth: .infinity)

            if let suffix {
                Text(suffix)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .background(
            Group {
                if outlined {
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                        .stroke(.white.opacity(0.85), lineWidth: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm)
                        .fill(BulkAITheme.Color.surfaceElevated)
                }
            }
        )
    }

    // MARK: - Helpers

    /// Render a Double without trailing `.0` so the field reads like
    /// the natural keypad entry the user just typed.
    private func trimmedString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    /// Build the FoodEntry handed to either CTA. The macro fields persist
    /// as Int per the FoodEntry model; alcohol has no first-class column,
    /// so its kcal contribution (7 kcal/g) is folded into the calorie total
    /// only when the user did not enter an Energy value. If they did enter
    /// one, we trust their number and ignore the derived sum.
    private func buildEntry() -> FoodEntry {
        let derivedEnergy = macroSumKcal + Int(alcohol * 7)
        let calories = energy > 0 ? Int(energy) : derivedEnergy
        return FoodEntry(
            name: "Quick Add",
            calories: calories,
            protein: Int(protein),
            carbs: Int(carbs),
            fat: Int(fat),
            timestamp: .now,
            source: .manual,
            mealType: .currentMeal
        )
    }
}

#Preview {
    QuickAddView(
        onQuickAdd: { _ in },
        onLogFoods: { _ in }
    )
    .preferredColorScheme(.dark)
}
