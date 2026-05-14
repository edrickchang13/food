import SwiftUI

/// The five-pill header row at the top of MacroFactor's Food Entry sheet.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6466.PNG`.
///
/// Layout, left to right:
///   1. Circular X close button
///   2. Time pill ("9 AM"-style label, tappable to pick a different hour)
///   3. Calorie progress pill (small ring around a "consumed / target" label)
///   4. Utensils pill (toggles the active meal type; tinted when one is set)
///   5. Down-chevron pill (collapse the sheet)
///
/// Each pill sits on `BulkAITheme.Color.surface` and shares the same height so
/// the row reads as a single segmented control. Tap targets are at least 44pt
/// so the row stays comfortable to thumb-press from the bottom sheet.
struct HeaderPillRow: View {

    // MARK: State

    @Binding var time: Date
    let consumed: Int
    let target: Int
    @Binding var mealType: MealType?
    let onClose: () -> Void
    let onCollapse: () -> Void

    @State private var isPickingTime = false
    @State private var isPickingMealType = false

    // MARK: Layout constants

    private static let pillHeight: CGFloat = 44
    private static let circleSize: CGFloat = 44

    // MARK: Body

    var body: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            closeButton
            timePill
            caloriePill
            utensilsPill
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

    private var caloriePill: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            ProgressRing(progress: progressFraction)
                .frame(width: 16, height: 16)

            Text("\(consumed) / \(target)")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .frame(height: Self.pillHeight)
        .background(
            Capsule().fill(BulkAITheme.Color.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calories consumed \(consumed) of \(target)")
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

    private var progressFraction: Double {
        guard target > 0 else { return 0 }
        let raw = Double(consumed) / Double(target)
        return min(max(raw, 0), 1)
    }
}

// MARK: - ProgressRing

/// Tiny circular progress ring used inside the calorie pill. Drawn by hand so
/// it composes inline with the text without dragging in a heavier component.
private struct ProgressRing: View {

    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    BulkAITheme.Color.accent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: progress)
        }
    }
}

// MARK: - Preview

#Preview("HeaderPillRow") {
    struct PreviewHost: View {
        @State private var time = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: .now
        ) ?? .now
        @State private var mealType: MealType? = nil

        var body: some View {
            VStack(spacing: BulkAITheme.Spacing.lg) {
                HeaderPillRow(
                    time: $time,
                    consumed: 0,
                    target: 3415,
                    mealType: $mealType,
                    onClose: { },
                    onCollapse: { }
                )

                HeaderPillRow(
                    time: $time,
                    consumed: 1240,
                    target: 3415,
                    mealType: .constant(.breakfast),
                    onClose: { },
                    onCollapse: { }
                )

                HeaderPillRow(
                    time: $time,
                    consumed: 3415,
                    target: 3415,
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
