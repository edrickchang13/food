import SwiftUI

/// 2×2 grid of analytics tiles that sits beneath the dashboard pager.
///
/// Each tile is an `InsightCard` rendered with a domain-specific accent. The
/// section also carries its own header row with a `See All` link that surfaces
/// the deeper analytics screen. Tile order matches the MacroFactor reference:
/// Expenditure / Weight Trend on top, Energy Balance / Goal Progress on the
/// second row.
struct InsightsAnalyticsGrid: View {

    /// Data for a single tile. The grid owns layout; the caller owns content
    /// and tap behavior so this view stays a dumb renderer.
    struct Insight {
        let title: String
        let subtitle: String?
        let icon: String
        let accent: Color
        let sparkline: [Double]?
        let valueText: String
        let onTap: () -> Void

        init(
            title: String,
            subtitle: String? = nil,
            icon: String,
            accent: Color,
            sparkline: [Double]? = nil,
            valueText: String,
            onTap: @escaping () -> Void
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.accent = accent
            self.sparkline = sparkline
            self.valueText = valueText
            self.onTap = onTap
        }
    }

    let expenditure: Insight
    let weightTrend: Insight
    let energyBalance: Insight
    let goalProgress: Insight
    let onSeeAll: () -> Void

    private static let columns = [
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm),
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            header

            LazyVGrid(columns: Self.columns, spacing: BulkAITheme.Spacing.sm) {
                tile(for: expenditure)
                tile(for: weightTrend)
                tile(for: energyBalance)
                tile(for: goalProgress)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Insights & Analytics")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onSeeAll) {
                Text("See All")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(BulkAITheme.Color.accent)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(for insight: Insight) -> some View {
        InsightCard(
            title: insight.title,
            subtitle: insight.subtitle,
            icon: insight.icon,
            accent: insight.accent,
            sparkline: insight.sparkline,
            valueText: insight.valueText,
            onTap: insight.onTap
        )
    }
}

#Preview("Insights & Analytics") {
    // A flat, slowly-rising shape mirrors the reference screenshot where
    // expenditure has just nudged up over the week.
    let expenditureSparkline: [Double] = [2950, 2980, 2970, 3010, 2995, 2987, 2987]
    let weightSparkline: [Double] = [178.4, 178.6, 178.8, 179.0, 179.0, 179.1, 179.1]
    // A bar-chart-like profile so the line drawn through it reads as columns
    // alternating in height — InsightCard only knows sparklines.
    let energyBalanceBars: [Double] = [-180, -240, -210, -310, -200, -260, -234]

    return ScrollView {
        InsightsAnalyticsGrid(
            expenditure: .init(
                title: "Expenditure",
                subtitle: "Last 7 Days",
                icon: "flame.fill",
                accent: BulkAITheme.Color.expenditure,
                sparkline: expenditureSparkline,
                valueText: "2987 kcal",
                onTap: {}
            ),
            weightTrend: .init(
                title: "Weight Trend",
                subtitle: "Last 7 Days",
                icon: "scalemass.fill",
                accent: BulkAITheme.Color.weightTrend,
                sparkline: weightSparkline,
                valueText: "179.1 lbs",
                onTap: {}
            ),
            energyBalance: .init(
                title: "Energy Balance",
                subtitle: "Last 7 Days",
                icon: "chart.bar.fill",
                accent: BulkAITheme.Color.macroCalories,
                sparkline: energyBalanceBars,
                valueText: "234 kcal deficit",
                onTap: {}
            ),
            goalProgress: .init(
                title: "Goal Progress",
                subtitle: "Last 372 Days",
                icon: "target",
                accent: BulkAITheme.Color.macroCarbs,
                sparkline: nil,
                valueText: "81 %",
                onTap: {}
            ),
            onSeeAll: {}
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
