# Phase B — Dashboard

**Blocked by Phase A.** Confirm Phase A has merged to main before starting.

## Branch

`phase-b-dashboard`

## Allowed paths

- `ios/calorietracker/Views/Dashboard/**` (new directory)
- Replacing `ios/calorietracker/Views/HomeComponents.swift` is OK (this is the legacy Fud AI dashboard you're superseding)

## Forbidden

- `ContentView.swift` except for a one-line swap to route the Home tab to the new view
- Any other phase's `Views/` folder
- `Components/**` (those are Phase A's; if you need a missing component, ping the orchestrator)

## Reference screens

`IMG_6455` through `IMG_6464` in `~/Downloads/macrofactor-screens/`.

## Architecture

The MacroFactor dashboard is conceptually:

```
ZStack {
    ScrollView {
        TabView(.page) {     // horizontal pager, 3 cards
            EnergyBalanceCard(...)
            DailyNutritionCard(...)
            ThirdCard(...)   // TBD - inspect IMG_6458 / 6459 carefully
        }
        .frame(height: ~450)

        // Below the pager:
        InsightsAndAnalyticsGrid(...)   // 2x2: Expenditure / Weight Trend / Energy Balance / Goal Progress
        HabitsSection(...)               // 2x ContributionGridView (Weigh-In, Food Logging)
        BodyMetricsRow(...)              // 2-card row
        NutritionGrid(...)               // 2x2 macro cards
        GeneralSection(...)              // Steps + future activity
        MoreSection(...)                 // "Customize Dashboard" + "Nutrition Data Manager" entries
    }
    SearchBarPinnedToBottom(...)         // sticky over the tab bar's safe area
}
```

## File layout

```
Views/Dashboard/
  DashboardView.swift              top-level, owns scroll + pager
  Cards/
    EnergyBalanceCard.swift        IMG_6456 / 6457 (toggle drives state)
    DailyNutritionCard.swift       IMG_6459
    ThirdCard.swift                inspect IMG_6458 - might be a duplicate; verify
  Sections/
    InsightsAnalyticsGrid.swift    uses Components/InsightCard
    HabitsSection.swift            uses Components/ContributionGridView
    BodyMetricsRow.swift
    NutritionGrid.swift            uses Components/ThinProgressBar
    GeneralSection.swift
    MoreSection.swift
  DashboardSearchBar.swift         pinned floating search field + AI sparkle button
```

## Data wiring

All cards read from existing stores via `@Environment`:

| Card | Reads from |
|---|---|
| Energy Balance | `EngineState.snapshot.expenditure` + `FoodStore.calories(for:)` over last 30 days + `UserProfile.effectiveCalories` |
| Daily Nutrition | `FoodStore.todayCalories/Protein/Carbs/Fat` + `UserProfile.effectiveCalories/Protein/Carbs/Fat` |
| Insights · Expenditure | `EngineState.snapshot.expenditure.kcalPerDay` + recent history (we don't track history yet - just show the current value) |
| Insights · Weight Trend | `EngineState.snapshot.trend` last 7 points |
| Insights · Energy Balance | derived: avg(calories) - expenditure over 7d |
| Insights · Goal Progress | `UserProfile.goalWeightKg` vs current vs start, % over duration |
| Habits · Weigh-In | last 30 days of `WeightStore.entries` -> ContributionGridView green colorway |
| Habits · Food Logging | last 30 days of `FoodStore.entries` -> ContributionGridView blue colorway |
| Body Metrics | `WeightStore.latestEntry` + optional `BodyFatStore.latestEntry` |
| Nutrition macro cards | `FoodStore.todayProtein/Carbs/Fat` + targets |
| General · Steps | HealthKit if available; placeholder otherwise |

## Definition of done

1. Open Home tab in simulator -> the new dashboard renders without crashes
2. With the imported MacroFactor CSV loaded (3,806 entries), Habits' Food Logging grid shows dense activity for the imported date range
3. `xcodebuild` build green
4. `swift test` 48/48 still passing
5. Tab bar still works (your changes shouldn't have touched it; if they did, regression)

## Watch out for

- The MacroFactor screenshots show 0 calories everywhere because the user hadn't logged that day. After their CSV import, you'll see real data. Don't hardcode zeros.
- The horizontal pager has dot indicators; SwiftUI's `TabView(.page)` provides them automatically but the dot tint needs setting.
- The bottom search bar floats above the custom tab bar - this requires careful safe-area / `ignoresSafeArea(.keyboard)` handling, similar to the existing custom tab bar setup.
