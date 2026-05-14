# Phase A — Foundation (design tokens + 8 shared components)

**Blocks every other phase.** Nothing else can start until A is on `main`.

## Branch

`phase-a-foundation`

## Allowed paths (exclusive write)

- `ios/calorietracker/Theme/**`
- `ios/calorietracker/Components/**`

## Forbidden

Don't touch `ContentView.swift`, `calorietrackerApp.swift`, any `Views/` subfolder except via read-only inspection, or `project.pbxproj` (synchronized groups will pick the new folders up automatically when this branch's files are committed).

## Deliverables

### `Theme/Tokens.swift`

Extract from the MacroFactor reference screenshots (`~/Downloads/macrofactor-screens/IMG_6455.PNG` is the primary palette source). Define:

```swift
enum BulkAITheme {
    enum Color {
        static let background = Color(hex: "0F0F10")
        static let surface = Color(hex: "1A1A1C")
        static let surfaceElevated = Color(hex: "232326")

        // Domain accents (MacroFactor convention preserved)
        static let macroCalories = Color(hex: "4C9AFF")   // blue
        static let macroProtein = Color(hex: "E36B5E")    // coral / red-orange
        static let macroFat = Color(hex: "E8C547")        // mustard yellow
        static let macroCarbs = Color(hex: "5BC98B")      // mint green

        static let expenditure = Color(hex: "8C6B4F")     // brown sparkline
        static let weightTrend = Color(hex: "9D7BD8")     // purple
        static let bodyMetrics = Color(hex: "5BC98B")     // green
        static let activity = Color(hex: "F4A07A")        // coral steps

        // Bulk AI accent stays
        static let accent = Color(hex: "FF6B6B")
    }
    enum Typography { /* SF Rounded family, sizes 11/13/15/17/20/28/40 */ }
    enum Spacing { /* 4 / 8 / 12 / 16 / 20 / 24 / 32 */ }
    enum Radius { /* 10 / 14 / 18 */ }
}
```

### `Theme/Surface.swift`

`SurfaceCard` view modifier that wraps content in `BulkAITheme.Color.surface`, 14pt radius, no shadow, hairline divider treatment.

### Components

Each in its own file under `Components/`. Each must:
1. Be standalone (no `@Environment` dependencies — take everything as parameters or `@Binding`)
2. Have a `#Preview` showing realistic data
3. Build cleanly under Xcode 16.4 / Swift 6.0 (run the GitHub Actions runner's compile path mentally — no `Chart { ForEach + if let }` patterns, see `docs/HANDOFF.md` "Anti-patterns")

| File | Component | Notes |
|---|---|---|
| `Components/ContributionGridView.swift` | GitHub-style heatmap | Takes `[Date: Double]` data, configurable cell color, 7-row weekly layout, last 30 days default |
| `Components/MacroWeekChart.swift` | 7-column stacked bars | Top pill = kcal, then 3 colored blocks (P/F/C) with embedded numeric labels. Used by Strategy + Set Program. |
| `Components/CountdownRing.swift` | Circular progress ring with center label | Takes `daysRemaining`, total, label. Green arc for active portion, gray for remaining. |
| `Components/RulerSlider.swift` | Horizontal tick scrubber | Like an iOS picker wheel on its side. Takes range, step, current value binding. Used by Edit Goal weight selection. |
| `Components/NumberedTimeline.swift` | Vertical connected numbered steps | Each step: number circle, bold title, colored sub-value, description paragraph. Vertical connector line between circles. |
| `Components/DiffRowCard.swift` | "old ›› new" diff cell | Two values with a chevron separator. Used by Edit Goal review screen. |
| `Components/ThinProgressBar.swift` | Track with tick marker | NOT a filled progress bar. Just a track + a small vertical tick at the current value position. Used heavily on dashboard. |
| `Components/InsightCard.swift` | Icon + sparkline + big number + chevron | The Dashboard analytics tile. Takes title, icon, sparkline data, value text, chevron action. |
| `Components/PillTabBar.swift` | Scrollable horizontal segmented row | The "Scan / Search / AI / Quick Add / Library / Describe…" top-tab pattern in the food entry sheet. White-pill selected state on dark track. |
| `Components/SegmentedToggle.swift` | Two-option toggle, white-pill-on-dark | Used by "Consumed / Remaining" and "Expenditure / Targets" on the Dashboard cards. |

## Definition of done

1. `xcodebuild -project ios/calorietracker.xcodeproj -scheme calorietracker -destination 'generic/platform=iOS Simulator' build` succeeds.
2. `swift test --package-path ios/Packages/BulkAIEngine/` still passes (48 tests).
3. Every component has a working `#Preview` you can spot-check in Xcode's canvas.
4. Branch pushed; tell the orchestrator the diff is ready for review and merge.

## Reference

`~/Downloads/macrofactor-screens/IMG_6455.PNG`, `IMG_6460.PNG`, `IMG_6473.PNG`, `IMG_6480.PNG` cover the visual language for ~95% of these components. Inspect the file before opening Xcode.
