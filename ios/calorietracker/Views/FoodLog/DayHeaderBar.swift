import SwiftUI

/// Top header bar for the Food Log tab.
///
/// Layout (left to right):
/// - Hamburger menu button (SF Symbol `line.3.horizontal`) on the leading edge
/// - Centered group: chevron-left, bold day label ("Today" when the selected
///   date is today, otherwise a formatted weekday/month/day string),
///   chevron-right
/// - Trailing edge intentionally empty so the centered group reads as the
///   focal element of the bar
///
/// Mirrors `IMG_6465.PNG` in `~/Downloads/macrofactor-screens/`. The chevrons
/// rewind/advance the bound date by one calendar day. The hamburger does not
/// own its own destination — the parent supplies an action.
struct DayHeaderBar: View {

    @Binding var date: Date
    let onMenuTap: () -> Void

    /// Calendar used for day arithmetic and "is today" comparisons. Defaults
    /// to `.current` so the bar follows the device locale and time zone.
    var calendar: Calendar = .current

    var body: some View {
        ZStack {
            HStack {
                menuButton
                Spacer()
            }

            centerGroup
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(BulkAITheme.Color.background)
        .accessibilityElement(children: .contain)
    }

    // MARK: Menu

    private var menuButton: some View {
        Button(action: onMenuTap) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
    }

    // MARK: Center group

    private var centerGroup: some View {
        HStack(spacing: BulkAITheme.Spacing.md) {
            chevronButton(systemName: "chevron.left", delta: -1, label: "Previous day")

            Text(dayLabel)
                .font(BulkAITheme.Typography.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(minWidth: 80)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            chevronButton(systemName: "chevron.right", delta: 1, label: "Next day")
        }
    }

    private func chevronButton(systemName: String, delta: Int, label: String) -> some View {
        Button {
            shiftDate(by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityHidden(true)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Behavior

    private func shiftDate(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: date) else { return }
        date = next
    }

    // MARK: Formatting

    private var dayLabel: String {
        if calendar.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }
}

#Preview("DayHeaderBar — Today") {
    StatefulPreviewContainer(Date()) { binding in
        VStack(spacing: 0) {
            DayHeaderBar(date: binding, onMenuTap: {})
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("DayHeaderBar — Past day") {
    StatefulPreviewContainer(
        Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    ) { binding in
        VStack(spacing: 0) {
            DayHeaderBar(date: binding, onMenuTap: {})
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

/// Tiny stateful wrapper so `#Preview` blocks can host a `@Binding`-driven view
/// without forcing every preview to declare its own `@State`-bearing struct.
/// Kept fileprivate so it does not leak into the app target's namespace.
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
