import SwiftUI

/// Dashboard General section — header + Steps card.
///
/// Currently houses only the Steps card. Future activity tiles (active energy,
/// sleep, etc.) can sit below this card without changing the API; the parent
/// would just compose another section. Matches IMG_6462 / IMG_6463 in
/// `~/Downloads/macrofactor-screens/`.
struct GeneralSection: View {

    /// Last 7 days of step counts in chronological order (oldest -> newest).
    /// Empty array renders a flat row of muted bars rather than crashing.
    let stepsHistory: [Int]

    /// Display string for the current day's step total, e.g. "2800 steps".
    /// String is owned by the caller so unit/formatting decisions stay in one
    /// place across the dashboard.
    let stepsValue: String

    let onStepsTap: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            header

            stepsCard
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("General")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button(action: onSeeAll) {
                Text("See All")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all general activity")
        }
    }

    // MARK: Steps card

    private var stepsCard: some View {
        Button(action: onStepsTap) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
                    Text("Steps")
                        .font(BulkAITheme.Typography.headline)
                        .foregroundStyle(.white)
                    Text("Last 7 Days")
                        .font(BulkAITheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                StepsBarChart(values: stepsHistory)
                    .frame(height: 64)
                    .padding(.top, BulkAITheme.Spacing.xxs)

                // Hairline divider above the value row, mirroring the macro
                // tiles so the dashboard reads as one design system.
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 0.5)

                bottomRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Steps, \(stepsValue)")
    }

    private var bottomRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: BulkAITheme.Spacing.xs) {
            // Steps total — caller passes the full string ("2800 steps").
            // We split off the leading numeric part for emphasis only when
            // the string parses cleanly; otherwise we render as-is.
            stepsValueLabel
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    /// Renders the steps value with a large numeric prefix and a soft unit
    /// suffix when the string is shaped like "1234 word"; otherwise falls
    /// back to plain text so unusual locales (e.g. "1.234 schritte") still
    /// display correctly.
    @ViewBuilder
    private var stepsValueLabel: some View {
        if let split = Self.splitNumeric(stepsValue) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(split.numeric)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(split.remainder)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        } else {
            Text(stepsValue)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    /// Splits a string like "2800 steps" into ("2800", "steps"). Returns nil
    /// when the value does not start with digits/grouping characters, in which
    /// case the caller renders the string unchanged.
    private static func splitNumeric(_ value: String) -> (numeric: String, remainder: String)? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let numericChars = CharacterSet(charactersIn: "0123456789.,")
        var splitIndex = trimmed.startIndex
        for index in trimmed.indices {
            if trimmed[index].unicodeScalars.allSatisfy({ numericChars.contains($0) }) {
                splitIndex = trimmed.index(after: index)
            } else {
                break
            }
        }
        let numericPart = String(trimmed[..<splitIndex])
        guard !numericPart.isEmpty, numericPart != trimmed else { return nil }
        let remainderPart = String(trimmed[splitIndex...]).trimmingCharacters(in: .whitespaces)
        guard !remainderPart.isEmpty else { return nil }
        return (numericPart, remainderPart)
    }
}

// MARK: - StepsBarChart

/// 7 vertical bars rendered with `Rectangle()` per Phase B's note that Swift
/// Charts with conditional marks does not compile under Xcode 16.4. Bars use
/// the activity coral-orange accent; height scales proportionally to the
/// maximum value in the supplied window, with a small minimum so zero-step
/// days are still visible as a stub.
private struct StepsBarChart: View {

    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let displayedValues = Self.padded(values, to: 7)
            let maxValue = max(displayedValues.max() ?? 1, 1)
            let barCount = displayedValues.count
            let spacing: CGFloat = 6
            let totalSpacing = spacing * CGFloat(max(barCount - 1, 0))
            let barWidth = max((proxy.size.width - totalSpacing) / CGFloat(barCount), 4)
            let minHeight: CGFloat = 4

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(displayedValues.enumerated()), id: \.offset) { _, value in
                    let ratio = CGFloat(value) / CGFloat(maxValue)
                    let height = max(proxy.size.height * ratio, minHeight)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(BulkAITheme.Color.activity)
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            .overlay(alignment: .bottom) {
                // Baseline hairline so the bars sit on a visible rule, matching
                // the screenshot's faint horizontal axis.
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steps history, last 7 days")
    }

    /// Pads or truncates the input to exactly `count` entries. Padding values
    /// are zero so an empty array renders a row of minimum-height stubs
    /// instead of crashing the geometry math.
    private static func padded(_ values: [Int], to count: Int) -> [Int] {
        if values.count == count { return values }
        if values.count > count { return Array(values.suffix(count)) }
        return values + Array(repeating: 0, count: count - values.count)
    }
}

#Preview("GeneralSection") {
    ScrollView {
        GeneralSection(
            stepsHistory: [3200, 2100, 4500, 1800, 2800, 3600, 2400],
            stepsValue: "2800 steps",
            onStepsTap: {},
            onSeeAll: {}
        )
        .padding(BulkAITheme.Spacing.md)

        GeneralSection(
            stepsHistory: [],
            stepsValue: "0 steps",
            onStepsTap: {},
            onSeeAll: {}
        )
        .padding(BulkAITheme.Spacing.md)
    }
    .background(BulkAITheme.Color.background)
}
