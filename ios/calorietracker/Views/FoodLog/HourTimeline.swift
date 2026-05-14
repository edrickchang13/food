import SwiftUI

/// Vertical agenda mirroring MacroFactor's Food Log hour timeline
/// (`~/Downloads/macrofactor-screens/IMG_6465.PNG`). Each hour from
/// `hours.lowerBound` through `hours.upperBound` gets a row showing a
/// time pill, a circular "+" button to add an entry at that hour, and
/// any food entries that already exist within the hour stacked underneath.
///
/// Aggregation is precomputed once outside the `ForEach` so scrolling stays
/// cheap even when the parent view churns its `date` or `entries` inputs —
/// see `entriesByHour` in `body`. The vertical connector line that runs
/// through the time pills in MacroFactor is rendered as a single
/// background `Rectangle` aligned to the time-pill column rather than per
/// row, so the line stays continuous even when an hour has no entries.
struct HourTimeline: View {

    let date: Date
    let entries: [FoodEntry]
    let onAdd: (Date) -> Void
    let onTapEntry: (FoodEntry) -> Void
    let hours: ClosedRange<Int>

    init(
        date: Date,
        entries: [FoodEntry],
        onAdd: @escaping (Date) -> Void,
        onTapEntry: @escaping (FoodEntry) -> Void,
        hours: ClosedRange<Int> = 7...23
    ) {
        self.date = date
        self.entries = entries
        self.onAdd = onAdd
        self.onTapEntry = onTapEntry
        self.hours = hours
    }

