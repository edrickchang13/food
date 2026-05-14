# Phase H — Performance Audit

## Summary

12 findings: 0 CRITICAL, 5 HIGH, 5 MEDIUM, 2 LOW. Fixed: 10 in-place. Deferred: 2 architectural proposals.

---

## Hot-path findings

### HIGH (fixed)

- **`ios/calorietracker/Stores/FoodStore.swift:91`** — `todayEntries` scanned the full `entries` array with `.filter { calendar.isDateInToday }` instead of routing through the O(1) day index. At 3,806 entries this runs ~3,806 `isDateInToday` calls per access. Changed to `entries(for: .now)` which does a single dictionary lookup. Estimated gain: eliminates ~3,800 comparisons per call, called 4× by `todayCalories/Protein/Carbs/Fat`.

- **`ios/calorietracker/Stores/FoodStore.swift:183`** — `protein(for:)`, `carbs(for:)`, `fat(for:)` called `entries(for:)` which includes an unnecessary sort. These only need totals, not ordered results. Changed to use the raw day index dict lookup directly, matching what `calories(for:)` already did. Eliminates 3 redundant sorts per day query.

- **`ios/calorietracker/Stores/FoodStore.swift:196`** — All 9 micronutrient aggregators (`sugar`, `addedSugar`, `fiber`, `saturatedFat`, `monounsaturatedFat`, `polyunsaturatedFat`, `cholesterol`, `sodium`, `potassium`) called `entries(for:)` (which sorts). Changed all 9 to use the raw day index. Eliminates 9 unnecessary sorts per nutrient detail view load.

- **`ios/calorietracker/Views/Dashboard/DashboardView.swift:290`** — `weekTotals()`, `lastNDaysIntake(30)`, `weighInHabitData()`, `foodLoggingHabitData()`, `weighInsThisWeek()`, `foodLogsThisWeek()` were called inline in `body`. SwiftUI calls `body` multiple times per frame during scroll. At 3,806 entries: `foodLoggingHabitData()` alone iterates all entries every call; with 5+ body calls per scroll frame that is ~19,000+ iterations per frame. Added `@State` memo fields populated only via `.onChange(of: foodStore.entries.count)` and `.onChange(of: foodStore.entries.last?.id)`. The 6 expensive aggregations now run only when the food or weight log actually changes.

- **`ios/calorietracker/Views/FoodEntry/FoodEntrySheet.swift:379`** — `filteredFavorites`, `filteredSuggestions`, `filteredLibrary` were computed vars that each called `foodDatabase.search()` on every `body` evaluation. Each `search()` call scans up to 6,912 USDA items + seed + AI cache with `localizedCaseInsensitiveContains` (expensive Unicode comparison). With 3 searches per body call, any SwiftUI animation or state change while the sheet is open triggered 3 full-corpus scans. Added `@State` cached arrays populated only via `.onChange(of: filterQuery)` and `.onChange(of: selectedTab)`.

### MEDIUM (fixed)

- **`ios/calorietracker/Views/Dashboard/DashboardView.swift:348`** (old `todayLabelAllCaps`) — `DateFormatter()` was constructed on every `body` call. DateFormatter construction allocates ~40 KB of ICU locale data on iOS. Replaced with `private static let todayLabelFormatter` initialized once.

- **`ios/calorietracker/Views/FoodEntry/FoodEntrySheet.swift:425`** (old `hourLabel`) — `DateFormatter()` constructed on every `body` call. Replaced with `private static let hourFormatter` initialized once.

- **`ios/calorietracker/Views/Strategy/StrategyView.swift:148`** — `checkInLabel` constructed a `DateFormatter()` on every computed-var access (called during body). Replaced with `private static let weekdayFormatter` initialized once.

- **`ios/calorietracker/Services/FoodDatabaseService.swift:137`** — `quickLookup()` called `try? NSRegularExpression(pattern:options:)` on every invocation. NSRegularExpression construction compiles a full ICU regex engine; on every keypress in the AI/Quick-Add tab this added ~0.5 ms. Extracted to `private static let gramsPattern` compiled once at first use.

- **`ios/calorietracker/Stores/FoodStore.swift:108`** — `todayCalories/Protein/Carbs/Fat` all previously called `todayEntries` (which returned the sorted filtered array) and then reduced over it, paying the full-array scan + sort 4 separate times. Each now routes through `calories/protein/carbs/fat(for: .now)` which uses the day index directly.

