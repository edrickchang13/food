# Bulk AI — Handoff for parallel work

If you are a fresh Claude instance picking this project up, read this top to bottom before doing anything. It compresses ~10 sessions of context into one page.

## What Bulk AI is

iOS-only, single-developer nutrition tracker. **Forked from [apoorvdarshan/fud-ai](https://github.com/apoorvdarshan/fud-ai)** (MIT) by `edrickchang13`. Personal project. Distributed via [AltStore](https://altstore.io/) (free Apple ID signing), not the App Store.

Local repo: `~/food`. GitHub: `github.com/edrickchang13/food`.

## What's already shipped

| Phase | What | Key files |
|---|---|---|
| P0 | Engine package + 48 unit tests | `ios/Packages/BulkAIEngine/` |
| P1 | Engine wired into iOS app | `ios/calorietracker/Engine/EngineState.swift`, `EngineDebugView.swift` |
| P2 | Weekly check-in flow | `ios/calorietracker/Engine/CheckInReviewView.swift` |
| P3 | Program modes, body measurements, period tracking, progress photos, recipes, URL importer | `Stores/MeasurementStore.swift`, `Stores/PeriodStore.swift`, `Stores/ProgressPhotoStore.swift`, `Stores/RecipeStore.swift`, `Services/RecipeImporter.swift`, plus matching Views |
| P4 | Rebrand Fud AI → Bulk AI (strings + display name) | many files |
| P5 | Locked to Gemini-only + Plus/RevenueCat stripped | `Models/AIProvider.swift` |
| P7a/b | Hybrid food lookup: 36 seed + 6,912 USDA + Open Food Facts + Gemini fallback | `Services/FoodDatabaseService.swift`, `OpenFoodFactsService.swift`, `Resources/usda-seed.json` |
| P8 | Free-signing config (bundle IDs, entitlements stripped) | `project.pbxproj`, `*.entitlements` |
| P9 | AltStore Source CI pipeline | `.github/workflows/build-ipa.yml`, `docs/source.json` |
| P11a | MacroFactor CSV import (3,806 entries supported) | `Services/MacroFactorCSVImporter.swift` |
| P11b | Custom tab bar + center FAB + Quick Add sheet | `Views/CustomTabBar.swift`, `Views/QuickAddSheet.swift` |
| Perf | FoodStore per-day index (O(1) lookups) | `Stores/FoodStore.swift` |

Pipeline is live. Every push to `main` → CI builds an unsigned IPA → publishes a GitHub Release → bumps `docs/source.json` → GitHub Pages serves the updated manifest at `https://edrickchang13.github.io/food/source.json` → AltStore on the phone offers an update within minutes.

## What we're building next — P12, MacroFactor UI parity

MacroFactor screenshots are at `~/Downloads/macrofactor-screens/IMG_64{55..81}.PNG` (26 PNGs, IMG_6471 missing on purpose). The plan and screen-by-screen analysis live in this conversation; if you don't have it, see "MacroFactor screen analysis" below.

**Phased plan:**

```
A. Foundation       — design tokens + 8 shared components
B. Dashboard        — horizontal pager + scrollable sections
C. Food Log         — hour timeline + Shortcuts sheet
D. Food Entry       — 5-tab sheet (Scan/Search/AI/Quick Add/Library)
E. Strategy         — countdown ring + Coached Program + Weight Goal
F. Goal/Program wizards
G. Bulk AI twist    — Stitch-assisted for divergent screens only
H. Polish + ship
```

A blocks all of B-F. G blocks H. B/C/D/E/F can run **fully in parallel** across forked chats because they touch disjoint file paths.

## Coordination rules for parallel forks

**One fork per phase.** Branch named `phase-X-<slug>` (e.g., `phase-b-dashboard`).

**File ownership** — no two phases touch the same file:

| Phase | Allowed paths (exclusive write) |
|---|---|
| A | `ios/calorietracker/Theme/**`, `ios/calorietracker/Components/**` |
| B | `ios/calorietracker/Views/Dashboard/**`, replaces `Views/HomeComponents.swift` |
| C | `ios/calorietracker/Views/FoodLog/**` |
| D | `ios/calorietracker/Views/FoodEntry/**` |
| E | `ios/calorietracker/Views/Strategy/**` |
| F | `ios/calorietracker/Views/Wizards/**` |
| G | per-screen, scoped to the divergent files only |
| H | scoped to whatever needs polishing |

**Shared files that everyone may touch (with extra care)** — `ContentView.swift` (tab routing), `calorietrackerApp.swift` (environment injection), `project.pbxproj` (only when adding folders; avoid concurrent edits). When two phases need to update one of these, the second to merge does the pbxproj edit.

**No phase pushes its branch to `main` until:**
1. `xcodebuild -project ios/calorietracker.xcodeproj -scheme calorietracker -destination 'generic/platform=iOS Simulator' build` succeeds locally
2. `swift test` in `ios/Packages/BulkAIEngine/` still passes (48 tests)
3. A `swift-reviewer` agent has reviewed the diff

**Merging order:** A → B/C/D/E/F (any order between these five) → G → H.

## Conventions you must respect

- **No `Co-Authored-By` trailer** in commit messages, ever (durable rule from user). See `~/.claude/projects/-Users-edrickchang/memory/feedback_commit_authorship.md`.
- **No em-dashes** in any user-facing copy or commit messages. Use hyphens or rewrite. See `feedback_writing_style.md`.
- **Push autonomy for this repo only:** after each phase commits cleanly, push without asking. See `feedback_food_repo_autonomy.md`. For any OTHER repo the user owns, push requires explicit chat approval.
- **macOS CI runner caps at Xcode 16.4 / Swift 6.0.** That means:
  - `Chart { ForEach(...) ; if let x = optional { ... } }` does not compile. Build with all marks unconditional and use `.opacity(0)` to hide.
  - Newer Swift Concurrency edge cases may fail remotely while passing locally. Test locally with `xcodebuild` before pushing.
- **No external dependencies beyond what's already in `Package.swift` and the iOS project.** The reason this repo can be free-signed is that we removed RevenueCat. Don't pull anything new in without thinking about App Group requirements.
- **Free signing forbids**: push notifications, app groups (so widgets are dead), iCloud, Sign in with Apple, HealthKit background delivery. The main `*.entitlements` has only `com.apple.developer.healthkit` declared.

## Where to find context if you're new

| What | Where |
|---|---|
| Original product spec | `PLAN.md` (in repo root) |
| Engine algorithm | `ios/Packages/BulkAIEngine/Sources/BulkAIEngine/` |
| Engine tests (golden values for engine math) | `ios/Packages/BulkAIEngine/Tests/BulkAIEngineTests/` |
| MacroFactor reference screenshots | `~/Downloads/macrofactor-screens/IMG_64*.PNG` |
| AltStore source manifest schema | `docs/source.json` |
| CI workflow | `.github/workflows/build-ipa.yml` |
| User's MacroFactor CSV (their actual food log) | `~/Documents/MacroFactor-20260513195315.csv` (3,806 entries) |
| User memory (durable preferences) | `~/.claude/projects/-Users-edrickchang/memory/` |

## MacroFactor screen analysis (26 screens, summarized)

**Dashboard (IMG_6455–6464):** Horizontal pager with 3 cards. Card 1 = Energy Balance bar chart with Expenditure/Targets segmented toggle, equation row "Nutrition − Targets = Difference". Card 3 = Daily Nutrition arc gauge with thin macro progress bars. Scrolled view = Insights & Analytics 2×2 grid (Expenditure brown sparkline, Weight Trend purple line, Energy Balance mini bars, Goal Progress green bar) → Habits with **GitHub-style contribution grids** for Weigh-In + Food Logging → Body Metrics → Nutrition 2×2 → General (Steps) → More.

**Food Log (IMG_6465, IMG_6472):** Day strip with status-ring chips, 4 thin macro progress pills with paging dots, vertical hour timeline (7 AM, 8 AM…) each with its own + button. Center FAB opens a **Shortcuts** bottom sheet with 4 circular icon buttons (AI/Weight/Search/Barcode) and a list (Your Foods/Quick Add/Metrics/Recipes).

**Food Entry sheet (IMG_6466–6470):** Header pill row (X / time / calorie ring / utensils / down). Scrollable top-tab row: Scan / Search / AI / Quick Add / Library / Describe. Scan has Barcode/Label sub-segment. AI has Snap/Describe. Quick Add is a manual macro form with live "Macro sum is X kcal" validation. Library has Recipes/Foods toggle + sort dropdown. Persistent bottom: small search field + "Log Foods" CTA.

**Strategy (IMG_6473–6475):** Big "STRATEGY" header collapsing on scroll. Horizontal action pill carousel (New Goal / Edit Goal / New Program / Edit Program / Change Check-In Day). Countdown ring ("5 DAYS until check-in"). Coached Program card with stacked weekday macro bar chart (blue cal / orange protein / yellow fat / green carbs). Weight Gain Goal card with 3 stats.

**Edit Goal wizard (IMG_6476–6478):** Progress-underline header. Derived stat tiles. **Ruler-style horizontal slider** for target weight. Segmented preset + continuous slider for rate. Live unit conversion (lbs / %BW × week/month). **Diff cards** ("175 lbs ›› 190 lbs"). Sticky white Done button.

**Set New Program wizard (IMG_6479–6481):** 2×3 preference grid. Generated weekday macro chart. **Numbered timeline with vertical connector line** explaining design rationale (Estimated Expenditure / Average Target / Target Protein / Diet Type).

## Components to extract (Phase A deliverable)

```
Theme/
  Tokens.swift          color, typography, spacing
  Surface.swift         card backgrounds, dividers

Components/
  ContributionGridView.swift     GitHub-style heatmap, configurable color
  MacroWeekChart.swift           7-column stacked bars w/ embedded labels
  CountdownRing.swift            circular progress + center label
  RulerSlider.swift              tick scrubber w/ tick labels
  NumberedTimeline.swift         vertical connected numbered steps
  DiffRowCard.swift              "old ›› new" diff cell
  ThinProgressBar.swift          track + tick marker, no fill
  InsightCard.swift              icon + sparkline + big number + chevron
  PillTabBar.swift               scrollable horizontal segmented row
  SegmentedToggle.swift          MacroFactor's white-pill-on-dark style
```

## Twist from MacroFactor (Bulk AI's positioning)

1. Engine math visible: show the actual energy-balance equation with live numbers
2. Coral as primary accent (vs. MacroFactor's blue)
3. Adherence-neutral copy throughout
4. Simpler defaults; advanced behind a single pill
5. Free-signing-honest: small badge somewhere explaining the AltStore refresh model

## Anti-patterns we have already learned

- **`UserDefaults` JSON for big collections is slow** — FoodStore.entries with 3,806 items froze the Progress tab. Fixed with `dayIndex`. Next time someone hits this, the right answer is SwiftData, not another in-memory index.
- **`Calendar.isDate(_:inSameDayAs:)` in a hot loop** — same crash, same fix.
- **Two pushes within 2 minutes** can race the source.json bump. CI has a retry-with-rebase loop now but don't push two phases at once unless you stagger by 5+ min.
- **`ForEach` + conditional inside `Chart {}`** — won't compile under Xcode 16.4. Use always-unconditional marks gated by opacity instead.

## How to start a new chat picking up Phase X

Paste this into a fresh Claude Code chat in `~/food`:

> I am picking up Phase **{A | B | C | D | E | F | G | H}** of the Bulk AI project. Read `docs/HANDOFF.md` end-to-end, then read the matching phase section in the conversation history of the parent fork (or ask the user to paste it). Create a branch `phase-{slug}` from main. Implement the phase per the plan. Build locally with `xcodebuild` after each change; do not push until the build is green and any other phase's branch you depend on (Phase A for most) has merged to main. After your build passes, run `swift test` in `ios/Packages/BulkAIEngine/` to confirm the 48 engine tests still pass. Then push the branch, open a PR, and tell the user when ready for merge. Do not edit files outside this phase's `Allowed paths` from `HANDOFF.md`. Respect `feedback_commit_authorship.md` and `feedback_writing_style.md` — no `Co-Authored-By`, no em-dashes.
