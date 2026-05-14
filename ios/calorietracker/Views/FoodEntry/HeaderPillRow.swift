import SwiftUI

/// The pill header row at the top of MacroFactor's Food Entry sheet.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6466.PNG` plus the
/// `~/Downloads/macrofactor-screens/staged-progress.png` variant.
///
/// Layout, left to right:
///   1. Circular X close button
///   2. Time pill ("9 AM"-style label, tappable to pick a different hour)
///   3. Calorie progress pill — `consumed + staged / target` with a thin
///      progress bar drawn along the top edge of the capsule. The bar
///      colors the *staged* portion in coral so the user can see how
///      much they're about to commit; the *already-logged* portion sits
///      underneath in white.
///   4. Either the utensils pill (when nothing is staged) OR a horizontal
///      strip of emoji bubbles representing each staged entry, capped at
///      the first 4 so the row doesn't overflow on small phones.
///   5. Down-chevron pill (collapse the sheet)
///
/// Each pill sits on `BulkAITheme.Color.surface` and shares the same height
/// so the row reads as a single segmented control. Tap targets are at least
/// 44pt so the row stays comfortable to thumb-press from the bottom sheet.
struct HeaderPillRow: View {

    // MARK: State

    @Binding var time: Date
    let consumed: Int
    let target: Int
    /// Kcal queued in the parent's staging buffer. Surfaces additively in
    /// the calorie pill so the user knows the cost of the staged batch
    /// before they hit "Log Foods".
    let stagedKcal: Int
    /// One emoji per staged entry. Renders as a horizontal bubble strip in
    /// place of the utensils pill. Empty → utensils pill renders normally.
    let stagedEmojis: [String]
    @Binding var mealType: MealType?
    let onClose: () -> Void
    let onCollapse: () -> Void

    @State private var isPickingTime = false
    @State private var isPickingMealType = false

    // MARK: Layout constants

    private static let pillHeight: CGFloat = 44
    private static let circleSize: CGFloat = 44
    /// Stroke width of the calorie-pill perimeter progress ring. 3 pt
    /// reads clearly without crowding the centered "consumed / target"
    /// label inside the pill.
    private static let ringStroke: CGFloat = 3
    /// Cap on how many emoji bubbles we render in the strip. Beyond this we
    /// show a "+N" overflow bubble so the row stays the same width on
    /// every phone size.
    private static let maxVisibleEmojis: Int = 4
    private static let emojiBubbleSize: CGFloat = 28

    // MARK: Body

