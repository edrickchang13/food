# Phase C — Food Log

**Blocked by Phase A.** Can run in parallel with B, D, E, F once A has merged.

## Branch

`phase-c-food-log`

## Allowed paths

- `ios/calorietracker/Views/FoodLog/**` (new directory)

## Forbidden

- `ContentView.swift` except for one-line tab routing
- `Views/Dashboard/**` (Phase B)
- `Components/**` (Phase A)

## Reference screens

`IMG_6465.PNG` (day view), `IMG_6472.PNG` (Shortcuts bottom sheet from center FAB).

## Architecture

```
FoodLogView
├── DayHeaderBar             hamburger / chevron-left / "Today" / chevron-right
├── WeekStrip                horizontal 7-chip day picker, status rings
├── DailyMacroSummary        4 thin progress pills (kcal/P/F/C) with paging dots
└── HourTimeline             vertical agenda 7 AM-11 PM, "+" per hour
ShortcutsSheet (presented when center FAB tapped from Food Log tab)
├── 4 circular icon buttons  AI / Weight / Search / Barcode
└── List rows               Your Foods / Quick Add / Metrics / Recipes
```

## File layout

```
Views/FoodLog/
  FoodLogView.swift          top-level, owns selectedDate state
  DayHeaderBar.swift
  WeekStrip.swift            uses status rings; the cyan-blue outline marks days with logs
  DailyMacroSummary.swift    uses Components/ThinProgressBar
  HourTimeline.swift         vertical agenda, taps "+" open the entry sheet pre-filled with time
  ShortcutsSheet.swift       half-height sheet, replaces the Quick Add sheet for users on this tab
```

## Data wiring

| View | Reads from | Writes to |
|---|---|---|
| WeekStrip | `FoodStore.entries` grouped by day - know which days are "logged" | sets `selectedDate` |
| DailyMacroSummary | `FoodStore.entries(for: selectedDate)` aggregated | none |
| HourTimeline | `FoodStore.entries(for: selectedDate)` grouped by hour | tapping "+" presents `QuickAddSheet` with the picked hour as initial time |

## Definition of done

1. Food Log tab renders the new view
2. Week strip correctly marks days with food entries (look for blue ring)
3. Tapping "+" on an hour pre-selects that hour in the entry sheet
4. Center FAB on this tab now presents `ShortcutsSheet` instead of the generic `QuickAddSheet` (or both - decide with the orchestrator)
5. `xcodebuild` + `swift test` green

## Watch out for

- The hour-timeline scrolling can be expensive at 1Y view. Don't recompute aggregates inside `ForEach`; precompute outside the View body.
- The day chip has three visual states: selected (filled gray with dot), logged-past (cyan outline ring), unlogged (no decoration). All three are visible in `IMG_6465`.
