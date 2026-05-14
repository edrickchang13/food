import SwiftUI

/// A horizontally scrollable segmented row of pill tabs, mirroring the top
/// of MacroFactor's Food Entry sheet (`~/Downloads/macrofactor-screens/IMG_6466.PNG`).
///
/// The selected tab is a white-filled pill with black text; unselected tabs
/// are gray text on the dark track. When `tabs.count` exceeds what fits on
/// screen the row scrolls horizontally. The white pill animates between
/// positions via `matchedGeometryEffect`, so changing the binding moves the
/// pill smoothly to the newly selected slot.
///
/// Pass `tabIcons` to render SF Symbols next to each label. The array, when
/// provided, must match `tabs.count`; mismatched lengths render labels only.
struct PillTabBar: View {

    let tabs: [String]
    @Binding var selection: Int
    let tabIcons: [String]?

    @Namespace private var pillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        tabs: [String],
        selection: Binding<Int>,
        tabIcons: [String]? = nil
    ) {
        self.tabs = tabs
        self._selection = selection
        self.tabIcons = tabIcons
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BulkAITheme.Spacing.xs) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                        tabButton(index: index, title: title)
                            .id(index)
                    }
                }
                .padding(.horizontal, BulkAITheme.Spacing.xs)
                .padding(.vertical, BulkAITheme.Spacing.xxs)
            }
            .background(
                Capsule().fill(BulkAITheme.Color.surface)
            )
            .onChange(of: selection) { _, newValue in
                if reduceMotion {
                    proxy.scrollTo(newValue, anchor: .center)
                } else {
                    withAnimation(.snappy) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private func tabButton(index: Int, title: String) -> some View {
        let isSelected = index == selection
        return Button {
            if reduceMotion {
                selection = index
            } else {
                withAnimation(.snappy) {
                    selection = index
                }
            }
        } label: {
            HStack(spacing: BulkAITheme.Spacing.xxs) {
                if let icon = iconName(at: index) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(BulkAITheme.Typography.body)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.vertical, BulkAITheme.Spacing.xs)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "pill", in: pillNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func iconName(at index: Int) -> String? {
        guard let tabIcons, tabIcons.count == tabs.count else { return nil }
        return tabIcons[index]
    }
}

private struct PillTabBarPreviewHarness: View {
    @State private var selectionA: Int = 1
    @State private var selectionB: Int = 0

    private let fiveTabs = ["Scan", "Search", "AI", "Quick Add", "Library"]
    private let fiveIcons = [
        "barcode.viewfinder",
        "magnifyingglass",
        "sparkles",
        "plus.square",
        "books.vertical"
    ]
    private let sixTabs = ["Scan", "Search", "AI", "Quick Add", "Library", "Describe"]

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
            Text("5 tabs, Search selected")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
            PillTabBar(tabs: fiveTabs, selection: $selectionA, tabIcons: fiveIcons)

            Text("6 tabs, scrolls horizontally")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
            PillTabBar(tabs: sixTabs, selection: $selectionB)
        }
        .padding(BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BulkAITheme.Color.background)
    }
}

#Preview("PillTabBar") {
    PillTabBarPreviewHarness()
}
