import SwiftUI

/// Library tab of the Food Entry sheet
/// (`~/Downloads/macrofactor-screens/IMG_6470.PNG`).
///
/// Top controls row:
/// - A `SegmentedToggle` for Recipes / Foods (bound via `mode`)
/// - A heart-shaped filter toggle (favorites-only). Currently visual; the
///   parent decides whether to filter `items` ahead of time. We expose
///   this as local state so the row can light up on tap without churning
///   the parent's data flow yet.
/// - A "Created" sort menu with a chevron - presents the standard sort
///   options as a `Menu`. Selection is local state for now; when the
///   parent needs to drive sort, lift this into a binding.
///
/// Below the controls: a vertical list of `FoodSearchRow`s. The parent
/// supplies the already-resolved `[FoodDatabaseItem]` array, keeping this
/// view free of `FoodDatabaseService` or `RecipeStore` dependencies.
struct LibraryView: View {

    @Binding var mode: Int
    let items: [FoodDatabaseItem]
    let onTapItem: (FoodDatabaseItem) -> Void
    let onAddItem: (FoodDatabaseItem) -> Void
    /// Optional favorite-state lookup. nil → row hides the heart badge.
    var isFavorite: ((FoodDatabaseItem) -> Bool)? = nil
    /// Optional favorite-toggle handler invoked on long-press of a row.
    var onToggleFavorite: ((FoodDatabaseItem) -> Void)? = nil

    @State private var favoritesOnly: Bool = false
    @State private var sortOption: SortOption = .created

    enum SortOption: String, CaseIterable, Identifiable {
        case created = "Created"
        case nameAZ = "Name A-Z"
        case nameZA = "Name Z-A"
        case caloriesHighLow = "Calories High to Low"
        case caloriesLowHigh = "Calories Low to High"

        var id: String { rawValue }
        var label: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            controlsRow
            sortRow
            list
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.top, BulkAITheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BulkAITheme.Color.background)
    }

    // MARK: Controls row

    private var controlsRow: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            SegmentedToggle(
                options: ("Recipes", "Foods"),
                selection: $mode
            )
            .frame(maxWidth: 180)

            favoritesToggle

            Spacer()

            addButton
        }
    }

    private var favoritesToggle: some View {
        Button {
            withAnimation(.snappy) { favoritesOnly.toggle() }
        } label: {
            ZStack {
                Circle()
                    .fill(favoritesOnly ? BulkAITheme.Color.accent : BulkAITheme.Color.surfaceElevated)
                    .frame(width: 36, height: 36)
                Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(favoritesOnly ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(favoritesOnly ? "Showing favorites only" : "Show favorites only")
    }

    private var addButton: some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(BulkAITheme.Color.surfaceElevated)
                    .frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add new \(mode == 0 ? "recipe" : "food")")
    }

    // MARK: Sort row

    private var sortRow: some View {
        HStack {
            sectionLabel
            Spacer()
            sortMenu
        }
    }

    private var sectionLabel: some View {
        Text(mode == 0 ? "Recipes" : "Foods")
            .font(BulkAITheme.Typography.headline)
            .foregroundStyle(.white)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: BulkAITheme.Spacing.xxs) {
                Text(sortOption.label)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            if items.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        FoodSearchRow(
                            name: item.name,
                            emoji: emoji(for: item),
                            tint: tint(for: item),
                            macroLine: macroLine(for: item),
                            onTap: { onTapItem(item) },
                            onAdd: { onAddItem(item) },
                            isFavorite: isFavorite?(item),
                            onToggleFavorite: { onToggleFavorite?(item) }
                        )
                        if index < items.count - 1 {
                            Divider().background(.white.opacity(0.06))
                        }
                    }
                }
                .padding(.bottom, BulkAITheme.Spacing.xxl)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: mode == 0 ? "book.closed" : "fork.knife")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text(mode == 0 ? "No recipes yet" : "No foods saved yet")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.55))
            Text(mode == 0
                 ? "Recipes you create or import will show up here."
                 : "Foods you log will be added to your library automatically.")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BulkAITheme.Spacing.xxl)
    }

    // MARK: Formatting helpers

    private func macroLine(for item: FoodDatabaseItem) -> String {
        let cal = Int(item.caloriesPer100g.rounded())
        let p = Int(item.proteinPer100g.rounded())
        let f = Int(item.fatPer100g.rounded())
        let c = Int(item.carbsPer100g.rounded())
        let portion = item.preparation == .other ? "1 portion" : "100 g \(item.preparation.displayName.lowercased())"
        return "\(cal) Cal \u{00B7} \(p)P \(f)F \(c)C \u{2022} \(portion)"
    }

    private func emoji(for item: FoodDatabaseItem) -> String {
        switch item.category {
        case .protein: "\u{1F357}"
        case .grain: "\u{1F35E}"
        case .vegetable: "\u{1F966}"
        case .fruit: "\u{1F34E}"
        case .dairy: "\u{1F95B}"
        case .fat: "\u{1F951}"
        case .prepared: "\u{1F35B}"
        }
    }

    private func tint(for item: FoodDatabaseItem) -> Color {
        switch item.category {
        case .protein: BulkAITheme.Color.macroProtein
        case .grain: BulkAITheme.Color.macroCalories
        case .vegetable: BulkAITheme.Color.macroCarbs
        case .fruit: BulkAITheme.Color.macroCarbs
        case .dairy: BulkAITheme.Color.macroFat
        case .fat: BulkAITheme.Color.macroFat
        case .prepared: BulkAITheme.Color.accent
        }
    }
}

private enum LibraryViewPreviewData {

    static let foods: [FoodDatabaseItem] = [
        item(id: "lib-1", name: "Apple Raisin Bread By Anderson Bakery", category: .grain, cal: 170, p: 3, f: 4, c: 32),
        item(id: "lib-2", name: "Dried Apples", category: .fruit, cal: 120, p: 1, f: 0, c: 29),
        item(id: "lib-3", name: "Protein Cup By Chipotle", category: .protein, cal: 180, p: 32, f: 7, c: 0),
        item(id: "lib-4", name: "String Beans By Din Tai Fung", category: .vegetable, cal: 170, p: 3, f: 14, c: 12),
        item(id: "lib-5", name: "Chic Fil A Grilled Nuggets 30ct", category: .protein, cal: 510, p: 98, f: 11, c: 4),
        item(id: "lib-6", name: "Peri Peri", category: .protein, cal: 1200, p: 128, f: 64, c: 4),
        item(id: "lib-7", name: "Chicken Rice Bowl", category: .prepared, cal: 507, p: 53, f: 7, c: 58),
        item(id: "lib-8", name: "Quick Add", category: .prepared, cal: 1070, p: 30, f: 32, c: 143),
    ]

    private static func item(
        id: String,
        name: String,
        category: FoodDatabaseCategory,
        cal: Double,
        p: Double,
        f: Double,
        c: Double
    ) -> FoodDatabaseItem {
        FoodDatabaseItem(
            id: id,
            name: name,
            category: category,
            preparation: .other,
            caloriesPer100g: cal,
            proteinPer100g: p,
            carbsPer100g: c,
            fatPer100g: f,
            fiberPer100g: nil,
            source: .verified
        )
    }
}

private struct LibraryViewPreviewHarness: View {
    @State private var mode: Int = 1

    var body: some View {
        LibraryView(
            mode: $mode,
            items: LibraryViewPreviewData.foods,
            onTapItem: { _ in },
            onAddItem: { _ in }
        )
    }
}

#Preview("LibraryView") {
    LibraryViewPreviewHarness()
}
