import SwiftUI

/// Horizontal 7-chip day picker for the week containing `selectedDate`.
///
/// Each chip is a fixed ~44pt-wide pill with a weekday letter on top and the
/// day number below. Three visual states, matching `IMG_6465.PNG`:
///
/// - **Selected**: filled neutral gray pill with a small `accent` dot below
///   the day number.
/// - **Logged (past)**: cyan-blue outline ring around the pill, plain text
///   inside. Only past days with logged entries get the ring; the selected
///   state always wins over the ring.
/// - **Unlogged**: plain text, no decoration.
///
/// The strip is non-scrolling — it shows exactly the 7 days of the week
/// containing `selectedDate`, recomputed when that binding changes. Tapping a
/// chip moves `selectedDate` to that day.
struct WeekStrip: View {

    @Binding var selectedDate: Date
    let loggedDates: Set<Date>
    var accent: Color = BulkAITheme.Color.macroCalories

    /// Calendar used to derive the visible week and start-of-day comparisons.
    var calendar: Calendar = .current

    // MARK: Body

    var body: some View {
        let days = weekDays(containing: selectedDate)
        let startOfToday = calendar.startOfDay(for: Date())

        HStack(spacing: BulkAITheme.Spacing.xs) {
            ForEach(days, id: \.self) { day in
                chip(for: day, startOfToday: startOfToday)
            }
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(BulkAITheme.Color.background)
    }

    // MARK: Chip

    private func chip(for day: Date, startOfToday: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isPast = day < startOfToday
        let isLogged = loggedDates.contains(calendar.startOfDay(for: day))
        let showsRing = isLogged && isPast && !isSelected

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 2) {
                Text(weekdayLetter(for: day))
                    .font(BulkAITheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.65))
                Text(dayNumber(for: day))
                    .font(BulkAITheme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.9))
                // Reserve the dot's height even when hidden so chips stay
                // vertically aligned across all three visual states.
                Circle()
                    .fill(isSelected ? accent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 44, height: 60)
            .background(
                Capsule()
                    .fill(isSelected ? BulkAITheme.Color.surfaceElevated : .clear)
            )
            .overlay(
                Capsule()
                    .stroke(
                        showsRing ? accent : .white.opacity(0.18),
                        lineWidth: showsRing ? 1.5 : 0.5
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day, isLogged: isLogged))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: Week derivation

    private func weekDays(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        let start = interval.start
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    // MARK: Formatting

    private func weekdayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "EEEEE" // single-letter weekday
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func accessibilityLabel(for date: Date, isLogged: Bool) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        let base = formatter.string(from: date)
        return isLogged ? "\(base), logged" : base
    }
}

#Preview("WeekStrip — current week, 3 days logged") {
    let calendar = Calendar.current
    let today = Date()
    // Mark the three most recent past days as logged so the cyan ring is
    // visible in the preview without depending on real FoodStore data.
    let loggedPastDates: Set<Date> = Set(
        (1...3).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { calendar.startOfDay(for: $0) }
        }
    )

    return StatefulPreviewContainer(today) { binding in
        VStack(spacing: BulkAITheme.Spacing.md) {
            DayHeaderBar(date: binding, onMenuTap: {})
            WeekStrip(
                selectedDate: binding,
                loggedDates: loggedPastDates
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

/// Local stateful preview wrapper. Duplicated fileprivate alongside
/// `DayHeaderBar.swift` to keep each preview self-contained without exposing
/// a shared helper in the app target.
private struct StatefulPreviewContainer<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
