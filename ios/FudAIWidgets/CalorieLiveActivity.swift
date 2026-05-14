import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity palette
// Scoped to this file only — do NOT add to WidgetPalette (CalorieWidgetViews.swift).
// Same accent as EnergyBalanceWidgetViews.swift (#4C9AFF) to keep the island on-brand.
fileprivate let liveActivityAccent = Color(
    red: 0x4C / 255.0, green: 0x9A / 255.0, blue: 0xFF / 255.0  // #4C9AFF
)
fileprivate let liveActivityBackground = Color(
    red: 0x0F / 255.0, green: 0x0F / 255.0, blue: 0x10 / 255.0  // #0F0F10
)

// MARK: - Widget configuration

struct CalorieLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalorieActivityAttributes.self) { context in
            // Lock screen / notification banner view
            lockScreenView(state: context.state)
                .activityBackgroundTint(liveActivityBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded form — appears when the user long-presses the island.
                DynamicIslandExpandedRegion(.leading) {
                    expandedRing(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedMacros(state: context.state)
                }
            } compactLeading: {
                compactRing(state: context.state)
            } compactTrailing: {
                Text("\(context.state.calories)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } minimal: {
                compactRing(state: context.state)
            }
            .keylineTint(liveActivityAccent)
        }
    }

    // MARK: - Lock screen / banner

    private func lockScreenView(state: CalorieActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: calorieProgress(state))
                    .stroke(liveActivityAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(state.calories)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("/ \(state.calorieGoal)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1.0)
                Text("\(state.protein) / \(state.proteinGoal) g protein")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("Updated \(state.updatedAt, style: .time)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Dynamic Island pieces

    private func compactRing(state: CalorieActivityAttributes.ContentState) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: calorieProgress(state))
                .stroke(liveActivityAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }

    @ViewBuilder
    private func expandedRing(state: CalorieActivityAttributes.ContentState) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: calorieProgress(state))
                .stroke(liveActivityAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(state.calories)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("/ \(state.calorieGoal)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .frame(width: 50, height: 50)
    }

    @ViewBuilder
    private func expandedMacros(state: CalorieActivityAttributes.ContentState) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Protein")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(0.8)
            Text("\(state.protein) / \(state.proteinGoal) g")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Helpers

    private func calorieProgress(_ state: CalorieActivityAttributes.ContentState) -> CGFloat {
        guard state.calorieGoal > 0 else { return 0 }
        return min(1, CGFloat(state.calories) / CGFloat(state.calorieGoal))
    }
}
