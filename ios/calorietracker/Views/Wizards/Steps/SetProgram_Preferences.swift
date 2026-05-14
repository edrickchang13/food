import SwiftUI

// MARK: - SetProgram_Preferences

/// Step 1 of the Set Program wizard — 2-column preference grid.
///
/// Reference: `~/Downloads/macrofactor-screens/IMG_6479.PNG`
///
/// Renders six `ProgramPreference` cards in a `LazyVGrid`. Each card shows an
/// SF Symbol icon, a bold title, and a one-line subtitle. The selected card is
/// highlighted with an accent border.
struct SetProgram_Preferences: View {

    @Binding var selection: ProgramPreference

    // MARK: - Layout

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm),
        GridItem(.flexible(), spacing: BulkAITheme.Spacing.sm)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
                header
                preferenceGrid
            }
            .padding(.horizontal, BulkAITheme.Spacing.lg)
            .padding(.top, BulkAITheme.Spacing.lg)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("Pick a program style")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(.white)
            Text("Each style trades different priorities. You can change this later.")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Grid

    private var preferenceGrid: some View {
        LazyVGrid(columns: columns, spacing: BulkAITheme.Spacing.sm) {
            ForEach(ProgramPreference.allCases) { preference in
                preferenceCard(preference)
            }
        }
    }

    // MARK: - Card

    private func preferenceCard(_ preference: ProgramPreference) -> some View {
        let isSelected = selection == preference
        return Button {
            selection = preference
        } label: {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                Image(systemName: preference.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isSelected
                        ? BulkAITheme.Color.accent
                        : BulkAITheme.Color.macroCarbs
                    )
                    .accessibilityHidden(true)

                Text(preference.displayName)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)

                Text(preference.subtitle)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BulkAITheme.Spacing.md)
            .background(BulkAITheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? BulkAITheme.Color.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preference.displayName), \(preference.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("SetProgram_Preferences – none selected") {
    struct Wrapper: View {
        @State var selection: ProgramPreference = .coached
        var body: some View {
            SetProgram_Preferences(selection: $selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BulkAITheme.Color.background)
        }
    }
    return Wrapper()
        .preferredColorScheme(.dark)
}

#Preview("SetProgram_Preferences – balanced selected") {
    struct Wrapper: View {
        @State var selection: ProgramPreference = .balanced
        var body: some View {
            SetProgram_Preferences(selection: $selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BulkAITheme.Color.background)
        }
    }
    return Wrapper()
        .preferredColorScheme(.dark)
}
