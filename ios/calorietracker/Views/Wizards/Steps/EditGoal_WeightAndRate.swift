import SwiftUI

// MARK: - EditGoal_WeightAndRate

/// Step 1 of the Edit Goal wizard — target-weight ruler plus weekly-rate picker.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6476.PNG`
///
/// The two stat tiles at the top update live while the user drags the ruler,
/// mirroring MacroFactor's behaviour. A `SegmentedToggle` switches the rate
/// input between Standard and Custom. In Standard mode, a three-pill picker
/// (Slower / Standard / Faster) sets the rate as a percent of bodyweight:
/// 0.25 %, 0.45 %, and 0.65 %/wk respectively. Standard at 0.45 %/wk equals
/// roughly +0.86 lb/wk for a 190-lb starting weight, matching MacroFactor.
/// Custom mode keeps a free Slider over 0–1.5 kg/wk unchanged.
struct EditGoal_WeightAndRate: View {

    @Binding var targetWeightKg: Double
    @Binding var weeklyChangeKg: Double
    @Binding var isCustomRate: Bool
    @Binding var standardTier: StandardRateTier
    let currentWeightKg: Double
    let useImperial: Bool

    // Local ruler state: ruler works in display units (lb or kg) and we convert
    // back to kg whenever the binding is written.
    @State private var rulerValue: Double = 0
    @State private var rateSegment: Int = 0

    // MARK: - Constants

    private let kgPerLb: Double = 0.453592
    private let lbPerKg: Double = 2.20462

    // MARK: - Computed helpers

    private var displayWeight: Double { useImperial ? targetWeightKg * lbPerKg : targetWeightKg }
    private var displayCurrent: Double { useImperial ? currentWeightKg * lbPerKg : currentWeightKg }
    private var weightUnit: String { useImperial ? "lb" : "kg" }

    private var rulerRange: ClosedRange<Double> {
        let delta: Double = useImperial ? 65 : 30
        let lower = (displayCurrent - delta).rounded()
        let upper = (displayCurrent + delta).rounded()
        return lower...upper
    }

    private var rulerStep: Double { useImperial ? 1.0 : 0.5 }

    /// Crude TDEE proxy: 33 kcal per kg current weight.
    private var maintenanceKcal: Double { currentWeightKg * 33 }

    private var dailyBudget: Int {
        let deficitPerDay = (weeklyChangeKg * 7700) / 7
        if targetWeightKg < currentWeightKg {
            return Int((maintenanceKcal - deficitPerDay).rounded())
        } else if targetWeightKg > currentWeightKg {
            return Int((maintenanceKcal + deficitPerDay).rounded())
        } else {
            return Int(maintenanceKcal.rounded())
        }
    }

    private var projectedEndDate: String {
        guard weeklyChangeKg > 0 else { return "—" }
        let weeks = abs(targetWeightKg - currentWeightKg) / weeklyChangeKg
        let interval = weeks * 7 * 86400
        let date = Date().addingTimeInterval(interval)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Resolved rate label shown below the rate row.
    /// Standard mode prefixes the tier name; Custom mode prefixes "Custom".
    private var displayRate: String {
        let prefix = isCustomRate ? "Custom" : standardTier.displayName
        if useImperial {
            let lbPerWeek = weeklyChangeKg * lbPerKg
            return String(format: "%@: +%.2f lb / wk", prefix, lbPerWeek)
        }
        return String(format: "%@: +%.2f kg / wk", prefix, weeklyChangeKg)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                statTiles
                weightSection
                rateSection
            }
            .padding(BulkAITheme.Spacing.lg)
        }
        .onAppear { syncRulerValue() }
        .onChange(of: targetWeightKg) { syncRulerValue() }
        .onChange(of: isCustomRate) { _, isNowCustom in
            rateSegment = isNowCustom ? 1 : 0
            // When switching back to Standard, snap the rate to the current tier.
            if !isNowCustom {
                weeklyChangeKg = standardTier.weeklyRateKg(forBodyweightKg: currentWeightKg)
            }
        }
        .onChange(of: rateSegment) { _, new in isCustomRate = new == 1 }
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            statTile(label: "initial daily budget", value: "\(dailyBudget) kcal")
            statTile(label: "projected end date", value: projectedEndDate)
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            Text(value)
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(BulkAITheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BulkAITheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
    }

