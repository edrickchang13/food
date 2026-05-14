import SwiftUI

/// A horizontally scrollable row of action pills for the Strategy screen.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6473.PNG` — the five pills
/// appear near the top of the screen beneath the navigation title and scroll
/// off the trailing edge. Each pill invokes a callback so the parent can push
/// the appropriate navigation destination.
///
/// The scroll indicator is hidden per the Strategy screen phase brief.
struct ActionPillCarousel: View {

    // MARK: Callbacks

    let onNewGoal: () -> Void
    let onEditGoal: () -> Void
    let onNewProgram: () -> Void
    let onEditProgram: () -> Void
    let onChangeCheckInDay: () -> Void

    // MARK: Data

    private struct PillConfig {
        let label: String
        let icon: String
    }

    private var pills: [(config: PillConfig, action: () -> Void)] {
        [
            (PillConfig(label: "New Goal",            icon: "target"),                       onNewGoal),
            (PillConfig(label: "Edit Goal",           icon: "pencil.circle"),                onEditGoal),
            (PillConfig(label: "New Program",         icon: "plus.rectangle.on.rectangle"), onNewProgram),
            (PillConfig(label: "Edit Program",        icon: "slider.horizontal.3"),          onEditProgram),
            (PillConfig(label: "Change Check-In Day", icon: "calendar"),                     onChangeCheckInDay),
        ]
    }

    // MARK: Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BulkAITheme.Spacing.sm) {
                ForEach(Array(pills.enumerated()), id: \.offset) { _, item in
                    pill(config: item.config, action: item.action)
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.md)
        }
    }

    // MARK: Pill

    private func pill(config: PillConfig, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BulkAITheme.Spacing.xs) {
                Image(systemName: config.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text(config.label)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.vertical, BulkAITheme.Spacing.sm)
            .background(
                Capsule().fill(BulkAITheme.Color.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(config.label)
    }
}

// MARK: - Preview

#Preview("ActionPillCarousel") {
    ActionPillCarousel(
        onNewGoal:          { },
        onEditGoal:         { },
        onNewProgram:       { },
        onEditProgram:      { },
        onChangeCheckInDay: { }
    )
    .padding(.vertical, BulkAITheme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
