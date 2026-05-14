import SwiftUI

/// First hero card of the Dashboard pager. Mirrors MacroFactor's IMG_6455:
/// big DASHBOARD headline, then a 4-row × 7-column grid of vertical macro bars
/// (calories / protein / fat / carbs) with the selected day highlighted by a
/// rounded outline, and a "Consumed / Remaining" toggle at the bottom.
struct WeeklyNutritionCard: View {

    struct DayTotals: Hashable {
        let weekday: String
        let kcal: Int
        let protein: Int
        let fat: Int
        let carbs: Int
    }

    let dateLabel: String
    let week: [DayTotals]
    let targets: DayTotals
    @Binding var selectedIndex: Int
    @Binding var consumedVsRemaining: Int
    var isLoading: Bool = false
    /// Fires when the user taps a specific day column. Carries the
    /// `dayIndex` (0..<7, where 6 is "today" and 0 is six days ago) so
    /// the parent can route to a per-day calorie chart / food log.
    /// Optional so consumers that just want the in-card highlight (no
    /// deep-link) can omit it.
    var onSelectDay: ((Int) -> Void)? = nil

    // MARK: Layout constants

    private let columnSpacing: CGFloat = 10
    private let barWidth: CGFloat = 8
    private let rowHeight: CGFloat = 28
    private let rowSpacing: CGFloat = 6
    private let selectionInset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            header
            sectionTitle
            gridWithTotals
            toggleRow
        }
        .surfaceCard(padding: BulkAITheme.Spacing.md)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            Text(dateLabel)
                .font(BulkAITheme.Typography.caption2)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))

            Text("DASHBOARD")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: some View {
        Text("Weekly Nutrition")
            .font(BulkAITheme.Typography.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Grid + totals

    private var gridWithTotals: some View {
        HStack(alignment: .top, spacing: BulkAITheme.Spacing.md) {
            grid
                .frame(maxWidth: .infinity, alignment: .leading)
            totalsColumn
        }
    }

    private var grid: some View {
        let macros: [Macro] = [.calories, .protein, .fat, .carbs]

        return VStack(spacing: rowSpacing) {
            // 4 rows of 7 vertical bars, with an overlay highlighting the selected column.
            ForEach(macros, id: \.self) { macro in
                HStack(spacing: columnSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        verticalBar(macro: macro, dayIndex: dayIndex)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: rowHeight)
            }

            // Weekday letter row.
            HStack(spacing: columnSpacing) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    Text(weekdayLetter(at: dayIndex))
                        .font(BulkAITheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            dayIndex == selectedIndex
                                ? BulkAITheme.Color.accent
                                : .white.opacity(0.6)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                let columnCount = CGFloat(7)
                let totalSpacing = columnSpacing * (columnCount - 1)
                let columnWidth = max((proxy.size.width - totalSpacing) / columnCount, 0)
                let selectedX = (columnWidth + columnSpacing) * CGFloat(selectedIndex)
                let height = (rowHeight * 4) + (rowSpacing * 3)

                RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    .frame(
                        width: columnWidth + (selectionInset * 2),
                        height: height + (selectionInset * 2)
                    )
                    .offset(x: selectedX - selectionInset, y: -selectionInset)
                    .animation(.snappy, value: selectedIndex)
            }
            .allowsHitTesting(false)
        }
        // Per-column tap layer — each column is a full-height transparent
        // button that selects that day and fires `onSelectDay`. Sits on
        // top of the bars (which are decorative). Without this, the bars
        // looked tappable but did nothing — the user couldn't drill into
        // a specific day's intake. The selection-outline overlay above
        // disables hit testing so this layer reliably catches taps.
        .overlay(alignment: .topLeading) {
            HStack(spacing: columnSpacing) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    Button {
                        selectedIndex = dayIndex
                        onSelectDay?(dayIndex)
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabelForColumn(dayIndex: dayIndex))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: (rowHeight * 4) + (rowSpacing * 3))
        }
    }

    /// Spoken summary for VoiceOver — combines the weekday letter and the
    /// kcal total so the user knows what they're about to drill into.
    private func accessibilityLabelForColumn(dayIndex: Int) -> String {
        let day = week[safe: dayIndex]
        let kcal = day.map(\.kcal) ?? 0
        return "\(weekdayLetter(at: dayIndex)), \(kcal) calories. Open day"
    }

    @ViewBuilder
    private func verticalBar(macro: Macro, dayIndex: Int) -> some View {
        let day = week[safe: dayIndex]
        let value = day.map { macroValue(for: macro, in: $0) } ?? 0
        let target = macroValue(for: macro, in: targets)
        let fraction = target > 0 ? min(max(Double(value) / Double(target), 0), 1) : 0

        ZStack(alignment: .bottom) {
            // Background track for the bar.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(BulkAITheme.Color.surfaceElevated)
                .frame(width: barWidth)

            // Filled portion.
            GeometryReader { proxy in
                let filledHeight = proxy.size.height * fraction
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: macro))
                        .frame(width: barWidth, height: filledHeight)
                        .skeleton(isLoading: isLoading, cornerRadius: 3)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: barWidth)
        }
        .frame(width: barWidth, height: rowHeight, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Totals column

    private var totalsColumn: some View {
        let day = week[safe: selectedIndex]
        let consumed = day.map { macroValue(for: .calories, in: $0) } ?? 0
        let consumedProtein = day.map { macroValue(for: .protein, in: $0) } ?? 0
        let consumedFat = day.map { macroValue(for: .fat, in: $0) } ?? 0
        let consumedCarbs = day.map { macroValue(for: .carbs, in: $0) } ?? 0

        let isRemaining = consumedVsRemaining == 1
        let displayKcal = isRemaining
            ? max(targets.kcal - consumed, 0) : consumed
        let displayProtein = isRemaining
            ? max(targets.protein - consumedProtein, 0) : consumedProtein
        let displayFat = isRemaining
            ? max(targets.fat - consumedFat, 0) : consumedFat
        let displayCarbs = isRemaining
            ? max(targets.carbs - consumedCarbs, 0) : consumedCarbs

        return VStack(alignment: .trailing, spacing: BulkAITheme.Spacing.sm) {
            totalRow(
                value: displayKcal,
                target: targets.kcal,
                trailing: .flame,
                color: BulkAITheme.Color.macroCalories
            )
            totalRow(
                value: displayProtein,
                target: targets.protein,
                trailing: .letter("P"),
                color: BulkAITheme.Color.macroProtein
            )
            totalRow(
                value: displayFat,
                target: targets.fat,
                trailing: .letter("F"),
                color: BulkAITheme.Color.macroFat
            )
            totalRow(
                value: displayCarbs,
                target: targets.carbs,
                trailing: .letter("C"),
                color: BulkAITheme.Color.macroCarbs
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private enum TotalTrailing {
        case flame
        case letter(String)
    }

    @ViewBuilder
    private func totalRow(value: Int, target: Int, trailing: TotalTrailing, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value)")
                        .font(BulkAITheme.Typography.headline)
                        .foregroundStyle(.white)
                        .skeleton(isLoading: isLoading)
                    switch trailing {
                    case .flame:
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    case .letter(let glyph):
                        Text(glyph)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                    }
                }
                Text("of \(target)")
                    .font(BulkAITheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .skeleton(isLoading: isLoading)
            }
        }
    }

    // MARK: - Toggle

    private var toggleRow: some View {
        HStack {
            Spacer()
            SegmentedToggle(
                options: ("Consumed", "Remaining"),
                selection: $consumedVsRemaining
            )
            Spacer()
        }
        .padding(.top, BulkAITheme.Spacing.xxs)
    }

    // MARK: - Helpers

    private enum Macro: Hashable {
        case calories
        case protein
        case fat
        case carbs
    }

    private func macroValue(for macro: Macro, in totals: DayTotals) -> Int {
        switch macro {
        case .calories: return totals.kcal
        case .protein: return totals.protein
        case .fat: return totals.fat
        case .carbs: return totals.carbs
        }
    }

    private func color(for macro: Macro) -> Color {
        switch macro {
        case .calories: return BulkAITheme.Color.macroCalories
        case .protein: return BulkAITheme.Color.macroProtein
        case .fat: return BulkAITheme.Color.macroFat
        case .carbs: return BulkAITheme.Color.macroCarbs
        }
    }

    private func weekdayLetter(at index: Int) -> String {
        // Mon-Sun order; first letter only, with Thursday rendered as "T" (same as Tuesday).
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        guard letters.indices.contains(index) else { return "" }
        return letters[index]
    }
}

