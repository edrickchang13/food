import SwiftUI

/// A thin horizontal progress indicator that is *not* a filled track.
///
/// The rail is a fixed neutral color; a small vertical tick marker sits at the
/// current value position. Used on the MacroFactor-parity dashboard cards where
/// the goal is "where am I along this scale" rather than "how full is this bar".
struct ThinProgressBar: View {

    let value: Double
    let total: Double
    let accent: Color
    let height: CGFloat

    init(
        value: Double,
        total: Double,
        accent: Color = BulkAITheme.Color.accent,
        height: CGFloat = 6
    ) {
        self.value = value
        self.total = total
        self.accent = accent
        self.height = height
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let tickWidth: CGFloat = 2
            let progress = Self.normalizedProgress(value: value, total: total)
            // Clamp so the tick stays fully inside the rail at the extremes.
            let maxOffset = max(0, width - tickWidth)
            let tickOffset = maxOffset * progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BulkAITheme.Color.surfaceElevated)
                    .frame(height: height)

                Rectangle()
                    .fill(accent)
                    .frame(width: tickWidth, height: height)
                    .offset(x: tickOffset)
            }
            .frame(height: height)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(Self.normalizedProgress(value: value, total: total) * 100)) percent")
    }

    private static func normalizedProgress(value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        let ratio = value / total
        return min(max(ratio, 0), 1)
    }
}

#Preview("ThinProgressBar — macro colors") {
    VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Protein • 0%")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
            ThinProgressBar(
                value: 0,
                total: 150,
                accent: BulkAITheme.Color.macroProtein
            )
        }

        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Fat • 50%")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
            ThinProgressBar(
                value: 35,
                total: 70,
                accent: BulkAITheme.Color.macroFat
            )
        }

        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Carbs • 100%")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
            ThinProgressBar(
                value: 240,
                total: 240,
                accent: BulkAITheme.Color.macroCarbs
            )
        }
    }
    .padding(BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(BulkAITheme.Color.background)
}
