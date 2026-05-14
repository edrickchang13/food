import SwiftUI

/// Strategy screen's top header. Two visual modes:
///
/// - **Big mode (default)** — large all-caps "STRATEGY" wordmark in the
///   display-weight rounded typeface. Sits inline above the action pill row.
/// - **Compact mode (after scroll)** — small "Strategy" label pinned to a
///   thin material strip at the top of the screen, mirroring iOS's native
///   large-title -> standard-title collapse behavior.
///
/// The parent owns the scroll-driven transition via `isCollapsed`. We don't
/// host a scroll listener here so the header can be embedded in any container.
struct StrategyHeader: View {

    /// `true` switches to the compact pinned-title state. The parent flips
    /// this via `.onScrollGeometryChange` (iOS 18+) on the surrounding
    /// `ScrollView`.
    let isCollapsed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Big wordmark — fades out as the parent collapses the header.
            bigTitle
                .opacity(isCollapsed ? 0 : 1)
                .scaleEffect(
                    reduceMotion ? 1 : (isCollapsed ? 0.92 : 1),
                    anchor: .topLeading
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isCollapsed)
                .accessibilityHidden(isCollapsed)

            // Compact strip — slides in from the top once the user scrolls
            // enough to push the big title off the visible area.
            compactStrip
                .opacity(isCollapsed ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (isCollapsed ? 0 : -12))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isCollapsed)
                .accessibilityHidden(!isCollapsed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    private var bigTitle: some View {
        Text("STRATEGY")
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .tracking(-0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.top, BulkAITheme.Spacing.md)
            .padding(.bottom, BulkAITheme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    private var compactStrip: some View {
        HStack {
            Text("Strategy")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.sm)
        .background(
            // Fall back to an opaque surface when Reduce Transparency is on so
            // the "Strategy" label keeps adequate contrast against the strip.
            reduceTransparency
                ? AnyShapeStyle(BulkAITheme.Color.surface)
                : AnyShapeStyle(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("StrategyHeader") {
    VStack(spacing: BulkAITheme.Spacing.xl) {
        StrategyHeader(isCollapsed: false)
        StrategyHeader(isCollapsed: true)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
