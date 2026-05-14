import SwiftUI

/// Applies the standard Bulk AI card treatment: surface fill, 14pt rounded clip,
/// 16pt internal padding, and a hairline elevated-surface border for definition.
/// No shadow — depth comes from the border + surface contrast against the background,
/// matching the MacroFactor reference where every card sits flat on a near-black bed.
struct SurfaceCard: ViewModifier {

    let padding: CGFloat

    init(padding: CGFloat = BulkAITheme.Spacing.md) {
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                    .fill(BulkAITheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                    .stroke(BulkAITheme.Color.surfaceElevated, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
    }
}

extension View {
    /// Wraps the view in a Bulk AI surface card. Override `padding` when the content
    /// already manages its own inner spacing (e.g., a list that needs an edge-to-edge feel).
    func surfaceCard(padding: CGFloat = BulkAITheme.Spacing.md) -> some View {
        modifier(SurfaceCard(padding: padding))
    }
}

#Preview("SurfaceCard") {
    ScrollView {
        VStack(spacing: BulkAITheme.Spacing.md) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                Text("Energy Balance")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                Text("Nutrition − Targets = Difference")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("2,140 kcal")
                    .font(BulkAITheme.Typography.title)
                    .foregroundStyle(BulkAITheme.Color.macroCalories)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()

            HStack(spacing: BulkAITheme.Spacing.sm) {
                VStack(alignment: .leading) {
                    Text("Protein")
                        .font(BulkAITheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("142g")
                        .font(BulkAITheme.Typography.title3)
                        .foregroundStyle(BulkAITheme.Color.macroProtein)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard()

                VStack(alignment: .leading) {
                    Text("Carbs")
                        .font(BulkAITheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("210g")
                        .font(BulkAITheme.Typography.title3)
                        .foregroundStyle(BulkAITheme.Color.macroCarbs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard()
            }

            Text("Tight padding variant")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(padding: BulkAITheme.Spacing.xs)
        }
        .padding(BulkAITheme.Spacing.md)
    }
    .background(BulkAITheme.Color.background)
}
