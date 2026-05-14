import SwiftUI

/// Floating dashboard search bar.
///
/// A pill-shaped, blurred-material bar designed to float above the custom tab
/// bar at the bottom of the dashboard. Matches IMG_6463 in
/// `~/Downloads/macrofactor-screens/`:
///
/// - Leading: magnifying glass icon + editable placeholder text.
/// - Trailing inside the pill: barcode scanner button.
/// - Outside the pill, on the right: a circular accent-colored sparkles button
///   that opens the AI flow.
///
/// The view is positioning-agnostic — the parent decides how to overlay it
/// (typically using `.safeAreaInset(edge: .bottom)` or an overlay aligned to
/// the bottom). It only owns its own size and styling.
struct DashboardSearchBar: View {

    @Binding var query: String
    let onBarcodeTap: () -> Void
    let onAITap: () -> Void
    var placeholder: String = "Search for a food"

    var body: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            searchPill

            aiButton
        }
        // Side margin so the bar reads as floating rather than edge-to-edge.
        .padding(.horizontal, BulkAITheme.Spacing.md)
        // Bottom padding tuned to give roughly 8pt of visual gap above the
        // custom tab bar when the parent uses `.safeAreaInset` to host it.
        .padding(.bottom, BulkAITheme.Spacing.xs)
        .padding(.top, BulkAITheme.Spacing.xs)
    }

    // MARK: Search pill

    private var searchPill: some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            TextField(
                "",
                text: $query,
                prompt: Text(placeholder)
                    .foregroundStyle(.white.opacity(0.45))
            )
            .font(BulkAITheme.Typography.body)
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)

            Button(action: onBarcodeTap) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan barcode")
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            // ultraThinMaterial gives the floating-glass treatment over both
            // the dashboard scroll content and the custom tab bar.
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
    }

    // MARK: AI button

    private var aiButton: some View {
        Button(action: onAITap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BulkAITheme.Color.accent)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Bulk AI")
    }
}

#Preview("DashboardSearchBar") {
    struct PreviewHost: View {
        @State private var query: String = ""
        @State private var queryFilled: String = "chicken breast"

        var body: some View {
            ZStack(alignment: .bottom) {
                BulkAITheme.Color.background
                    .ignoresSafeArea()

                // Mock content behind the bar so the material blur has
                // something interesting to render against.
                VStack(spacing: BulkAITheme.Spacing.md) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                            .fill(BulkAITheme.Color.surface)
                            .frame(height: 64)
                    }
                }
                .padding(BulkAITheme.Spacing.md)

                VStack(spacing: BulkAITheme.Spacing.md) {
                    DashboardSearchBar(
                        query: .constant(""),
                        onBarcodeTap: {},
                        onAITap: {}
                    )

                    DashboardSearchBar(
                        query: .constant("chicken breast"),
                        onBarcodeTap: {},
                        onAITap: {}
                    )
                }
                .padding(.bottom, BulkAITheme.Spacing.lg)
            }
        }
    }

    return PreviewHost()
}
