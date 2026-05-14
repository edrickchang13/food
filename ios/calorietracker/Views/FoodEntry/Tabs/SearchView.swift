import SwiftUI

/// Search tab of the Food Entry sheet
/// (`~/Downloads/macrofactor-screens/IMG_6466.PNG`).
///
/// Two sections stacked vertically:
/// 1. Favorites - a horizontally scrolling row of `FavoriteAvatar` tiles.
///    These are foods the user has explicitly favorited and tapping one
///    adds it to the log immediately via `onAddItem`.
/// 2. Time-of-day Picks - a vertical list of `FoodSearchRow`s. The header
///    label ("9 AM Picks" / "12 PM Picks" / etc.) is passed in as
///    `timeLabel` because the parent owns the meal slot. Tapping the row
///    opens portion picking; tapping its trailing "+" logs the default
///    serving directly.
///
/// This view is purely presentational. It takes resolved
/// `[FoodDatabaseItem]` arrays and stays out of the data path, so it can
/// be rendered with mock data in previews and snapshot tests without
/// pulling in `FoodDatabaseService` or `FoodStore`.
struct SearchView: View {

    let timeLabel: String
    let favorites: [FoodDatabaseItem]
    let suggestions: [FoodDatabaseItem]
    let onTapItem: (FoodDatabaseItem) -> Void
    let onAddItem: (FoodDatabaseItem) -> Void
    /// Optional favorite-state lookup (called per row). Defaults to nil so
    /// callers that don't have a FavoritesStore keep working unchanged.
    var isFavorite: ((FoodDatabaseItem) -> Bool)? = nil
    /// Optional favorite-toggle handler invoked on long-press.
    var onToggleFavorite: ((FoodDatabaseItem) -> Void)? = nil
    /// Optional search substring. When non-empty, the matched substring in
    /// each result row's name highlights in coral with a semibold weight +
    /// underline. Defaults to nil so call sites without a live search query
    /// continue to render plain names.
    var highlight: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                favoritesSection
                picksSection
            }
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.top, BulkAITheme.Spacing.md)
            .padding(.bottom, BulkAITheme.Spacing.xxl)
        }
        .background(BulkAITheme.Color.background)
    }

    // MARK: Favorites

    @ViewBuilder
    private var favoritesSection: some View {
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                sectionHeader("Favorites")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: BulkAITheme.Spacing.md) {
                        ForEach(favorites) { item in
                            FavoriteAvatar(
                                name: shortName(item.name),
                                emoji: emoji(for: item),
                                tint: tint(for: item),
                                onTap: { onAddItem(item) }
                            )
                        }
                    }
                    .padding(.vertical, BulkAITheme.Spacing.xxs)
                }
            }
        }
    }

    // MARK: Picks

    @ViewBuilder
    private var picksSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            sectionHeader("\(timeLabel) Picks")

            if suggestions.isEmpty {
                emptyPicks
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                        FoodSearchRow(
                            name: item.name,
                            emoji: emoji(for: item),
                            tint: tint(for: item),
                            macroLine: macroLine(for: item),
                            onTap: { onTapItem(item) },
                            onAdd: { onAddItem(item) },
                            highlight: highlight,
                            isFavorite: isFavorite?(item),
                            onToggleFavorite: { onToggleFavorite?(item) }
                        )
                        if index < suggestions.count - 1 {
                            Divider().background(.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    private var emptyPicks: some View {
        VStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.35))
            Text("No suggestions for this time slot yet")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BulkAITheme.Spacing.xl)
    }

    // MARK: Section header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(BulkAITheme.Typography.headline)
            .foregroundStyle(.white)
    }

    // MARK: Formatting helpers

    private func shortName(_ name: String) -> String {
        // The favorites strip needs to fit a name under a 64pt circle, so
        // strip vendor/brand suffixes and keep the lead noun.
        if let byRange = name.range(of: " By ") {
            return String(name[..<byRange.lowerBound])
        }
        return name
    }

    private func macroLine(for item: FoodDatabaseItem) -> String {
        let cal = Int(item.caloriesPer100g.rounded())
        let p = Int(item.proteinPer100g.rounded())
        let f = Int(item.fatPer100g.rounded())
        let c = Int(item.carbsPer100g.rounded())
        let portion = item.preparation == .other ? "1 serving" : "100 g \(item.preparation.displayName.lowercased())"
        return "\(cal) Cal \u{00B7} \(p)P \(f)F \(c)C \u{2022} \(portion)"
    }

    private func emoji(for item: FoodDatabaseItem) -> String {
        switch item.category {
        case .protein: "\u{1F357}"   // poultry leg, stands in for protein
        case .grain: "\u{1F35E}"     // bread
        case .vegetable: "\u{1F966}" // broccoli
        case .fruit: "\u{1F34E}"     // apple
        case .dairy: "\u{1F95B}"     // glass of milk
        case .fat: "\u{1F951}"       // avocado
        case .prepared: "\u{1F35B}"  // bowl of food
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

private enum SearchViewPreviewData {

    static let favorites: [FoodDatabaseItem] = [
        item(id: "fav-1", name: "Jamba Juice Strawberries Wild", category: .fruit),
        item(id: "fav-2", name: "Salmon Rice Bowl By Sweetgreen", category: .protein),
        item(id: "fav-3", name: "Chicken Rice Bowl By Halal Guys", category: .prepared),
        item(id: "fav-4", name: "Peri Peri Chicken By Nando's", category: .protein),
    ]

    static let suggestions: [FoodDatabaseItem] = [
        item(
            id: "s-1",
            name: "Venti Strawberry Acai Lemonade Refresher By Starbucks",
            category: .fruit,
            cal: 200, p: 0, f: 0, c: 51
        ),
        item(
            id: "s-2",
            name: "Core Power 26g Complete Protein Shake - Chocolate By Fairlife",
            category: .dairy,
            cal: 170, p: 26, f: 4, c: 8
        ),
        item(
            id: "s-3",
            name: "Tropical Wellness Smoothie By Pressed Juicer",
            category: .fruit,
            cal: 160, p: 1, f: 0, c: 41
        ),
        item(
            id: "s-4",
            name: "McCafe Strawberry Banana Smoothie Medium By McDonald's",
            category: .fruit,
            cal: 240, p: 3, f: 1, c: 55
        ),
        item(
            id: "s-5",
            name: "Side Items Waffle Potato Fries Medium By Chick-Fil-A",
            category: .prepared,
            cal: 420, p: 5, f: 24, c: 45
        ),
        item(
            id: "s-6",
            name: "Chicken Fingers By Raising Cane's",
            category: .protein,
            cal: 130, p: 13, f: 6, c: 5
        ),
        item(
            id: "s-7",
            name: "Biscuit With Egg Cheese And Bacon",
            category: .prepared,
            cal: 436, p: 17, f: 25, c: 35
        ),
    ]

    private static func item(
        id: String,
        name: String,
        category: FoodDatabaseCategory,
        cal: Double = 150,
        p: Double = 8,
        f: Double = 4,
        c: Double = 18
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

#Preview("SearchView") {
    SearchView(
        timeLabel: "9 AM",
        favorites: SearchViewPreviewData.favorites,
        suggestions: SearchViewPreviewData.suggestions,
        onTapItem: { _ in },
        onAddItem: { _ in }
    )
}
