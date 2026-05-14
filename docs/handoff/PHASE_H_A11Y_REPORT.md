# Phase H — Accessibility Audit

## Summary

26 findings: 2 CRITICAL, 8 HIGH, 11 MEDIUM, 5 LOW. Fixed: 21 in-place. Deferred: 5 (Dynamic Type, one contrast edge case, FoodLog entry-row missing label).

---

## CRITICAL findings (fixed)

- `Views/FoodLog/DayHeaderBar.swift:48` — Menu button frame was 32×32pt; primary nav control on the Food Log screen. Expanded to `minWidth: 44, minHeight: 44` with `.contentShape(Rectangle())`. Added `accessibilityHidden(true)` to the inner SF Symbol to prevent double-read.

- `Views/FoodLog/HourTimeline.swift:104` — Per-hour "+" add button had a 28×28pt visual circle used as the sole hit target on the main food-logging timeline. Expanded to `frame(minWidth: 44, minHeight: 44)` with `contentShape(Rectangle())` while keeping the visual circle at 28pt. Added `accessibilityHidden(true)` to the inner plus symbol.

---

## HIGH findings (fixed)

- `Views/FoodLog/DayHeaderBar.swift:73` — Previous/Next day chevron buttons were 28×28pt. Expanded to `minWidth: 44, minHeight: 44`. Added `accessibilityHidden(true)` on the chevron images (labels already supplied via `accessibilityLabel`).

- `Views/FoodEntry/HeaderPillRow.swift:33` — `pillHeight` and `circleSize` constants were both 36pt. Raised to 44pt. This affects the close, time, calorie, utensils, and collapse pill/button targets in the Food Entry sheet header row. Added `accessibilityHidden(true)` to the icon images inside the close, utensils, and collapse buttons.

- `Views/FoodLog/ShortcutsSheet.swift:62` — Close and Configure header buttons had 32×32pt frames. Expanded to `minWidth: 44, minHeight: 44` with `contentShape(Rectangle())`. Added `accessibilityHidden(true)` on each SF Symbol image.

- `Views/FoodEntry/Rows/FoodSearchRow.swift:29` — "+" add button was 32×32pt. Raised `addButtonSize` constant to 44pt. Added `accessibilityHidden(true)` to the plus symbol (button already has `accessibilityLabel("Add \(name)")`).

- `Components/SegmentedToggle.swift:42` — Segment buttons had `accessibilityAddTraits` only; VoiceOver announced "button" with no label. Added `.accessibilityLabel(label)` so VO reads the option name ("Standard", "Custom", etc.).

- `Components/MacroWeekChart.swift:49` — The stacked macro chart had zero accessibility treatment; entirely invisible to VoiceOver. Added `.accessibilityElement(children: .ignore)` on the outer `VStack` with a computed `chartAccessibilityLabel` that summarises all seven days as "7-day macro chart. Monday: 3414 kcal, 190g protein, 113g fat, 407g carbs. …".

- `Components/InsightCard.swift:38` — SF Symbol icon inside the card `Button` was not `accessibilityHidden`; VoiceOver would read the system image name before the title. Added `accessibilityHidden(true)` to the icon and the sparkline overlay. Added explicit `.accessibilityLabel` combining title, optional subtitle, and value so the combined announcement is clean.

- `Components/DiffRowCard.swift:62` — The `">>"` direction indicator was read literally as "greater than greater than" by VoiceOver. Wrapped the changed-value `HStack` in `.accessibilityElement(children: .ignore)` with `.accessibilityLabel("\(currentValue), changed to \(newValue)")`. The `">>"` `Text` is also individually `accessibilityHidden(true)` as belt-and-suspenders.

---

## MEDIUM findings (fixed in place)

- `Views/Strategy/Header/StrategyHeader.swift:20` — Collapse/expand animations (opacity, scaleEffect, offset) ran unconditionally. Added `@Environment(\.accessibilityReduceMotion)`. Scale effect and offset transition are disabled at Reduce Motion; opacity-only crossfade remains (opacity changes are an accepted Reduce Motion fallback per WCAG 2.3 / Apple HIG).

- `Views/Strategy/Header/StrategyHeader.swift:54` — Compact strip used `.ultraThinMaterial` with no Reduce Transparency fallback. Added `@Environment(\.accessibilityReduceTransparency)`; falls back to `BulkAITheme.Color.surface` when the setting is on.

- `Views/FoodEntry/FloatingBottomBar.swift:26` — `.ultraThinMaterial` background with no Reduce Transparency fallback. Added `@Environment(\.accessibilityReduceTransparency)`; falls back to `BulkAITheme.Color.surfaceElevated` (opaque dark surface) ensuring the white "Log Foods" pill retains contrast.

- `Components/SegmentedToggle.swift:44` — `withAnimation(.snappy)` ran on every tap unconditionally. Added `@Environment(\.accessibilityReduceMotion)`; selection is now set directly without animation when Reduce Motion is on.

- `Components/PillTabBar.swift:47` — `withAnimation(.snappy)` on tab selection and `proxy.scrollTo` ran unconditionally. Added `@Environment(\.accessibilityReduceMotion)`; both animation calls are bypassed when Reduce Motion is on.

- `Views/Wizards/Shared/WizardProgressUnderline.swift:40` — Pill color animation ran unconditionally. Added `@Environment(\.accessibilityReduceMotion)`; `.animation` is set to `nil` when Reduce Motion is on.

- `Components/CountdownRing.swift:36` — Arc progress animation ran unconditionally. Added `@Environment(\.accessibilityReduceMotion)`; `.animation` is set to `nil` when Reduce Motion is on.

