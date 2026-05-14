import SwiftUI

/// The half-height bottom sheet that replaces the generic Quick Add sheet
/// when the center FAB is tapped from the Food Log tab. Mirrors
/// `~/Downloads/macrofactor-screens/IMG_6472.PNG`:
///
/// - Grab handle at the top
/// - Header row: "X" close on the left, "Shortcuts" title centered,
///   sliders-icon configure button on the right
/// - A row of four evenly spaced circular icon buttons (AI / Weight /
///   Search / Barcode)
/// - A vertical list of four `.surfaceCard()` rows with leading SF Symbol
///   icon and trailing chevron (Your Foods / Quick Add / Metrics / Recipes)
///
/// All actions are passed in explicitly so this view is presentation-only;
/// `FoodLogView` owns the routing decisions for each tap.
struct ShortcutsSheet: View {
    let onAITap: () -> Void
    let onWeightTap: () -> Void
    let onSearchTap: () -> Void
    let onBarcodeTap: () -> Void
    let onYourFoods: () -> Void
    let onQuickAdd: () -> Void
    let onMetrics: () -> Void
    let onRecipes: () -> Void
    let onClose: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            grabHandle
            header
            Divider()
                .background(BulkAITheme.Color.surfaceElevated)
                .padding(.bottom, BulkAITheme.Spacing.lg)

            circularButtonRow
                .padding(.horizontal, BulkAITheme.Spacing.lg)
                .padding(.bottom, BulkAITheme.Spacing.xl)

            listRows
                .padding(.horizontal, BulkAITheme.Spacing.md)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(BulkAITheme.Color.background)
    }

    // MARK: - Header

    private var grabHandle: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .padding(.top, BulkAITheme.Spacing.sm)
            .padding(.bottom, BulkAITheme.Spacing.md)
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Text("Shortcuts")
                .font(BulkAITheme.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onConfigure) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configure shortcuts")
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.bottom, BulkAITheme.Spacing.md)
    }

    // MARK: - Circular icon row

    private var circularButtonRow: some View {
        HStack(spacing: 0) {
            iconButton(symbol: "sparkles", label: "AI", action: onAITap)
            Spacer(minLength: 0)
            iconButton(symbol: "scalemass.fill", label: "Weight", action: onWeightTap)
            Spacer(minLength: 0)
            iconButton(symbol: "magnifyingglass", label: "Search", action: onSearchTap)
            Spacer(minLength: 0)
            iconButton(symbol: "barcode.viewfinder", label: "Barcode", action: onBarcodeTap)
        }
    }

    private func iconButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: BulkAITheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(BulkAITheme.Color.surfaceElevated)
                        .frame(width: 56, height: 56)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Vertical list rows

    private var listRows: some View {
        VStack(spacing: BulkAITheme.Spacing.xs) {
            listRow(symbol: "fork.knife", title: "Your Foods", action: onYourFoods)
            listRow(symbol: "bolt.fill", title: "Quick Add", action: onQuickAdd)
            listRow(symbol: "ruler", title: "Metrics", action: onMetrics)
            listRow(symbol: "book.closed", title: "Recipes", action: onRecipes)
        }
    }

    private func listRow(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BulkAITheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, alignment: .center)

                Text(title)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .surfaceCard()
        .accessibilityLabel(title)
    }
}

#Preview("ShortcutsSheet") {
    ZStack {
        BulkAITheme.Color.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            ShortcutsSheet(
                onAITap: {},
                onWeightTap: {},
                onSearchTap: {},
                onBarcodeTap: {},
                onYourFoods: {},
                onQuickAdd: {},
                onMetrics: {},
                onRecipes: {},
                onClose: {},
                onConfigure: {}
            )
            .frame(maxHeight: 520)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: BulkAITheme.Radius.lg,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: BulkAITheme.Radius.lg,
                    style: .continuous
                )
                .fill(BulkAITheme.Color.background)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: BulkAITheme.Radius.lg,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: BulkAITheme.Radius.lg,
                    style: .continuous
                )
                .stroke(BulkAITheme.Color.surfaceElevated, lineWidth: 0.5)
            )
        }
    }
}