// MARK: - Array safe-indexing

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

private struct WeeklyNutritionCardPreviewHarness: View {
    @State private var selectedIndex: Int = 2
    @State private var mode: Int = 0

    private let week: [WeeklyNutritionCard.DayTotals] = [
        .init(weekday: "Mon", kcal: 2980, protein: 175, fat: 92, carbs: 360),
        .init(weekday: "Tue", kcal: 2640, protein: 162, fat: 80, carbs: 310),
        .init(weekday: "Wed", kcal: 1820, protein: 110, fat: 64, carbs: 220),
        .init(weekday: "Thu", kcal: 0, protein: 0, fat: 0, carbs: 0),
        .init(weekday: "Fri", kcal: 0, protein: 0, fat: 0, carbs: 0),
        .init(weekday: "Sat", kcal: 0, protein: 0, fat: 0, carbs: 0),
        .init(weekday: "Sun", kcal: 0, protein: 0, fat: 0, carbs: 0)
    ]

    private let targets = WeeklyNutritionCard.DayTotals(
        weekday: "T",
        kcal: 3415,
        protein: 190,
        fat: 113,
        carbs: 407
    )

    var body: some View {
        ScrollView {
            WeeklyNutritionCard(
                dateLabel: "WEDNESDAY, MAY 13",
                week: week,
                targets: targets,
                selectedIndex: $selectedIndex,
                consumedVsRemaining: $mode
            )
            .padding(BulkAITheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("WeeklyNutritionCard") {
    WeeklyNutritionCardPreviewHarness()
}

private struct WeeklyNutritionCardLoadingPreviewHarness: View {
    @State private var selectedIndex: Int = 2
    @State private var mode: Int = 0

    private let targets = WeeklyNutritionCard.DayTotals(
        weekday: "T",
        kcal: 3415,
        protein: 190,
        fat: 113,
        carbs: 407
    )

    var body: some View {
        ScrollView {
            WeeklyNutritionCard(
                dateLabel: "WEDNESDAY, MAY 13",
                week: [],
                targets: targets,
                selectedIndex: $selectedIndex,
                consumedVsRemaining: $mode,
                isLoading: true
            )
            .padding(BulkAITheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("WeeklyNutritionCard — loading") {
    WeeklyNutritionCardLoadingPreviewHarness()
}
