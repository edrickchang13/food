import SwiftUI

/// Dashboard "More" section — grouped list with two utility rows.
///
/// Layout matches IMG_6464 in `~/Downloads/macrofactor-screens/`:
/// a section header, then a single `.surfaceCard()` containing two tappable
/// rows separated by a hairline divider. Each row shows an SF Symbol icon
/// tinted with the Bulk AI accent, a label, and a trailing chevron.
struct MoreSection: View {

    let onCustomizeDashboard: () -> Void
    let onNutritionDataManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            Text("More")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                MoreRow(
                    icon: "rectangle.grid.2x2",
                    title: "Customize Dashboard",
                    action: onCustomizeDashboard
                )

                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 0.5)
                    // Inset the divider to match list-style rules where the
                    // hairline sits flush with the label rather than the card edge.
                    .padding(.leading, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)

                MoreRow(
                    icon: "cylinder.split.1x2.fill",
                    title: "Nutrition Data Manager",
                    action: onNutritionDataManager
                )
            }
            // Use the surface card with zero padding so each row owns its own
            // padding; this matches the visual rhythm of a grouped iOS list
            // sitting inside a single rounded surface.
            .surfaceCard(padding: 0)
        }
    }
}

// MARK: - MoreRow

/// One row inside the More section card.
///
/// Kept private to this file; rows in this section share an identical shape
/// so factoring them out reduces parent-call boilerplate without creating a
/// generic component that doesn't earn its abstraction.
private struct MoreRow: View {

    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BulkAITheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BulkAITheme.Color.accent)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.vertical, BulkAITheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("MoreSection") {
    ScrollView {
        MoreSection(
            onCustomizeDashboard: {},
            onNutritionDataManager: {}
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .background(BulkAITheme.Color.background)
}
