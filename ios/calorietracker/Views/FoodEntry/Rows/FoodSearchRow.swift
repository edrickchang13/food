import SwiftUI

/// A single food row used in the Food Entry sheet's Search and Library tabs
/// (`~/Downloads/macrofactor-screens/IMG_6466.PNG`, `IMG_6470.PNG`).
///
/// Visual anatomy left to right:
/// - A small circular icon with a food emoji on a tinted background. The
///   tint mirrors the food's category color (carbs, protein, etc.) so the
///   list reads at a glance.
/// - A vertical text block: bold food name on top, a single muted line of
///   macros + serving size below. The macro line is a pre-formatted string
///   like "200 Cal 0P 0F 51C 24 fl oz" so this row stays presentational
///   and doesn't have to know the macro vocabulary.
/// - A trailing circular "+" button that adds the item to the log without
///   opening the detail view. The whole row is also tappable to open detail.
///
/// Two separate actions (`onTap` and `onAdd`) reflect MacroFactor's
/// behavior: tapping the row opens portion picking, tapping the "+" adds
/// the default serving immediately.
struct FoodSearchRow: View {

    let name: String
    let emoji: String
    let tint: Color
    let macroLine: String
    let onTap: () -> Void
    let onAdd: () -> Void
    /// Optional favorite state. When provided, a heart indicator appears on
    /// the leading icon and long-press on the row toggles the favorite.
    /// Default of `nil` keeps existing call sites unchanged.
    var isFavorite: Bool? = nil
    var onToggleFavorite: (() -> Void)? = nil

    private let iconSize: CGFloat = 36
    private let addButtonSize: CGFloat = 44

    var body: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            Button(action: onTap) {
                HStack(spacing: BulkAITheme.Spacing.sm) {
                    leadingIcon
                    textBlock
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in onToggleFavorite?() }
            )

            addButton
        }
        .padding(.vertical, BulkAITheme.Spacing.xs)
    }

    private var leadingIcon: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(0.3), lineWidth: 0.5)
                    )
                    .frame(width: iconSize, height: iconSize)

                Text(emoji)
                    .font(.system(size: 18))
            }

            // Tiny heart badge in the top-right of the icon when this row is
            // favorited. Long-press on the row toggles via `onToggleFavorite`.
            if isFavorite == true {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BulkAITheme.Color.accent)
                    .padding(2)
                    .background(
                        Circle().fill(BulkAITheme.Color.background)
                    )
                    .offset(x: 4, y: -2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: iconSize, height: iconSize, alignment: .topTrailing)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(BulkAITheme.Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(macroLine)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .fill(BulkAITheme.Color.surfaceElevated)
                    .frame(width: addButtonSize, height: addButtonSize)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(name)")
    }
}

private struct FoodSearchRowPreviewHarness: View {
    var body: some View {
        VStack(spacing: 0) {
            FoodSearchRow(
                name: "Venti Strawberry Acai Lemonade Refresher By Starbucks",
                emoji: "\u{1F378}",
                tint: BulkAITheme.Color.macroFat,
                macroLine: "200 Cal \u{00B7} 0P 0F 51C \u{2022} 24 fl oz",
                onTap: {},
                onAdd: {}
            )
            Divider().background(.white.opacity(0.06))
            FoodSearchRow(
                name: "Core Power 26g Complete Protein Shake - Chocolate",
                emoji: "\u{1F95B}",
                tint: BulkAITheme.Color.macroProtein,
                macroLine: "170 Cal \u{00B7} 26P 4F 8C \u{2022} 1 bottle",
                onTap: {},
                onAdd: {}
            )
            Divider().background(.white.opacity(0.06))
            FoodSearchRow(
                name: "Chicken Fingers By Raising Cane's",
                emoji: "\u{1F357}",
                tint: BulkAITheme.Color.macroCalories,
                macroLine: "130 Cal \u{00B7} 13P 6F 5C \u{2022} 1 finger",
                onTap: {},
                onAdd: {}
            )
            Divider().background(.white.opacity(0.06))
            FoodSearchRow(
                name: "Biscuit With Egg Cheese And Bacon",
                emoji: "\u{1F950}",
                tint: BulkAITheme.Color.macroFat,
                macroLine: "436 Cal \u{00B7} 17P 25F 35C \u{2022} 1 item (145 g)",
                onTap: {},
                onAdd: {}
            )
        }
        .padding(BulkAITheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("FoodSearchRow") {
    FoodSearchRowPreviewHarness()
}
