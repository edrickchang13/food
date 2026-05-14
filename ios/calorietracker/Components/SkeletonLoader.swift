import SwiftUI

/// Shimmering placeholder for views that don't have data yet.
///
/// Wrap any view in `.skeleton(isLoading: true)` and it animates a soft
/// horizontal-shimmer overlay while hiding the underlying content. When
/// `isLoading` flips to false, the modifier fades the real view in.
///
/// Designed to drop into existing Dashboard hero cards and Insight tiles
/// without changing their layout — apply the modifier at the leaf level
/// (the value Text, the sparkline Shape, etc.) so the surrounding
/// chrome (card backgrounds, headers) stays visible.
///
/// Visual spec:
/// - Base color: `BulkAITheme.Color.surfaceElevated` opacity 0.5
/// - Shimmer band: `Color.white.opacity(0.08)` linear gradient sweep
/// - Sweep duration: 1.4 s, repeats forever with `.easeInOut`
/// - Respects `accessibilityReduceMotion`: sweep disabled, static muted fill
/// - VoiceOver announces "Loading" via `accessibilityLabel`
struct SkeletonView: View {
    var cornerRadius: CGFloat = 8

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BulkAITheme.Color.surfaceElevated.opacity(0.5))

                if !reduceMotion {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width)
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: false)
                        ) {
                            phase = 1
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - View modifier

/// Flips between live content and a skeleton placeholder without shifting layout.
///
/// The modifier overlays `SkeletonView` on top of an `opacity(0)` copy of the
/// wrapped content so the parent's frame calculation always uses the real view's
/// intrinsic size — the layout never shifts between loading and loaded states.
///
/// Usage:
/// ```swift
/// Text(macros)
///     .skeleton(isLoading: macros.isEmpty)
/// ```
extension View {
    func skeleton(
        isLoading: Bool,
        cornerRadius: CGFloat = 8
    ) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, cornerRadius: cornerRadius))
    }
}

private struct SkeletonModifier: ViewModifier {
    let isLoading: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            // Keep content in the layout tree at opacity 0 so the skeleton
            // inherits the same intrinsic size; no frame shift on reveal.
            content
                .opacity(isLoading ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: isLoading)

            if isLoading {
                SkeletonView(cornerRadius: cornerRadius)
            }
        }
    }
}

// MARK: - Preview

#Preview("Skeleton states") {
    VStack(spacing: BulkAITheme.Spacing.lg) {
        // 1. Loading text — skeleton overlays the invisible label
        Text("2,453 kcal")
            .font(.title.weight(.bold))
            .foregroundStyle(.white)
            .skeleton(isLoading: true)
            .frame(width: 200, height: 40)

        // 2. Loaded text — real content faded in
        Text("2,453 kcal")
            .font(.title.weight(.bold))
            .foregroundStyle(.white)
            .skeleton(isLoading: false)
            .frame(width: 200, height: 40)

        // 3. Loading shape — wider tile, custom corner radius
        RoundedRectangle(cornerRadius: 8)
            .frame(width: 280, height: 96)
            .skeleton(isLoading: true, cornerRadius: 12)
    }
    .padding(BulkAITheme.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
