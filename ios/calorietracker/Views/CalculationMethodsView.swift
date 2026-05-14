import SwiftUI

/// Apple Guideline 1.4.1 (Safety: Physical Harm) requires apps with health
/// or medical calculations to cite their sources. This sheet documents every
/// formula Fud AI uses to derive BMR, TDEE, calorie targets, and macro splits,
/// with links to the original peer-reviewed sources where available. Reachable
/// from the onboarding Plan step ("How is this calculated?") and from
/// Settings → Goals & Nutrition → Calculation Methods.
struct CalculationMethodsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro

                    section(title: "Resting metabolism (BMR)") {
                        formulaCard(
                            name: "Mifflin-St Jeor equation",
                            usedWhen: "Default formula. Used when body fat % is not entered, or when “Use Body Fat for BMR” is off in Settings.",
                            formula: "Men: 10×weight(kg) + 6.25×height(cm) − 5×age + 5\nWomen: 10×weight(kg) + 6.25×height(cm) − 5×age − 161",
                            citation: "Mifflin MD, St Jeor ST, et al. (1990). “A new predictive equation for resting energy expenditure in healthy individuals.” Am J Clin Nutr 51(2):241–247.",
                            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")
                        )
                        formulaCard(
                            name: "Katch-McArdle equation",
                            usedWhen: "Used automatically when body fat % is set AND “Use Body Fat for BMR” is on. More accurate for lean and athletic users since it derives BMR from lean body mass instead of total weight.",
                            formula: "BMR = 370 + 21.6 × LBM(kg)\nLBM = weight × (1 − bodyFat%)",
                            citation: "McArdle WD, Katch FI, Katch VL. Exercise Physiology: Nutrition, Energy, and Human Performance, 7th ed. Lippincott Williams & Wilkins, 2010.",
                            url: nil
                        )
                    }

                    section(title: "Daily energy expenditure (TDEE)") {
                        formulaCard(
                            name: "Activity-multiplier method",
                            usedWhen: "TDEE = BMR × activity multiplier. Multipliers correspond to the user-selected activity level.",
                            formula: "Sedentary: 1.2  ·  Light: 1.375  ·  Moderate: 1.55  ·  Very Active: 1.725  ·  Extra Active: 1.9",
                            citation: "Standard PAL (Physical Activity Level) coefficients from FAO/WHO/UNU joint expert consultation on human energy requirements (2001). Also widely used by ACSM and USDA Dietary Guidelines.",
                            url: URL(string: "https://www.fao.org/3/y5686e/y5686e00.htm")
                        )
                    }

                    section(title: "Calorie target for goal") {
                        formulaCard(
                            name: "Energy-balance adjustment",
                            usedWhen: "Daily calorie goal = TDEE adjusted for chosen weekly weight-change rate. Used for Lose / Gain / Maintain goals.",
                            formula: "1 lb of body fat ≈ 3,500 kcal · 1 kg ≈ 7,700 kcal\nWeekly deficit / surplus is divided across 7 days and added to (or subtracted from) TDEE to produce the daily calorie target.",
                            citation: "Hall KD, et al. (2011). “Quantification of the effect of energy imbalance on bodyweight.” Lancet 378(9793):826–837. The classic 3,500-kcal-per-pound rule originates from Wishnofsky M (1958), Am J Clin Nutr 6:542–546.",
                            url: URL(string: "https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(11)60812-X/fulltext")
                        )
                    }

                    section(title: "Macronutrient split") {
                        formulaCard(
                            name: "Protein, carbs, fat targets",
                            usedWhen: "Defaults derived from current calorie target. Each macro is fully overridable in onboarding and Settings.",
                            formula: "Protein: ~1.6 g per kg body weight (Morton 2018 meta-analysis; raised for active users)\nFat: ~25% of total calories\nCarbs: remaining calories ÷ 4 kcal/g",
                            citation: "Morton RW, et al. (2018). “A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength.” Br J Sports Med 52(6):376–384.",
                            url: URL(string: "https://bjsm.bmj.com/content/52/6/376")
                        )
                    }

                    section(title: "Micronutrient values") {
                        formulaCard(
                            name: "Per-meal estimates",
                            usedWhen: "Calorie, macro, fiber, sugar, saturated fat, cholesterol, sodium, potassium and other micronutrient values returned per meal are AI-generated estimates from the food image, voice transcript, or text description, using the AI provider you selected.",
                            formula: nil,
                            citation: "Estimates rely on the underlying AI model's training data (USDA FoodData Central, manufacturer panels, scientific literature). Accuracy varies by food, portion-size visibility, and provider model. Always cross-check labels for foods you log frequently.",
                            url: URL(string: "https://fdc.nal.usda.gov/")
                        )
                    }

                    disclaimer

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BulkAITheme.Color.background)
            .navigationTitle("Calculation Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How Bulk AI calculates your numbers")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Every metabolism, calorie target, and macro split shown in the app comes from peer-reviewed equations. Your AI provider only estimates the per-meal nutrition; the daily targets are pure math from your profile.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not medical advice")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text("Bulk AI is an estimation tool, not a clinical instrument. Predictive equations carry inherent error (typically ±10% for BMR). Consult a registered dietitian, physician, or sports medicine professional before significant diet changes — especially if you have a medical condition, are pregnant or breastfeeding, are under 18, or are managing an eating disorder.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal, 4)
            content()
        }
    }

    private func formulaCard(name: String, usedWhen: String, formula: String?, citation: String, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            Text(usedWhen)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let formula {
                Text(formula)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Source")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(citation)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("Open source")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(BulkAITheme.Color.accent)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BulkAITheme.Color.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CalculationMethodsView()
}