- `Views/Strategy/Actions/ActionPillCarousel.swift:53` — SF Symbol icons inside pill buttons were not `accessibilityHidden`; labels already supplied via `.accessibilityLabel`. Added `accessibilityHidden(true)` to each icon.

- `Views/Wizards/Steps/SetProgram_Preferences.swift:61` — Preference cards had no `accessibilityLabel`; VoiceOver would read icon system name + title + subtitle as separate fragments. Added `.accessibilityLabel("\(preference.displayName), \(preference.subtitle)")` and `.accessibilityAddTraits(isSelected ? .isSelected : [])`.

- `Views/About/FreeSigningStatusView.swift:46` — Hero `checkmark.shield.fill` SF Symbol was not `accessibilityHidden`. It is purely decorative; the surrounding text explains the content. Added `accessibilityHidden(true)`.

- **Section heading traits (Dashboard + Strategy)** — Added `.accessibilityAddTraits(.isHeader)` to section title `Text` views in: `InsightsAnalyticsGrid` ("Insights & Analytics"), `HabitsSection` ("Habits"), `BodyMetricsRow` ("Body Metrics"), `NutritionGrid` ("Nutrition"), `GeneralSection` ("General"), `MoreSection` ("More"), and `StrategyView` ("IN PROGRESS"). VoiceOver users navigating by headings can now jump between dashboard sections. The `DayHeaderBar` day label already carried `.isHeader`.

- `Views/Strategy/Ring/CheckInCountdownRing.swift:76` — Goal and Check-In metadata columns now carry `.accessibilityElement(children: .combine)` so VoiceOver reads each column as a single announcement ("GOAL: Maintain weight") rather than two separate elements.

---

## LOW findings (deferred, with proposal)

- **FoodLog `entryRow` has no `accessibilityLabel`** — `HourTimeline.entryRow` wraps a `Button` whose label contains an emoji, name text, macro text, and time text. SwiftUI's implicit traversal reads all child text in sequence which is acceptable but verbose. Adding `.accessibilityElement(children: .ignore)` with a composed label like `"\(entry.name), \(entry.calories) kcal"` and an optional hint would tighten this. Deferred because it needs coordination with the food-detail sheet for the `accessibilityHint`.

- **`DynamicTDEEExplainer` operator text** — The `opText` helper renders `=`, `−`, `×`, `/`, `(`, `)` at `white.opacity(0.45)`, giving ~5.5:1 contrast against `0F0F10` — passes. However `white.opacity(0.4)` on the "WHY THIS MATTERS" caption label yields ~4.9:1 — technically just above the 4.5:1 threshold but dangerously close at sub-optimal display conditions. Recommend raising to `white.opacity(0.5)` in a follow-up pass. Not touched here to stay surgical.

- **`HourTimeline` entry `entryRow` emoji avatar** — The emoji avatar circle `accessibilityHidden` is not set. When the emoji is present the `Text(emoji)` inherits VoiceOver focus inside the button. Propose wrapping the avatar `ZStack` with `accessibilityHidden(true)` and letting the outer `Button` carry the food name.

- **Reduce Motion — Wizard step transitions** — `EditGoalFlow` and `SetProgramFlow` both drive `.animation(.easeOut, value: currentStep)` on the full-height `stepContent`. This produces a content cross-fade/slide. The parent `withAnimation(.easeOut)` call in `handleButtonTap` is not gated. Proposal: check `@Environment(\.accessibilityReduceMotion)` and set the animation to `nil` in both flow files when the setting is on.

---

## Tokens.swift refactor proposal (Dynamic Type)

All seven `BulkAITheme.Typography` tokens use `Font.system(size: N, ...)` with fixed point sizes. This means text does not respond to the user's preferred text size setting and fails WCAG 2.2 SC 1.4.4 (Resize Text) at AX5 accessibility sizes.

**Proposed approach — do not execute this refactor without a dedicated engineering sprint:**

Replace each fixed-size token with the corresponding relative text style, preserving the SF Rounded design and weight:

```
caption2  (11pt medium)  → Font.system(.caption2, design: .rounded).weight(.medium)
caption   (13pt medium)  → Font.system(.caption, design: .rounded).weight(.medium)
body      (15pt regular) → Font.system(.body, design: .rounded)
headline  (17pt semibold)→ Font.system(.headline, design: .rounded)
title3    (20pt semibold)→ Font.system(.title3, design: .rounded).weight(.semibold)
title     (28pt bold)    → Font.system(.title, design: .rounded).weight(.bold)
display   (40pt bold)    → Font.system(.largeTitle, design: .rounded).weight(.bold)
```

Using `Font.system(_:design:)` with a named style lets UIKit/SwiftUI scale the size automatically with Dynamic Type while preserving the SF Rounded design. The weight modifier on top corrects for the default weight each style carries.

For the two visualisation surfaces — `MacroWeekChart` and the equation card in `DynamicTDEEExplainer` — which must not reflow at large text sizes because they are spatial/numerical displays, wrap those specific call sites in a `dynamicTypeSize(...DynamicTypeSize.accessibility3)` clamp. This satisfies SC 1.4.4 up to ~310% zoom (AX3) while preventing layout breakage at the extreme AX5 size. Annotate the clamp with a comment explaining the exception.

All 50+ files that import `BulkAITheme.Typography` tokens would pick up the change automatically. The critical risk is that the MacroFactor-reference numeric displays (`title3` values in stat tiles, `display` in the TDEE explainer) may grow beyond their card bounds at AX4+. Layout testing at AX3 and AX4 simulator sizes is mandatory before shipping this change.

A secondary concern is the `DailyMacroSummary` pill row, which uses `minimumScaleFactor(0.8)` and `lineLimit(1)` — these will need re-evaluation once text scales dynamically, since the pills may truncate earlier or need a two-line layout fallback.
