import SwiftUI

// MARK: - Weekly Nutrition

/// MacroFactor-style "Weekly Nutrition" card: seven vertical bars, one per
/// calendar day for the last 7 days ending today. Each bar is split into
/// protein / fat / carbs segments sized by their calorie contribution
/// (protein × 4, carbs × 4, fat × 9). All bars share a single y-scale equal
/// to max(observed daily total, kcalFloor) so a quiet day doesn't dominate.
struct WeeklyNutritionView: View {
    @Environment(FoodStore.self) private var foodStore

    /// Minimum top of the shared y-axis. Keeps the visual scale stable on
    /// quiet days and prevents the loudest day from squashing everything.
    private static let kcalFloor: Double = 2000

    /// Fixed height for the bar plotting area (inside the card).
    private static let barAreaHeight: CGFloat = 140

    private var weekDays: [DayTotals] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Build oldest → newest so the bars read left-to-right with today
        // on the right edge of the row.
        return (0..<7).reversed().map { offset -> DayTotals in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let entries = foodStore.entries.filter {
                calendar.isDate($0.timestamp, inSameDayAs: day)
            }
            let protein = entries.reduce(0) { $0 + $1.protein }
            let carbs = entries.reduce(0) { $0 + $1.carbs }
            let fat = entries.reduce(0) { $0 + $1.fat }
            return DayTotals(
                id: day,
                date: day,
                proteinKcal: Double(protein) * 4,
                carbsKcal: Double(carbs) * 4,
                fatKcal: Double(fat) * 9
            )
        }
    }

    private var yMax: Double {
        let observed = weekDays.map(\.totalKcal).max() ?? 0
        return max(observed, Self.kcalFloor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            card
        }
    }

    // MARK: - Sections

    private var header: some View {
        Text("WEEKLY NUTRITION")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private var card: some View {
        let days = weekDays
        let scale = yMax
        return VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days) { day in
                    DayBar(day: day, yMax: scale, barAreaHeight: Self.barAreaHeight)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Self.barAreaHeight)

            HStack(spacing: 10) {
                ForEach(days) { day in
                    DayLabel(date: day.date, isToday: day.isToday)
                        .frame(maxWidth: .infinity)
                }
            }

            LegendRow()
                .padding(.top, 2)
        }
        .padding(20)
        .background(BulkAITheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Per-day totals (file-scope so subviews can reference it)

fileprivate struct DayTotals: Identifiable {
    let id: Date
    let date: Date
    let proteinKcal: Double
    let carbsKcal: Double
    let fatKcal: Double

    var totalKcal: Double { proteinKcal + carbsKcal + fatKcal }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

// MARK: - Single-day stacked bar

private struct DayBar: View {
    let day: DayTotals
    let yMax: Double
    let barAreaHeight: CGFloat

    /// Height of the filled bar within the bar plotting area.
    private var filledHeight: CGFloat {
        guard yMax > 0 else { return 0 }
        let ratio = min(day.totalKcal / yMax, 1.0)
        return barAreaHeight * CGFloat(ratio)
    }

    /// Height a macro segment should occupy, given the filled bar's total
    /// height. Returns 0 on empty days so the bar collapses cleanly.
    private func segmentHeight(_ kcal: Double) -> CGFloat {
        guard day.totalKcal > 0 else { return 0 }
        return filledHeight * CGFloat(kcal / day.totalKcal)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Empty-day track so quiet days still show a faint column.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: barAreaHeight)

            if day.totalKcal > 0 {
                // Stack from bottom: fat, carbs, protein (top).
                // We use a single rounded clip so the entire stack reads as
                // one bar rather than three stacked rectangles.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: segmentHeight(day.proteinKcal))
                    Rectangle()
                        .fill(Color.green)
                        .frame(height: segmentHeight(day.carbsKcal))
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(height: segmentHeight(day.fatKcal))
                }
                .frame(height: filledHeight, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: filledHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: barAreaHeight, alignment: .bottom)
    }
}

// MARK: - Day-letter label

private struct DayLabel: View {
    let date: Date
    let isToday: Bool

    private var letter: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEEE" // narrow weekday, e.g. S M T W T F S
        return formatter.string(from: date)
    }

    var body: some View {
        Text(letter)
            .font(.system(.caption2, design: .rounded, weight: isToday ? .bold : .semibold))
            .foregroundStyle(isToday ? BulkAITheme.Color.accent : Color.secondary)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Legend

private struct LegendRow: View {
    var body: some View {
        HStack(spacing: 14) {
            legendDot(color: .red, label: "Protein")
            legendDot(color: .green, label: "Carbs")
            legendDot(color: .yellow, label: "Fat")
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

