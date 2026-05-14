import SwiftUI

/// GitHub-style activity heatmap.
///
/// Renders a grid of 7 rows by ceil(dayCount/7) columns of small rounded squares.
/// Each cell represents one day; its color is derived from `colorScale(value)`.
/// Days with no entry in `data` render in a neutral dim color.
///
/// Two initializers are provided:
/// - The full one that takes an explicit `colorScale` closure.
/// - A convenience one that takes a single `accent` color and auto-builds a
///   5-bucket linear scale from transparent to that accent.
struct ContributionGridView: View {
    let data: [Date: Double]
    let dayCount: Int
    let weekStartsOn: Day
    let colorScale: (Double) -> Color

    /// Full initializer with an explicit color scale.
    init(
        data: [Date: Double],
        dayCount: Int = 30,
        weekStartsOn: Day = .sunday,
        colorScale: @escaping (Double) -> Color
    ) {
        self.data = data
        self.dayCount = dayCount
        self.weekStartsOn = weekStartsOn
        self.colorScale = colorScale
    }

    /// Convenience initializer. Builds a 5-bucket linear ramp from a dim base to `accent`.
    /// Values are normalized against the max value in `data`.
    init(
        data: [Date: Double],
        dayCount: Int = 30,
        weekStartsOn: Day = .sunday,
        accent: Color
    ) {
        let maxValue = data.values.max() ?? 0
        self.data = data
        self.dayCount = dayCount
        self.weekStartsOn = weekStartsOn
        self.colorScale = Self.linearScale(accent: accent, maxValue: maxValue)
    }

    var body: some View {
        let days = orderedDays
        let columnCount = Int((Double(days.count) / 7.0).rounded(.up))

        GeometryReader { proxy in
            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
            let cellSize = max(8, (proxy.size.width - totalSpacing) / CGFloat(max(columnCount, 1)))

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columnCount, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            let index = column * 7 + row
                            cell(for: index, days: days, size: cellSize)
                        }
                    }
                }
            }
        }
        .frame(height: cellRowHeight)
    }

    @ViewBuilder
    private func cell(for index: Int, days: [Date], size: CGFloat) -> some View {
        if index < days.count {
            let day = days[index]
            let value = data[day] ?? 0
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(value > 0 ? colorScale(value) : emptyCellColor)
                .frame(width: size, height: size)
        } else {
            // Pad incomplete trailing columns so the grid keeps its shape.
            Color.clear.frame(width: size, height: size)
        }
    }

    private var cellRowHeight: CGFloat {
        // 7 cells of ~14pt + 6 gaps of 4pt is a sensible default canvas height.
        7 * 14 + 6 * 4
    }

    private var emptyCellColor: Color {
        Color.white.opacity(0.08)
    }

    /// Builds the ordered list of dates that will appear in the grid, oldest first.
    /// The first row is aligned to `weekStartsOn` so columns read as calendar weeks.
    private var orderedDays: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = weekStartsOn.calendarValue

        let today = calendar.startOfDay(for: Date())
        let earliest = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today

        // Walk backwards from the earliest visible day to the previous start-of-week
        // boundary so the first column is a full calendar week.
        let earliestWeekday = calendar.component(.weekday, from: earliest)
        let offsetToWeekStart = (earliestWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offsetToWeekStart, to: earliest) ?? earliest

        let totalDays = dayCount + offsetToWeekStart
        return (0..<totalDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private static func linearScale(accent: Color, maxValue: Double) -> (Double) -> Color {
        return { value in
            guard maxValue > 0 else { return accent.opacity(0.2) }
            let normalized = min(max(value / maxValue, 0), 1)
            // 5 buckets: 0.25, 0.45, 0.65, 0.85, 1.0 opacity.
            let bucket: Double
            switch normalized {
            case 0:                  bucket = 0
            case 0..<0.25:           bucket = 0.30
            case 0.25..<0.5:         bucket = 0.50
            case 0.5..<0.75:         bucket = 0.70
            case 0.75..<1.0:         bucket = 0.85
            default:                 bucket = 1.0
            }
            return accent.opacity(bucket)
        }
    }
}

/// Day-of-week enum for the grid's row alignment.
enum Day: Int, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    fileprivate var calendarValue: Int { rawValue }
}

#Preview("Food Logging + Weigh-In") {
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date())

    // Dense Food Logging data: most days have an entry, varying counts.
    let foodLogging: [Date: Double] = {
        var map: [Date: Double] = [:]
        for offset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            // Skip a couple of days to look realistic.
            if offset == 4 || offset == 11 || offset == 22 { continue }
            map[date] = Double((offset * 7 + 3) % 9) + 1
        }
        return map
    }()

    // Sparse Weigh-In data: only a handful of days have entries.
    let weighIn: [Date: Double] = {
        var map: [Date: Double] = [:]
        for offset in [2, 8, 14, 18, 25] {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            map[date] = 1
        }
        return map
    }()

    return VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Food Logging")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Last 30 Days")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            ContributionGridView(data: foodLogging, accent: BulkAITheme.Color.macroCalories)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Weigh-In")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Last 30 Days")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            ContributionGridView(data: weighIn, accent: BulkAITheme.Color.bodyMetrics)
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(BulkAITheme.Color.background)
}
