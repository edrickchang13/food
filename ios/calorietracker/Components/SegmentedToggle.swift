import SwiftUI

/// A compact two-option pill toggle, modeled on MacroFactor's
/// "Consumed / Remaining" switch (`~/Downloads/macrofactor-screens/IMG_6459.PNG`).
///
/// Selected option is a white-filled pill with black text; unselected is just
/// muted text on a dark capsule track. The pill animates between the two
/// slots via `matchedGeometryEffect` whenever the binding changes. The track
/// is intentionally narrow (caps at ~200pt) so this works inline within a
/// card or under a chart legend.
struct SegmentedToggle: View {

    let options: (String, String)
    @Binding var selection: Int
    let accent: Color

    @Namespace private var pillNamespace

    init(
        options: (String, String),
        selection: Binding<Int>,
        accent: Color = BulkAITheme.Color.accent
    ) {
        self.options = options
        self._selection = selection
        self.accent = accent
    }

    var body: some View {
        HStack(spacing: 0) {
            segment(label: options.0, index: 0)
            segment(label: options.1, index: 1)
        }
        .padding(BulkAITheme.Spacing.xxs)
        .background(
            Capsule().fill(BulkAITheme.Color.surfaceElevated)
        )
        .frame(maxWidth: 200)
    }

    private func segment(label: String, index: Int) -> some View {
        let isSelected = index == selection
        return Button {
            withAnimation(.snappy) {
                selection = index
            }
        } label: {
            Text(label)
                .font(BulkAITheme.Typography.body)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, BulkAITheme.Spacing.xs)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "segment", in: pillNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SegmentedTogglePreviewHarness: View {
    @State private var first: Int = 0
    @State private var second: Int = 1

    var body: some View {
        VStack(spacing: BulkAITheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                Text("Consumed selected")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                SegmentedToggle(
                    options: ("Consumed", "Remaining"),
                    selection: $first
                )
            }

            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                Text("Remaining selected")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                SegmentedToggle(
                    options: ("Consumed", "Remaining"),
                    selection: $second
                )
            }
        }
        .padding(BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("SegmentedToggle") {
    SegmentedTogglePreviewHarness()
}