    // MARK: - Weight section

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            Text("TARGET WEIGHT")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            RulerSlider(
                value: rulerBinding,
                range: rulerRange,
                step: rulerStep,
                majorTickEvery: useImperial ? 10 : 5,
                accent: BulkAITheme.Color.macroCarbs,
                unit: weightUnit
            )
        }
    }

    // MARK: - Rate section

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            Text("RATE")
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            SegmentedToggle(
                options: ("Standard", "Custom"),
                selection: $rateSegment,
                accent: BulkAITheme.Color.macroCarbs
            )

            if isCustomRate {
                customRateSlider
            } else {
                tierPillRow
            }

            Text(displayRate)
                .font(BulkAITheme.Typography.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Tier pill row (Standard mode)

    /// Three-pill picker matching the dark-theme aesthetic: surfaceElevated
    /// track, white pill + black text for the selected tier.
    private var tierPillRow: some View {
        HStack(spacing: BulkAITheme.Spacing.xxs) {
            ForEach(StandardRateTier.allCases) { tier in
                tierPill(tier: tier)
            }
        }
        .padding(BulkAITheme.Spacing.xxs)
        .background(
            Capsule().fill(BulkAITheme.Color.surfaceElevated)
        )
    }

    @ViewBuilder
    private func tierPill(tier: StandardRateTier) -> some View {
        let isSelected = tier == standardTier
        Button {
            withAnimation(.snappy) {
                standardTier = tier
                weeklyChangeKg = tier.weeklyRateKg(forBodyweightKg: currentWeightKg)
            }
        } label: {
            Text(tier.displayName)
                .font(BulkAITheme.Typography.body)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, BulkAITheme.Spacing.xs)
                .background {
                    if isSelected {
                        Capsule().fill(Color.white)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tier.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Custom rate slider

    private var customRateSlider: some View {
        Slider(value: $weeklyChangeKg, in: 0.0...1.5, step: 0.05)
            .tint(BulkAITheme.Color.accent)
    }

    // MARK: - Ruler binding (display units ↔ kg)

    private var rulerBinding: Binding<Double> {
        Binding(
            get: { rulerValue },
            set: { newDisplay in
                rulerValue = newDisplay
                let newKg = useImperial ? newDisplay * kgPerLb : newDisplay
                if newKg != targetWeightKg {
                    targetWeightKg = newKg
                }
            }
        )
    }

    private func syncRulerValue() {
        let display = useImperial ? targetWeightKg * lbPerKg : targetWeightKg
        if abs(display - rulerValue) > 0.01 {
            rulerValue = display
        }
    }
}

// MARK: - Preview

#Preview("EditGoal_WeightAndRate – metric") {
    struct Host: View {
        @State var targetKg: Double = 80
        @State var rateKg: Double = 0.5
        @State var isCustom: Bool = false
        @State var tier: StandardRateTier = .standard

        var body: some View {
            EditGoal_WeightAndRate(
                targetWeightKg: $targetKg,
                weeklyChangeKg: $rateKg,
                isCustomRate: $isCustom,
                standardTier: $tier,
                currentWeightKg: 86.0,
                useImperial: false
            )
            .background(BulkAITheme.Color.background)
            .preferredColorScheme(.dark)
        }
    }
    return Host()
}

#Preview("EditGoal_WeightAndRate – imperial") {
    struct Host: View {
        @State var targetKg: Double = 79.5
        @State var rateKg: Double = 0.45
        @State var isCustom: Bool = true
        @State var tier: StandardRateTier = .standard

        var body: some View {
            EditGoal_WeightAndRate(
                targetWeightKg: $targetKg,
                weeklyChangeKg: $rateKg,
                isCustomRate: $isCustom,
                standardTier: $tier,
                currentWeightKg: 86.0,
                useImperial: true
            )
            .background(BulkAITheme.Color.background)
            .preferredColorScheme(.dark)
        }
    }
    return Host()
}
