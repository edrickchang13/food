import SwiftUI

/// Two side-by-side habit cards: Weigh-In (sparse green grid) and Food Logging
/// (dense blue grid). Each card has its own header, a 30-day contribution grid,
/// and a footer row showing "X/7 this week" plus a chevron affordance.
struct HabitsSection: View {

    let weighInData: [Date: Double]
    let weighInThisWeek: String
    let foodLoggingData: [Date: Double]
    let foodLoggingThisWeek: String
    let onWeighInTap: () -> Void
    let onFoodLoggingTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            Text("Habits")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: BulkAITheme.Spacing.sm) {
                card(
                    title: "Weigh-In",
                    subtitle: "Last 30 Days",
                    weekStat: weighInThisWeek,
                    data: weighInData,
                    accent: BulkAITheme.Color.macroCarbs,
                    onTap: onWeighInTap
                )

                card(
                    title: "Food Logging",
                    subtitle: "Last 30 Days",
                    weekStat: foodLoggingThisWeek,
                    data: foodLoggingData,
                    accent: BulkAITheme.Color.macroCalories,
                    onTap: onFoodLoggingTap
                )
            }
        }
    }

    private func card(
        title: String,
        subtitle: String,
        weekStat: String,
        data: [Date: Double],
        accent: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                ContributionGridView(
                    data: data,
                    dayCount: 30,
                    weekStartsOn: .sunday,
                    accent: accent
                )

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(weekStat)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("this week")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .surfaceCard()
    }
}

#Preview("Habits") {
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date())

    // Sparse Weigh-In: a handful of greens in a month.
    let weighIn: [Date: Double] = {
        var map: [Date: Double] = [:]
        for offset in [2, 8, 14, 18, 25] {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            map[date] = 1
        }
        return map
    }()

    // Dense Food Logging: most days have a value, scaled so the linear ramp
    // shows visible variation.
    let foodLogging: [Date: Double] = {
        var map: [Date: Double] = [:]
        for offset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if offset == 4 || offset == 11 || offset == 22 { continue }
            map[date] = Double((offset * 7 + 3) % 9) + 1
        }
        return map
    }()

    return ScrollView {
        HabitsSection(
            weighInData: weighIn,
            weighInThisWeek: "0/7",
            foodLoggingData: foodLogging,
            foodLoggingThisWeek: "2/7",
            onWeighInTap: {},
            onFoodLoggingTap: {}
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
