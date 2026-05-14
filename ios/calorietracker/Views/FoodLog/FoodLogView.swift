import SwiftUI

/// MacroFactor-style Food Log: a day-centric timeline view. Top is the day
/// header + horizontal week strip + 4-pill macro summary. Body is an hourly
/// timeline (7 AM through 11 PM by default) listing meals with quick-add per
/// hour. The "+" FAB on the tab bar presents `FoodEntrySheet`; the per-hour
/// "+" buttons present the same sheet pre-filled with the tapped hour.
struct FoodLogView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(ProfileStore.self) private var profileStore

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showShortcuts: Bool = false
    @State private var quickAddHour: Date? = nil
    @State private var showShortcutsBackground: Bool = true

    private var profile: UserProfile { profileStore.profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    DayHeaderBar(date: $selectedDate, onMenuTap: { showShortcuts = true })
                        .padding(.horizontal, 16)
                    WeekStrip(selectedDate: $selectedDate, loggedDates: loggedDates())
                        .padding(.horizontal, 16)
                    DailyMacroSummary(
                        caloriesConsumed: Double(macros.kcal),
                        caloriesTarget: Double(profile.effectiveCalories),
                        proteinConsumed: Double(macros.protein),
                        proteinTarget: Double(profile.effectiveProtein),
                        fatConsumed: Double(macros.fat),
                        fatTarget: Double(profile.effectiveFat),
                        carbsConsumed: Double(macros.carbs),
                        carbsTarget: Double(profile.effectiveCarbs)
                    )
                    .padding(.horizontal, 16)
                    HourTimeline(
                        date: selectedDate,
                        entries: foodStore.entries(for: selectedDate),
                        onAdd: { hour in quickAddHour = hour },
                        onTapEntry: { _ in /* TODO open entry editor */ }
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(BulkAITheme.Color.background)
        }
        .background(BulkAITheme.Color.background)
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet(
                onAITap: { showShortcuts = false },
                onWeightTap: { showShortcuts = false },
                onSearchTap: { showShortcuts = false },
                onBarcodeTap: { showShortcuts = false },
                onYourFoods: { showShortcuts = false },
                onQuickAdd: { showShortcuts = false; quickAddHour = .now },
                onMetrics: { showShortcuts = false },
                onRecipes: { showShortcuts = false },
                onClose: { showShortcuts = false },
                onConfigure: { showShortcuts = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { quickAddHour.map { IdentifiableDate(date: $0) } },
            set: { quickAddHour = $0?.date }
        )) { wrapper in
            FoodEntrySheet(initialTime: wrapper.date)
        }
    }

    private struct IdentifiableDate: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSince1970 }
    }

    // MARK: - Aggregates

    private var macros: (kcal: Int, protein: Int, fat: Int, carbs: Int) {
        let entries = foodStore.entries(for: selectedDate)
        return (
            kcal: entries.reduce(0) { $0 + $1.calories },
            protein: entries.reduce(0) { $0 + $1.protein },
            fat: entries.reduce(0) { $0 + $1.fat },
            carbs: entries.reduce(0) { $0 + $1.carbs }
        )
    }

    private func loggedDates() -> Set<Date> {
        let calendar = Calendar.current
        return Set(foodStore.entries.map { calendar.startOfDay(for: $0.timestamp) })
    }
}
