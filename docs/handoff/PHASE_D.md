# Phase D — Food Entry sheet

**Blocked by Phase A.** Runs in parallel with B, C, E, F.

## Branch

`phase-d-food-entry`

## Allowed paths

- `ios/calorietracker/Views/FoodEntry/**` (new directory)
- Replacing `ios/calorietracker/Views/QuickAddSheet.swift` is OK (this supersedes the current MVP entry sheet)

## Reference screens

`IMG_6466` (Search), `IMG_6467` (Scan), `IMG_6468` (AI), `IMG_6469` (Quick Add), `IMG_6470` (Library) in `~/Downloads/macrofactor-screens/`.

## Architecture

```
FoodEntrySheet
├── HeaderPillRow            X / time pill / kcal-ring pill / utensils pill / down-chevron
├── PillTabBar               scrollable: Scan / Search / AI / Quick Add / Library / Describe
└── @ViewBuilder body per tab
    ├── ScanView             Barcode + Label sub-segment, camera viewfinder
    ├── SearchView           Favorites avatar row + time-of-day "Picks" list + food rows
    ├── AIView               Snap + Describe sub-segment
    ├── QuickAddView         manual macro form with live "Macro sum is X kcal" check
    ├── LibraryView          Recipes/Foods toggle + sort dropdown + rows
    └── DescribeView         free-form text -> Gemini parse
FloatingBottomBar            small search + "Log Foods" CTA, persistent across all tabs
```

## File layout

```
Views/FoodEntry/
  FoodEntrySheet.swift           top-level container
  HeaderPillRow.swift            5-pill header (X / time / kcal / utensils / chevron-down)
  Tabs/
    ScanView.swift               wraps existing CameraView with barcode/label sub-segment
    SearchView.swift             Favorites avatars + 9 AM Picks + food rows (reuses FoodDatabaseService.search)
    AIView.swift                 Snap (wraps CameraView with auto-analyze) + Describe (Gemini text parse)
    QuickAddView.swift           manual macro entry form with live kcal validation
    LibraryView.swift            Recipes + Foods toggle + sort dropdown
    DescribeView.swift           text-only Gemini parse (same as current QuickAddSheet's text path)
  Rows/
    FoodSearchRow.swift          left icon + name + macro line + trailing "+"
    FavoriteAvatar.swift         circular avatar with "+" badge
  FloatingBottomBar.swift        persistent across tabs
```

## Reuse from existing code

- `GeminiService.analyzeTextInput(description:foodDatabase:)` for AI/Describe
- `GeminiService.autoAnalyze(image:)` for AI/Snap
- `GeminiService.analyzeNutritionLabel(...)` for Scan/Label
- `FoodDatabaseService.search` + `.searchIncludingRemote` for Search and Library
- `CameraView`, `PhotosPicker` from existing infrastructure
- `ManualEntryView` for Quick Add - or rewrite if the visual is too different

## Definition of done

1. All six tabs render and route correctly
2. Selected tab's white-pill indicator is reactive
3. Logging via any tab adds to `FoodStore` exactly once and matches existing entry semantics
4. Header pills reflect the meal slot picked (utensils icon changes color when meal-type set)
5. `xcodebuild` + `swift test` green

## Watch out for

- The PillTabBar is **horizontally scrollable** (more tabs than fit on screen). Use Phase A's `Components/PillTabBar.swift`.
- The Quick Add view has a live "Macro sum is N kcal" validator. Compute as `proteinG*4 + carbsG*4 + fatG*9` and compare to entered energy. Don't gate save on it - just show as a helper.
- The 9 AM Picks list is contextual to the time pill's value. If the user changes the time, the suggestions refresh. For MVP, query `FoodStore.entries` filtered by hour-of-day +/- 1h.