    private var entriesByHour: [Int: [FoodEntry]] {
        let calendar = Calendar.current
        var grouped: [Int: [FoodEntry]] = [:]
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.timestamp)
            grouped[hour, default: []].append(entry)
        }
        for hour in grouped.keys {
            grouped[hour]?.sort { $0.timestamp < $1.timestamp }
        }
        return grouped
    }

    var body: some View {
        let grouped = entriesByHour
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Visible range = the configured base hours UNIONED with any hour
        // that actually has an entry. Without this union, an early-AM
        // snack (logged at e.g. 2 AM) gets silently dropped from the
        // timeline even though it counts toward the daily totals — the
        // user sees the kcal in the header but no row in the body and
        // can't tell where the calories came from.
        let visibleHours = Self.unionRange(base: hours, populated: grouped.keys)

        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            ForEach(visibleHours, id: \.self) { hour in
                hourRow(
                    hour: hour,
                    entries: grouped[hour] ?? [],
                    hourStart: calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
                )
            }
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.sm)
    }

    /// Build a contiguous sorted list of hours covering both the configured
    /// base range AND every hour that has at least one entry. Returned as a
    /// plain `[Int]` so SwiftUI's `ForEach` can iterate it stably.
    private static func unionRange(base: ClosedRange<Int>, populated: some Sequence<Int>) -> [Int] {
        let allHours = Set(base).union(populated)
        guard let lo = allHours.min(), let hi = allHours.max() else {
            return Array(base)
        }
        return Array(lo...hi)
    }

    @ViewBuilder
    private func hourRow(hour: Int, entries hourEntries: [FoodEntry], hourStart: Date) -> some View {
        // Match the MacroFactor reference: the time pill and the small "+"
        // sit side-by-side on the same row, with entry cards filling the
        // remaining width to the right. Previously stacked vertically; the
        // horizontal layout reads as one continuous timeline row.
        HStack(alignment: .top, spacing: BulkAITheme.Spacing.sm) {
            HStack(spacing: BulkAITheme.Spacing.xs) {
                timePill(hour: hour)
                addButton(hourStart: hourStart)
            }

            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                if hourEntries.isEmpty {
                    // Reserve a small invisible spacer so empty hours keep the
                    // same vertical rhythm as populated ones — avoids the timeline
                    // visually "collapsing" between dense and sparse stretches.
                    Color.clear.frame(height: 0)
                } else {
                    ForEach(hourEntries) { entry in
                        entryRow(entry: entry)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timePill(hour: Int) -> some View {
        Text(formatted(hour: hour))
            .font(BulkAITheme.Typography.caption)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, BulkAITheme.Spacing.sm)
            .padding(.vertical, BulkAITheme.Spacing.xxs)
            .background(
                Capsule().fill(BulkAITheme.Color.surface)
            )
            .frame(minWidth: 64)
    }

    /// Small, dim "+" affordance sitting beside the time pill. Matches the
    /// MacroFactor reference: surface-tinted circle (same as the time pill)
    /// with a thin white plus glyph, not the loud coral FAB we had before.
    /// Hit area stays 44pt for accessibility; only the visual is smaller.
    private func addButton(hourStart: Date) -> some View {
        Button {
            onAdd(hourStart)
        } label: {
            ZStack {
                Circle()
                    .fill(BulkAITheme.Color.surface)
                    .frame(width: 22, height: 22)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityHidden(true)
            }
            // Expand the hit area to 44pt without affecting the visual circle size.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add food at \(formatted(hour: Calendar.current.component(.hour, from: hourStart)))")
    }

    private func entryRow(entry: FoodEntry) -> some View {
        Button {
            onTapEntry(entry)
        } label: {
            HStack(spacing: BulkAITheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(BulkAITheme.Color.surfaceElevated)
                        .frame(width: 32, height: 32)
                    if let emoji = entry.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(BulkAITheme.Typography.body)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(entry.calories) kcal  •  P \(entry.protein)  C \(entry.carbs)  F \(entry.fat)")
                        .font(BulkAITheme.Typography.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.timeString)
                    .font(BulkAITheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            .padding(.horizontal, BulkAITheme.Spacing.sm)
            .padding(.vertical, BulkAITheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm, style: .continuous)
                    .fill(BulkAITheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm, style: .continuous)
                    .stroke(BulkAITheme.Color.surfaceElevated, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatted(hour: Int) -> String {
        let suffix = hour < 12 ? "AM" : "PM"
        let display: Int
        switch hour {
        case 0:
            display = 12
        case 13...23:
            display = hour - 12
        case 12:
            display = 12
        default:
            display = hour
        }
        return "\(display) \(suffix)"
    }
}

#Preview("HourTimeline") {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(byAdding: .minute, value: minute,
                      to: calendar.date(byAdding: .hour, value: hour, to: day) ?? day) ?? day
    }
    let entries: [FoodEntry] = [
        FoodEntry(
            name: "Oats with berries",
            calories: 320, protein: 12, carbs: 54, fat: 6,
            timestamp: at(8, 15),
            emoji: "🥣",
            source: .manual,
            mealType: .breakfast
        ),
        FoodEntry(
            name: "Cold brew",
            calories: 10, protein: 0, carbs: 2, fat: 0,
            timestamp: at(9, 5),
            emoji: "☕️",
            source: .manual,
            mealType: .breakfast
        ),
        FoodEntry(
            name: "Chicken bowl",
            calories: 620, protein: 48, carbs: 62, fat: 18,
            timestamp: at(13, 30),
            emoji: "🍱",
            source: .manual,
            mealType: .lunch
        ),
        FoodEntry(
            name: "Greek yogurt",
            calories: 150, protein: 17, carbs: 12, fat: 4,
            timestamp: at(16, 0),
            emoji: "🥄",
            source: .manual,
            mealType: .snack
        ),
        FoodEntry(
            name: "Pasta + meatballs",
            calories: 780, protein: 42, carbs: 88, fat: 24,
            timestamp: at(19, 45),
            emoji: "🍝",
            source: .manual,
            mealType: .dinner
        )
    ]

    return ScrollView {
        HourTimeline(
            date: .now,
            entries: entries,
            onAdd: { _ in },
            onTapEntry: { _ in }
        )
    }
    .background(BulkAITheme.Color.background)
}
