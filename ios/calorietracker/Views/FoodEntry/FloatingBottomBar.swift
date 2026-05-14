import SwiftUI

/// The persistent bottom bar that sits across every tab inside the Food Entry
/// sheet. Reference: `~/Downloads/macrofactor-screens/IMG_6470.PNG`.
///
/// Left side is a small inline search field (magnifying-glass + TextField) used
/// to filter the current tab's list. The center divider visually separates the
/// filter from the action. The right side is the "Log Foods" CTA, drawn as a
/// solid white pill with black text so it pops on the dark background.
///
/// The bar uses `.ultraThinMaterial` so the underlying content remains lightly
/// visible while keeping enough contrast for the white pill. The whole bar is
/// rounded and shadowed; the parent decides where to anchor it.
struct FloatingBottomBar: View {

    // MARK: API

    @Binding var filterQuery: String
    let logCount: Int
    let onLog: () -> Void
    var placeholder: String = "Filter foods"

    // MARK: Focus

    @FocusState private var isFilterFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: Layout constants

    private static let barHeight: CGFloat = 52
    private static let buttonHeight: CGFloat = 40

    // MARK: Body

    var body: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            filterField

            Divider()
                .frame(height: 24)
                .overlay(Color.white.opacity(0.12))

            logButton
        }
        .padding(.horizontal, BulkAITheme.Spacing.sm)
        .frame(height: Self.barHeight)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                // When Reduce Transparency is on, materials become opaque but
                // the resulting surface color can lose contrast. Fall back to
                // a fully opaque surface token so text targets stay legible.
                .fill(reduceTransparency
                    ? AnyShapeStyle(BulkAITheme.Color.surfaceElevated)
                    : AnyShapeStyle(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        .padding(.horizontal, BulkAITheme.Spacing.md)
    }

    // MARK: Pieces

    private var filterField: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            TextField(
                "",
                text: $filterQuery,
                prompt: Text(placeholder)
                    .foregroundStyle(.white.opacity(0.45))
            )
            .focused($isFilterFocused)
            .font(BulkAITheme.Typography.body)
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
        }
        .padding(.horizontal, BulkAITheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
        .contentShape(Rectangle())
        .onTapGesture { isFilterFocused = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
    }

    private var logButton: some View {
        Button(action: onLog) {
            Text(buttonTitle)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, BulkAITheme.Spacing.md)
                .frame(minWidth: 96, minHeight: Self.buttonHeight)
                .background(
                    Capsule().fill(Color.white)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(buttonTitle)
    }

    // MARK: Derived

    private var buttonTitle: String {
        guard logCount > 0 else { return "Log Foods" }
        return "Log \(logCount) \(logCount == 1 ? "Food" : "Foods")"
    }
}

// MARK: - Preview

#Preview("FloatingBottomBar") {
    struct PreviewHost: View {
        @State private var emptyQuery: String = ""
        @State private var typedQuery: String = "chicken"
        @State private var singleQuery: String = ""

        var body: some View {
            ZStack {
                BulkAITheme.Color.background.ignoresSafeArea()

                VStack(spacing: BulkAITheme.Spacing.xl) {
                    Spacer()

                    VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                        Text("logCount = 0")
                            .font(BulkAITheme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        FloatingBottomBar(
                            filterQuery: $emptyQuery,
                            logCount: 0,
                            onLog: { }
                        )
                    }

                    VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                        Text("logCount = 1")
                            .font(BulkAITheme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        FloatingBottomBar(
                            filterQuery: $singleQuery,
                            logCount: 1,
                            onLog: { },
                            placeholder: "Search for a food"
                        )
                    }

                    VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                        Text("logCount = 3 with query")
                            .font(BulkAITheme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        FloatingBottomBar(
                            filterQuery: $typedQuery,
                            logCount: 3,
                            onLog: { }
                        )
                    }
                }
                .padding(.bottom, BulkAITheme.Spacing.xl)
            }
        }
    }

    return PreviewHost()
}
