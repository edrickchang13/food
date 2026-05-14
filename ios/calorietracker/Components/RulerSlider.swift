import SwiftUI

/// A horizontal ruler-style tick scrubber for fine numeric selection.
///
/// Used by the Edit Goal weight picker. Renders a fixed window of ticks
/// (roughly 21) with the current value's tick centered, snapping to `step`.
/// Major ticks (every `majorTickEvery` step) are taller and labeled. The
/// current-value tick is rendered in `accent`. A drag gesture updates the
/// binding continuously while the user is dragging, not just on release.
struct RulerSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1.0
    var majorTickEvery: Int = 10
    var accent: Color = BulkAITheme.Color.macroCarbs
    var unit: String = ""

    // Visual constants
    private let visibleTicks: Int = 21
    private let rulerHeight: CGFloat = 64
    private let minorTickHeight: CGFloat = 14
    private let majorTickHeight: CGFloat = 24
    private let centerTickHeight: CGFloat = 36
    private let tickWidth: CGFloat = 2
    private let tickLabelFont: Font = .system(size: 11, weight: .medium, design: .rounded)

    // Drag tracking
    @State private var dragAnchorValue: Double? = nil

    private var clampedValue: Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var snappedValue: Double {
        snap(clampedValue)
    }

    private var displayValue: String {
        String(format: "%.1f", snappedValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            valueReadout

            GeometryReader { proxy in
                let spacing = proxy.size.width / CGFloat(visibleTicks - 1)
                ZStack {
                    tickRow(spacing: spacing, in: proxy.size)
                    centerIndicator
                }
                .frame(width: proxy.size.width, height: rulerHeight, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            updateValue(translation: gesture.translation.width, spacing: spacing)
                        }
                        .onEnded { _ in
                            dragAnchorValue = nil
                            value = snappedValue
                        }
                )
            }
            .frame(height: rulerHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(unit.isEmpty ? "Value" : "Value in \(unit)"))
        .accessibilityValue(Text(displayValue))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = snap(min(snappedValue + step, range.upperBound))
            case .decrement:
                value = snap(max(snappedValue - step, range.lowerBound))
            @unknown default:
                break
            }
        }
    }

    // MARK: - Subviews

    private var valueReadout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(displayValue)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tickRow(spacing: CGFloat, in size: CGSize) -> some View {
        let centerStepIndex = stepIndex(for: snappedValue)
        let half = visibleTicks / 2

        return ZStack {
            ForEach(-half...half, id: \.self) { offset in
                let tickStepIndex = centerStepIndex + offset
                if let tickValue = value(forStepIndex: tickStepIndex) {
                    tickMark(
                        for: tickValue,
                        isCenter: offset == 0,
                        xPosition: size.width / 2 + CGFloat(offset) * spacing,
                        rulerHeight: size.height
                    )
                }
            }
        }
    }

    private func tickMark(
        for tickValue: Double,
        isCenter: Bool,
        xPosition: CGFloat,
        rulerHeight: CGFloat
    ) -> some View {
        let isMajor = isMajorTick(value: tickValue)
        let height: CGFloat = isCenter ? centerTickHeight : (isMajor ? majorTickHeight : minorTickHeight)
        let color: Color = isCenter ? accent : (isMajor ? Color.white.opacity(0.75) : Color.white.opacity(0.35))

        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: tickWidth / 2)
                .fill(color)
                .frame(width: tickWidth, height: height)

            if isMajor {
                Text(majorTickLabel(for: tickValue))
                    .font(tickLabelFont)
                    .foregroundStyle(isCenter ? accent : Color.white.opacity(0.7))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Spacer(minLength: 0)
                    .frame(height: 14)
            }
        }
        .frame(width: 40, height: rulerHeight, alignment: .top)
        .position(x: xPosition, y: rulerHeight / 2)
    }

    private var centerIndicator: some View {
        // Subtle vertical guideline behind the highlighted center tick to
        // emphasise it like MacroFactor's reference. Kept low-contrast so the
        // ruler stays the focal point.
        Rectangle()
            .fill(accent.opacity(0.12))
            .frame(width: 28, height: rulerHeight)
            .cornerRadius(8)
            .allowsHitTesting(false)
    }

    // MARK: - Math helpers

    private func snap(_ raw: Double) -> Double {
        guard step > 0 else { return raw }
        let lower = range.lowerBound
        let snapped = (raw - lower) / step
        let rounded = (snapped).rounded()
        let candidate = lower + rounded * step
        return min(max(candidate, range.lowerBound), range.upperBound)
    }

    private func stepIndex(for v: Double) -> Int {
        guard step > 0 else { return 0 }
        return Int(((v - range.lowerBound) / step).rounded())
    }

    private func value(forStepIndex index: Int) -> Double? {
        let candidate = range.lowerBound + Double(index) * step
        guard candidate >= range.lowerBound, candidate <= range.upperBound else {
            return nil
        }
        return candidate
    }

    private func isMajorTick(value v: Double) -> Bool {
        guard step > 0, majorTickEvery > 0 else { return false }
        let index = Int(((v - range.lowerBound) / step).rounded())
        return index % majorTickEvery == 0
    }

    private func majorTickLabel(for v: Double) -> String {
        // Drop the trailing ".0" for whole-step major ticks to match the
        // reference screenshot's clean numerals.
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(v))
        }
        return String(format: "%.1f", v)
    }

    private func updateValue(translation: CGFloat, spacing: CGFloat) {
        guard spacing > 0 else { return }
        let anchor = dragAnchorValue ?? snappedValue
        if dragAnchorValue == nil {
            dragAnchorValue = anchor
        }

        // Dragging right reveals smaller tick values (ruler moves with the
        // finger), so a positive translation should decrease the value.
        let stepsDelta = -translation / spacing
        let raw = anchor + Double(stepsDelta) * step
        let snapped = snap(raw)
        if snapped != value {
            value = snapped
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var weight: Double = 190.0
        @State private var bodyFat: Double = 50.0

        var body: some View {
            VStack(spacing: 32) {
                RulerSlider(
                    value: $weight,
                    range: 150.0...250.0,
                    step: 0.5,
                    majorTickEvery: 10,
                    unit: "lbs"
                )

                RulerSlider(
                    value: $bodyFat,
                    range: 0.0...100.0,
                    step: 1.0,
                    majorTickEvery: 10,
                    accent: BulkAITheme.Color.macroProtein,
                    unit: "%"
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BulkAITheme.Color.background)
        }
    }

    return PreviewHost()
        .preferredColorScheme(.dark)
}
