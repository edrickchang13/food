import SwiftUI

/// Four-tab bar with a floating "+" button in the center, MacroFactor-style.
/// The + button is bigger, elevated above the tab strip, and opens a Quick
/// Add sheet for fast food logging without leaving the current tab.
struct CustomTabBar: View {
    enum Tab: Hashable {
        case home, progress, coach, settings, about
    }

    @Binding var selection: Tab
    var onAddTapped: () -> Void

    private let visibleTabs: [(Tab, String, String)] = [
        (.home, "house.fill", "Home"),
        (.progress, "apple.logo", "Food Log"),
        (.coach, "bubble.left.and.bubble.right.fill", "Coach"),
        (.settings, "gearshape.fill", "Settings")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                tabButton(visibleTabs[0])
                tabButton(visibleTabs[1])
                Spacer().frame(width: 72)   // hole for the floating + button
                tabButton(visibleTabs[2])
                tabButton(visibleTabs[3])
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 0.5)
            }

            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(AppColors.calorie)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.appBackground, lineWidth: 3)
                    )
                    .shadow(color: AppColors.calorie.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .offset(y: -6)
            .accessibilityLabel("Add food")
        }
    }

    @ViewBuilder
    private func tabButton(_ entry: (Tab, String, String)) -> some View {
        let (tab, icon, label) = entry
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
            .foregroundStyle(selection == tab ? AppColors.calorie : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