    var body: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            closeButton
            timePill
            caloriePill
            if stagedEmojis.isEmpty {
                utensilsPill
            } else {
                stagedItemsStrip
            }
            collapseButton
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.sm)
        .sheet(isPresented: $isPickingTime) {
            timePickerSheet
        }
        .confirmationDialog(
            "Meal type",
            isPresented: $isPickingMealType,
            titleVisibility: .visible
        ) {
            mealTypeDialogButtons
        }
        .coachMark(
            seenKey: "coachmark.foodentry.headerpills.v1",
            title: "Set time, meal, and totals at a glance",
            message: "These pills control what slot your foods land in. Tap the time or meal pill to change them.",
            alignment: .bottom
        )
    }

    // MARK: Pills

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
                .frame(width: Self.circleSize, height: Self.circleSize)
                .background(
                    Circle().fill(BulkAITheme.Color.surface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var timePill: some View {
        Button {
            isPickingTime = true
        } label: {
            Text(timeLabel)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, BulkAITheme.Spacing.md)
                .frame(height: Self.pillHeight)
                .background(
                    Capsule().fill(BulkAITheme.Color.surface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change time, currently \(timeLabel)")
    }

    /// Calorie pill with a top-edge progress bar. Total + staged numerator
    /// updates live as the user stages more items; the staged portion of
    /// the bar is tinted with the accent so the delta reads as "what
    /// you're about to log" rather than "what's already there."
    private var caloriePill: some View {
        let total = consumed + max(stagedKcal, 0)
        let loggedFraction = target > 0 ? min(Double(consumed) / Double(target), 1) : 0
        let totalFraction = target > 0 ? min(Double(total) / Double(target), 1) : 0

        return ZStack {
            // Pill body — the surface the ring traces around.
            Capsule()
                .fill(BulkAITheme.Color.surface)

            // Coral staged-fill ring sits underneath the white logged ring
            // so the white portion overlays it cleanly. Total = logged +
            // staged, so this stroke ends where the staged delta ends.
            // When stagedKcal == 0 the totalFraction equals loggedFraction
            // and this stroke is fully covered by the white one above.
            //
            // No `rotationEffect`: capsules aren't rotationally symmetric
            // like circles. Rotating the stroked capsule 90 degrees warps
            // the shape into a vertical pill that gets clipped to the
            // wide horizontal bounds, leaving only the left and right
            // arcs visible. Trim from 0 traces the perimeter from
            // Capsule's native path origin (the top edge) clockwise.
            Capsule()
                .trim(from: 0, to: CGFloat(totalFraction))
                .stroke(
                    BulkAITheme.Color.accent,
                    style: StrokeStyle(lineWidth: Self.ringStroke, lineCap: .round)
                )
                .animation(.easeOut(duration: 0.25), value: totalFraction)

            // White logged-progress ring on top.
            Capsule()
                .trim(from: 0, to: CGFloat(loggedFraction))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: Self.ringStroke, lineCap: .round)
                )
                .animation(.easeOut(duration: 0.25), value: loggedFraction)

            // Label centered in the pill.
            Text("\(total) / \(target)")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, BulkAITheme.Spacing.md)
        }
        .frame(height: Self.pillHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            stagedKcal > 0
                ? "Calories: \(consumed) logged plus \(stagedKcal) staged, of \(target) target"
                : "Calories \(consumed) of \(target)"
        )
    }

    private var utensilsPill: some View {
        Button {
            isPickingMealType = true
        } label: {
            Image(systemName: mealType?.icon ?? "fork.knife")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mealType == nil ? .white : BulkAITheme.Color.accent)
                .accessibilityHidden(true)
                .padding(.horizontal, BulkAITheme.Spacing.md)
                .frame(height: Self.pillHeight)
                .background(
                    Capsule().fill(BulkAITheme.Color.surface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mealType.map { "Meal type, \($0.displayName)" } ?? "Choose meal type")
    }

    /// Horizontal strip of staged-item emoji bubbles. Tapping the strip
    /// also opens the meal-type picker so the user keeps that affordance
    /// even when staged items push the utensils pill out.
    private var stagedItemsStrip: some View {
        Button {
            isPickingMealType = true
        } label: {
            HStack(spacing: -8) {
                ForEach(Array(visibleEmojis.enumerated()), id: \.offset) { _, emoji in
                    emojiBubble(emoji)
                }
                if overflowCount > 0 {
                    overflowBubble(count: overflowCount)
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.xs)
            .frame(height: Self.pillHeight)
            .background(
                Capsule().fill(BulkAITheme.Color.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stagedAccessibilityLabel)
    }

    private var visibleEmojis: [String] {
        Array(stagedEmojis.prefix(Self.maxVisibleEmojis))
    }

    private var overflowCount: Int {
        max(0, stagedEmojis.count - Self.maxVisibleEmojis)
    }

    private var stagedAccessibilityLabel: String {
        let count = stagedEmojis.count
        let suffix = count == 1 ? "" : "s"
        let mealSuffix = mealType.map { ", meal type \($0.displayName)" } ?? ""
        return "\(count) staged item\(suffix)\(mealSuffix). Tap to change meal type."
    }

    @ViewBuilder
    private func emojiBubble(_ emoji: String) -> some View {
        ZStack {
            Circle()
                .fill(BulkAITheme.Color.surfaceElevated)
                .frame(width: Self.emojiBubbleSize, height: Self.emojiBubbleSize)
                .overlay(
                    Circle()
                        .stroke(BulkAITheme.Color.surface, lineWidth: 2)
                )
            Text(emoji)
                .font(.system(size: 15))
        }
    }

    @ViewBuilder
    private func overflowBubble(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(BulkAITheme.Color.surfaceElevated)
                .frame(width: Self.emojiBubbleSize, height: Self.emojiBubbleSize)
                .overlay(
                    Circle()
                        .stroke(BulkAITheme.Color.surface, lineWidth: 2)
                )
            Text("+\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var collapseButton: some View {
        Button(action: onCollapse) {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
                .frame(width: Self.circleSize, height: Self.circleSize)
                .background(
                    Circle().fill(BulkAITheme.Color.surface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Collapse sheet")
    }

    // MARK: Sheets

    private var timePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Time",
                    selection: $time,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                Spacer()
            }
            .navigationTitle("Pick a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPickingTime = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var mealTypeDialogButtons: some View {
        ForEach(MealType.allCases, id: \.self) { type in
            Button(type.displayName) { mealType = type }
        }
        if mealType != nil {
            Button("Clear", role: .destructive) { mealType = nil }
        }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: Derived

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: time)
    }
}

// MARK: - Preview

#Preview("HeaderPillRow") {
    struct PreviewHost: View {
        @State private var time = Calendar.current.date(
            bySettingHour: 10, minute: 0, second: 0, of: .now
        ) ?? .now
        @State private var mealType: MealType? = nil

        var body: some View {
            VStack(spacing: BulkAITheme.Spacing.lg) {
                Text("Empty staged list").font(.caption).foregroundStyle(.white.opacity(0.5))
                HeaderPillRow(
                    time: $time,
                    consumed: 0,
                    target: 3414,
                    stagedKcal: 0,
                    stagedEmojis: [],
                    mealType: $mealType,
                    onClose: { },
                    onCollapse: { }
                )

                Text("Mid-day, no staged").font(.caption).foregroundStyle(.white.opacity(0.5))
                HeaderPillRow(
                    time: $time,
                    consumed: 1240,
                    target: 3414,
                    stagedKcal: 0,
                    stagedEmojis: [],
                    mealType: .constant(.breakfast),
                    onClose: { },
                    onCollapse: { }
                )

                Text("Mid-day, 3 staged").font(.caption).foregroundStyle(.white.opacity(0.5))
                HeaderPillRow(
                    time: $time,
                    consumed: 240,
                    target: 3414,
                    stagedKcal: 300,
                    stagedEmojis: ["\u{1F36B}", "\u{1F34B}", "\u{1F964}"],
                    mealType: .constant(.breakfast),
                    onClose: { },
                    onCollapse: { }
                )

                Text("Many staged → overflow").font(.caption).foregroundStyle(.white.opacity(0.5))
                HeaderPillRow(
                    time: $time,
                    consumed: 240,
                    target: 3414,
                    stagedKcal: 980,
                    stagedEmojis: ["\u{1F36B}", "\u{1F34B}", "\u{1F964}", "\u{1F357}", "\u{1F35E}", "\u{1F35B}"],
                    mealType: .constant(.lunch),
                    onClose: { },
                    onCollapse: { }
                )

                Text("Full target").font(.caption).foregroundStyle(.white.opacity(0.5))
                HeaderPillRow(
                    time: $time,
                    consumed: 3414,
                    target: 3414,
                    stagedKcal: 0,
                    stagedEmojis: [],
                    mealType: .constant(.dinner),
                    onClose: { },
                    onCollapse: { }
                )

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BulkAITheme.Color.background)
        }
    }

    return PreviewHost()
}
