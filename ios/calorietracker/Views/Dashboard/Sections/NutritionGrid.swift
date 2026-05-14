import SwiftUI

/// Dashboard Nutrition section — 2x2 grid of macro tiles.
///
/// Each tile shows the macro label, a "Today" subtitle, a `ThinProgressBar`
/// indicating consumed vs target, and a large value with a chevron at the
/// bottom. Tiles are tinted by macro accent and wrapped in `.surfaceCard()`.
///
/// Matches the layout in `~/Downloads/macrofactor-screens/IMG_6462.PNG` and
/// `IMG_6463.PNG`.
struct NutritionGrid: View {

    /// One macro's consumed / target / unit triple.
    ///
    /// `unit` is the display unit ("kcal" for calories, "g" for the rest); we
    /// keep it as data on the model so the same view can render any macro
    /// without branching on macro identity.
    struct MacroTotal {
        let consumed: Int
        let target: Int
        let unit: String

        init(consumed: Int, target: Int, unit: String) {
            self.consumed = consumed
            self.target = target
            self.unit = unit
        }
    }

    enum Macro {
        case calories, protein, fat, carbs
    }

    let calories: MacroTotal
    let protein: MacroTotal
    let fat: MacroTotal
    let carbs: MacroTotal
    let onSeeAll: () -> Void
    let onTapMacro: (Macro) -> Void

    // Two flexible columns with consistent gutter spacing. `LazyVGrid` is
    // intentional here because the dashboard scroll above this section may be
    // long; lazy materialization keeps offscreen tiles cheap.
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm),
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            header

            LazyVGrid(columns: columns, spacing: BulkAITheme.Spacing.sm) {
                tile(for: .calories, total: calories)
                tile(for: .protein, total: protein)
                tile(for: .fat, total: fat)
                tile(for: .carbs, total: carbs)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Nutrition")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onSeeAll) {
                Text("See All")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all nutrition")
        }
    }

    // MARK: Tile

    @ViewBuilder
    private func tile(for macro: Macro, total: MacroTotal) -> some View {
        Button {
            onTapMacro(macro)
        } label: {
            MacroTile(
                label: Self.label(for: macro),
                icon: Self.icon(for: macro),
                accent: Self.accent(for: macro),
                value: total.consumed,
                target: total.target,
                unit: total.unit
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.label(for: macro)), \(total.consumed) \(total.unit) of \(total.target)")
    }

    // MARK: Mapping helpers

    private static func label(for macro: Macro) -> String {
        switch macro {
        case .calories: return "Calories"
        case .protein:  return "Protein"
        case .fat:      return "Fat"
        case .carbs:    return "Carbs"
        }
    }

    private static func icon(for macro: Macro) -> String {
        // SF Symbols. We pick semantically reasonable glyphs; tinted by macro
        // accent so the visual identity still comes from color first, icon second.
        switch macro {
        case .calories: return "flame.fill"
        case .protein:  return "fork.knife"
        case .fat:      return "drop.fill"
        case .carbs:    return "leaf.fill"
        }
    }

    private static func accent(for macro: Macro) -> Color {
        switch macro {
        case .calories: return BulkAITheme.Color.macroCalories
        case .protein:  return BulkAITheme.Color.macroProtein
        case .fat:      return BulkAITheme.Color.macroFat
        case .carbs:    return BulkAITheme.Color.macroCarbs
        }
    }
}

// MARK: - MacroTile

/// Single macro card rendered inside `NutritionGrid`.
///
/// Pulled out as its own view so the grid stays declarative and the tile body
/// can be reasoned about in isolation. Keeps state out — this is purely
/// presentational from props passed by the parent.
private struct MacroTile: View {

    let label: String
    let icon: String
    let accent: Color
    let value: Int
    let target: Int
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            header

            // Tiny vertical breathing room before the progress rail so the
            // tile doesn't feel top-heavy when consumed = 0.
            ThinProgressBar(
                value: Double(value),
                total: Double(max(target, 1)),
                accent: accent
            )
            .padding(.top, BulkAITheme.Spacing.xs)

            // Hairline divider above the value row, matching the reference
            // where each tile's bottom row sits behind a subtle separator.
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)

            bottomRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            HStack(spacing: BulkAITheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
            }
            Text("Today")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: BulkAITheme.Spacing.xs) {
            // Numeric value sits at large size; the unit follows in a softer
            // weight so the eye lands on the count first.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

#Preview("NutritionGrid") {
    ScrollView {
        NutritionGrid(
            calories: .init(consumed: 0, target: 2400, unit: "kcal"),
            protein: .init(consumed: 0, target: 150, unit: "g"),
            fat: .init(consumed: 0, target: 70, unit: "g"),
            carbs: .init(consumed: 0, target: 240, unit: "g"),
            onSeeAll: {},
            onTapMacro: { _ in }
        )
        .padding(BulkAITheme.Spacing.md)

        NutritionGrid(
            calories: .init(consumed: 1840, target: 2400, unit: "kcal"),
            protein: .init(consumed: 112, target: 150, unit: "g"),
            fat: .init(consumed: 58, target: 70, unit: "g"),
            carbs: .init(consumed: 196, target: 240, unit: "g"),
            onSeeAll: {},
            onTapMacro: { _ in }
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .background(BulkAITheme.Color.background)
}
