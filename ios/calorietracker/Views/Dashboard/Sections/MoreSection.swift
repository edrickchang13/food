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
    var onStrategy: (() -> Void)? = nil

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

                divider

                MoreRow(
                    icon: "cylinder.split.1x2.fill",
                    title: "Nutrition Data Manager",
                    action: onNutritionDataManager
                )

                if let onStrategy {
                    divider
                    MoreRow(
                        icon: "target",
                        title: "Strategy",
                        action: onStrategy
                    )
                }
            }
            // Use the surface card with zero padding so each row owns its own
            // padding; this matches the visual rhythm of a grouped iOS list
            // sitting inside a single rounded surface.
            .surfaceCard(padding: 0)
        }
    }

    /// Inset hairline divider between rows. Factored out so the optional
    /// Strategy row reuses the same insets without copy-pasting the geometry.
    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)
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
