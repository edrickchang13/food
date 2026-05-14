import SwiftUI

/// A card row that shows an old-to-new value diff, used on the Edit Goal
/// review screen (`~/Downloads/macrofactor-screens/IMG_6477.PNG`).
///
/// When the value has changed, the right side reads `currentValue ›› newValue`
/// using a doubled chevron and the card takes on a faint green tint. When
/// unchanged, the right side renders "No Change" in a muted gray. An optional
/// `note` paragraph is rendered below the row to explain the rationale.
///
/// The card depends on `Theme/Surface.swift`'s `.surfaceCard()` modifier
/// (Agent 1's file in this phase). If the modifier is missing at build time
/// the surrounding `VStack` still lays out correctly; the styling is what's
/// missing.
struct DiffRowCard: View {

    let label: String
    let currentValue: String
    let newValue: String
    let note: String?

    init(
        label: String,
        currentValue: String,
        newValue: String,
        note: String? = nil
    ) {
        self.label = label
        self.currentValue = currentValue
        self.newValue = newValue
        self.note = note
    }

    private var hasChanged: Bool {
        currentValue != newValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: BulkAITheme.Spacing.sm) {
                Text(label)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: BulkAITheme.Spacing.sm)
                diffValue
            }

            if let note, !note.isEmpty {
                Text(note)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BulkAITheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var diffValue: some View {
        if hasChanged {
            HStack(spacing: BulkAITheme.Spacing.xs) {
                Text(currentValue)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                Text(">>")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    // Suppress the raw ">>" characters; the containing VStack
                    // already carries a combined label via .accessibilityElement.
                    .accessibilityHidden(true)
                Text(newValue)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(currentValue), changed to \(newValue)")
        } else {
            Text("No Change")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if hasChanged {
            ZStack {
                BulkAITheme.Color.surface
                BulkAITheme.Color.macroCarbs.opacity(0.06)
            }
        } else {
            BulkAITheme.Color.surface
        }
    }
}

#Preview("Edit Goal diffs") {
    ScrollView {
        VStack(spacing: BulkAITheme.Spacing.md) {
            DiffRowCard(
                label: "Weight Gain",
                currentValue: "175 lbs",
                newValue: "190 lbs",
                note: "Your target weight has been updated. We will re-plan your weekly check-ins around the new goal."
            )

            DiffRowCard(
                label: "Start Date",
                currentValue: "May 6, 2025",
                newValue: "May 6, 2025"
            )
        }
        .padding(BulkAITheme.Spacing.lg)
    }
    .background(BulkAITheme.Color.background)
}
