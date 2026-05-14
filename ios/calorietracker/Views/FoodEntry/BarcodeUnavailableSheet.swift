import SwiftUI

/// Half-sheet placeholder shown when the user captures an image in Barcode mode.
///
/// Barcode scanning is a future phase — this sheet surfaces that clearly and
/// offers two escape hatches: jump to the Search tab or switch to Label mode,
/// which is available today.
///
/// Layout (top to bottom inside a dark `ZStack`):
/// 1. Close button (top-left, circular, surface-elevated background)
/// 2. `barcode.viewfinder` SF symbol (large, dimmed)
/// 3. Title — "Barcode scanning is coming soon"
/// 4. Body copy — explains what to do instead
/// 5. Two CTA pills — "Search manually" (primary) + "Try label scan" (secondary)
struct BarcodeUnavailableSheet: View {

    /// Called when the user taps "Search manually".
    let onSearchManually: () -> Void

    /// Called when the user taps "Try label scan".
    let onTryLabel: () -> Void

    /// Called when the user taps the X close button.
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            BulkAITheme.Color.background
                .ignoresSafeArea()

            closeButton
                .padding(.top, BulkAITheme.Spacing.md)
                .padding(.leading, BulkAITheme.Spacing.md)

            VStack(spacing: 0) {
                Spacer()

                iconSection

                Spacer()

                ctaStack
                    .padding(.horizontal, BulkAITheme.Spacing.md)
                    .padding(.bottom, BulkAITheme.Spacing.xxl)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(BulkAITheme.Color.surfaceElevated))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Icon + copy

    private var iconSection: some View {
        VStack(spacing: BulkAITheme.Spacing.lg) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: BulkAITheme.Spacing.sm) {
                Text("Barcode scanning is coming soon")
                    .font(BulkAITheme.Typography.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Bulk AI doesn't scan barcodes yet. Tap Search manually to look the item up by name in the food database, or try the Label mode to scan a nutrition facts label instead.")
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BulkAITheme.Spacing.lg)
            }
        }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: BulkAITheme.Spacing.sm) {
            Button(action: onSearchManually) {
                Text("Search manually")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)

            Button(action: onTryLabel) {
                Text("Try label scan")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(BulkAITheme.Color.surfaceElevated))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("BarcodeUnavailableSheet") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            BarcodeUnavailableSheet(
                onSearchManually: {},
                onTryLabel: {},
                onClose: {}
            )
        }
}