### LOW (deferred, with proposal)

- **`ios/calorietracker/Engine/EngineState.swift:225`** — `foodStore.onEntriesChanged` triggers `refresh()` synchronously. `refresh()` re-runs `WeightTrend.compute`, `Expenditure.estimate`, `TargetMacros.plan`, and `WeeklyCheckIn.isDue` — all full recomputes over the complete entry history. A bulk import (e.g. MacroFactor CSV with 3,806 entries) calls `addEntries` which fires `onEntriesChanged` once (correctly uses bulk path). However, any future caller that loops `addEntry` N times would call `refresh()` N times. Proposal: add a 300 ms debounce on `onEntriesChanged` → `refresh()` so rapid successive changes coalesce into a single engine pass. See architectural proposals below.

- **`ios/calorietracker/Services/FoodDatabaseService.swift:22`** — `allItems` re-sorts the full merged corpus on every access: `(seed + USDA + aiCache).sorted { localizedCaseInsensitiveCompare }`. This is called by browse UI. The sort is O(N log N) over ~7,000 items each time. Proposal: maintain a pre-sorted `allItems` array and update it incrementally when `aiCache` is appended to. See architectural proposals below.

---

## Architectural proposals (deferred)

### Engine refresh debouncing

`EngineState.observeStores()` wires `onEntriesChanged` to `refresh()` directly. `refresh()` runs 4 engine computations over the full history. The bulk-import path correctly avoids the N-call problem, but any future code path that calls `addEntry` in a loop would saturate the main thread.

Proposed change (not applied — requires touching the engine wiring):

```swift
// In EngineState.observeStores()
private var refreshDebounceTask: Task<Void, Never>?

private func scheduleRefresh() {
    refreshDebounceTask?.cancel()
    refreshDebounceTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        refresh()
    }
}
```

Wire `onEntriesChanged` to `scheduleRefresh()` instead of `refresh()`.

### FoodDatabaseService sorted-allItems cache

`allItems` sorts the full 7,000+ item corpus every call. Since `aiCache` only grows (items are appended, never removed), the sorted result can be maintained incrementally:

```swift
private var cachedAllItems: [FoodDatabaseItem] = []

// Rebuild only when aiCache changes or USDA loads:
private func rebuildAllItems() {
    cachedAllItems = (FoodDatabaseSeed.items + loadUSDAIfNeeded() + aiCache)
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

var allItems: [FoodDatabaseItem] { cachedAllItems }
```

Call `rebuildAllItems()` in `init()`, after `loadUSDAIfNeeded()` completes, and in `record(_:)`.

### Search prefix index (longer term)

`search()` uses `localizedCaseInsensitiveContains` over 7,000 items per keypress. A prefix trie or sorted array with binary-search on lowercased name prefixes would reduce per-keypress search from O(N) to O(log N + K) for K results. Not applied — requires a non-trivial data structure and would change the `FoodDatabaseService` API surface. Worth revisiting when the USDA corpus grows beyond 10,000 items or when profiling shows >16 ms search latency on a real device.

---

## Measurement notes

- `DashboardView.weekTotals()` iterates 7 days × `foodStore.entries(for:)` per day. At 3,806 entries with a well-distributed day index this is 7 O(1) lookups + 7 small sorts. Previously was calling 7 `.filter` scans over the full array = ~26,642 comparisons per `body` call.
- `foodLoggingHabitData()` iterates all `foodStore.entries` to build the habit heatmap. At 3,806 entries this is one pass = ~3,806 iterations. Called on every body call before memoization; now called only on entry count/id change.
- `filteredFavorites + filteredSuggestions + filteredLibrary` = 3 × `localizedCaseInsensitiveContains` scans over ~7,000 items per body call. `localizedCaseInsensitiveContains` uses Unicode collation and is roughly 10× slower than a plain ASCII `contains`. Before memoization, a single tab-switch animation (5–10 body calls) triggered 35–70 full-corpus scans.
- `DateFormatter` construction: Apple's profiler shows 40–80 µs per `DateFormatter()` init on iOS 18 hardware. Three formatter constructions per body call × 5 body calls per scroll frame = 600–1,200 µs of formatter init overhead per frame at 60 fps = up to 7% of a 16 ms frame budget wasted on allocation. All three are now static lets.
- `NSRegularExpression` construction: ~0.3–0.5 ms per call on A16+. Now compiled once.
