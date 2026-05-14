import SwiftUI

/// A circular avatar tile used in the Favorites strip at the top of the
/// Food Entry > Search tab (`~/Downloads/macrofactor-screens/IMG_6466.PNG`).
///
/// Visual anatomy:
/// - 64pt circle filled with a tinted (low-opacity) version of `tint`
/// - Centered emoji glyph that represents the food category
/// - A small "+" badge in the bottom-right corner with the full `tint`
///   color, indicating tap-to-add semantics
/// - First name line, truncated, sitting underneath the circle
///
/// The whole tile (circle + label) is one button surface so the tap target
/// stays generous on touch. The "+" badge is purely visual; it doesn't have
/// its own action because Favorites in MacroFactor always add immediately on
/// tap. If we later need an "open detail vs. quick add" split, this is the
/// place to add a long-press gesture.
struct FavoriteAvatar: View {

    let name: String
    let emoji: String
    let tint: Color
    let onTap: () -> Void

    private let circleSize: CGFloat = 64
    private let badgeSize: CGFloat = 20

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: BulkAITheme.Spacing.xs) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(tint.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: circleSize, height: circleSize)

                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: circleSize, height: circleSize)

                    plusBadge
                        .offset(x: 2, y: 2)
                }
                .frame(width: circleSize, height: circleSize)

                Text(name)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: circleSize + 12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(name) to log")
    }

    private var plusBadge: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: badgeSize, height: badgeSize)
                .overlay(
                    Circle()
                        .stroke(BulkAITheme.Color.background, lineWidth: 2)
                )
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct FavoriteAvatarPreviewHarness: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            Text("Favorites")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)

            HStack(spacing: BulkAITheme.Spacing.md) {
                FavoriteAvatar(
                    name: "Jamba Juice",
                    emoji: "\u{1F964}",
                    tint: BulkAITheme.Color.macroFat,
                    onTap: {}
                )
                FavoriteAvatar(
                    name: "Salmon Rice",
                    emoji: "\u{1F363}",
                    tint: BulkAITheme.Color.macroProtein,
                    onTap: {}
                )
                FavoriteAvatar(
                    name: "Chicken Rice",
                    emoji: "\u{1F35B}",
                    tint: BulkAITheme.Color.macroCalories,
                    onTap: {}
                )
                FavoriteAvatar(
                    name: "Peri Peri",
                    emoji: "\u{1F357}",
                    tint: BulkAITheme.Color.accent,
                    onTap: {}
                )
            }
        }
        .padding(BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("FavoriteAvatar") {
    FavoriteAvatarPreviewHarness()
}
