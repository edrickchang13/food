# Bulk AI — Plan

Forked from [apoorvdarshan/fud-ai](https://github.com/apoorvdarshan/fud-ai) (MIT). This document is the working plan, not marketing copy — written for the two people building this. App is iOS-only, named **Bulk AI**.

## 1. Strategy

We keep Fud AI's commodity layer (SwiftUI shell, HealthKit plumbing, AI food parsing, widgets, food log UI). We replace the coaching engine — that's the IP. The engine difference:

| | Fud AI today | Us |
|---|---|---|
| TDEE | Mifflin-St Jeor × activity multiplier, static after onboarding | Deterministic from energy-balance equation, updates weekly from observed intake + smoothed weight |
| Weight signal | Raw log + chart | EWMA trend weight with linear interpolation for missing days |
| Weekly cadence | None | Check-in prompts a proposed plan; user accepts |
| Coaching mode | Single mode | Coached / Collaborative / Manual |
| Adherence | "Forecast" framing | Adherence-neutral; no day-to-day compensation |

iOS only. Android directory stays in the tree but unmaintained until we choose to revisit. License stays MIT; we preserve the original copyright and add our own copyright line for the fork.

## 2. What we keep (and lightly rename)

- `ios/calorietracker/` Xcode project — the whole SwiftUI app shell
- `Stores/HealthKitManager.swift` — bidirectional Apple Health sync, 12 nutrition types
- `Stores/FoodStore.swift`, `Models/FoodEntry.swift` — food log persistence
- `Services/GeminiService.swift` — keep. **Narrow to Gemini-only:** strip the other 12 providers + the Fud AI Plus paid proxy. Onboarding ships a deep link to [aistudio.google.com/apikey](https://aistudio.google.com/apikey) for a free key.
- `Services/CloudKitService.swift` — private CloudKit DB for cross-device, end-to-end encrypted (already there, satisfies "heavily encrypted" PRD mandate)
- `Stores/WeightStore.swift` — keep as raw log, **add** a separate `WeightTrendService` for the EWMA layer
- Widgets target (`ios/FudAIWidgets/`)
- Onboarding scaffolding in `Views/OnboardingView.swift` — keep flow, replace target-calculation step
- Localization (15 languages) — leave in place

## 3. What we replace

| File | What it does today | What we do |
|---|---|---|
| `Models/UserProfile.swift` | Stores BMR / activity multiplier / static TDEE | Add: program mode, weekly target rate-of-change, lean mass estimate, last check-in date, accepted plan history |
| `Services/WeightAnalysisService.swift` | Thermodynamic forecast (forward-looking) | Replace with backward-looking `ExpenditureService` (the actual MacroFactor-style estimator) |
| `Views/CalculationMethodsView.swift` | Explains BMR×activity | Rewrite to explain the dynamic model + show user their current expenditure estimate |
| `Views/OnboardingView.swift` (target step) | Picks calorie target from formula | Picks goal direction + rate; engine handles the rest |
| `Services/CoachTools.swift` | LLM context for the chat coach | Add the new metrics (trend weight, dynamic TDEE, weekly delta) into the prompt context |

## 4. What we add

New Swift Package at `ios/Packages/BulkAIEngine/` (pure-Swift, no UIKit/SwiftUI dependency — testable from the command line via `swift test`):

- `WeightTrend.swift` — EWMA trend weight, linear interpolation for gaps
- `Expenditure.swift` — dynamic TDEE from energy-balance equation, guardrails
- `TargetMacros.swift` — protein from lean mass, fat floor, carb remainder
- `WeeklyCheckIn.swift` — weekly trigger, proposed-plan generation, accept/reject
- `ProgramMode.swift` — Coached / Collaborative / Manual switch with the policies for each

The main app consumes `BulkAIEngine` as a local package dependency. This keeps the IP isolated, testable headlessly, and portable if we ever do Android.

New stores:

- `Stores/CheckInStore.swift` — history of weekly check-ins, accepted plans
- `Stores/PeriodStore.swift` — menstrual cycle log (privacy-sensitive, on-device only)
- `Stores/MeasurementStore.swift` — 24 body measurements over time (necks/waists/etc.)
- `Stores/ProgressPhotoStore.swift` — front/back/side, encrypted at rest, linked to date+weight

New views (deferred to later phases):

- Weekly check-in flow
- Recipe creator + URL importer (P3)
- Period tracking (P3)
- Photo gallery (P3)

## 5. The Algorithm Engine

### 5.1 Weight Trend (EWMA)

Input: `[WeightLog(date, kg)]` sorted ascending.

Step 1: Fill missing days with linear interpolation between bracketing logs. Leading/trailing missing days are not interpolated (no extrapolation).

Step 2: Apply EWMA. `trend[t] = α * weight[t] + (1 - α) * trend[t-1]`, with `trend[0] = weight[0]`.

Default `α = 0.1` (≈10-day half-life). Expose as advanced setting; do not show in onboarding.

Output: `[TrendPoint(date, kg)]` for charting + a single `currentTrend` value for the engine.

### 5.2 Dynamic Expenditure

Input: a rolling window (default 14 days) of `kcalIn[]` and `trendKg[]`.

Formula: `expenditure = avg(kcalIn) - (trendChangeKg * kcalPerKg) / days`, where `kcalPerKg = 7700` (≈3500 kcal/lb, standard).

Confidence gate: require ≥4 food logs and ≥3 weight logs in the window. Below threshold, return the prior expenditure unchanged and surface `confidence = .low`.

Guardrails:
- Single weekly update cannot move expenditure more than ±15% from prior estimate
- Hard floor: never below `1.1 × BMR` (Mifflin-St Jeor)
- Hard ceiling: never above `2.5 × BMR`
- First 7 days of use: use onboarding estimate, do not run dynamic calc yet

### 5.3 Calorie Target

Input: chosen `Goal ∈ {lose, maintain, gain}` and `weeklyRatePctBodyweight` (e.g., 0.5% per week).

`weeklyDeltaKcal = currentTrendKg * weeklyRatePctBodyweight * 7700`
`dailyAdjustment = weeklyDeltaKcal / 7`
`dailyCalorieTarget = expenditure ± dailyAdjustment` (sign by goal)

Safety floor: `max(dailyCalorieTarget, fatFloorKcal + proteinKcal + 50)` — never drop the carb budget negative.

### 5.4 Macro Distribution

Lean body mass (LBM): if body fat % is logged, `LBM = weight * (1 - bodyfat%)`. Otherwise estimate `LBM = weight * 0.85` for sedentary, `0.90` for active (rough; refine later).

- **Protein:** `g/day = 2.0 * LBM_kg` for lose/maintain, `1.8 * LBM_kg` for gain. (Scales with LBM, not total weight.)
- **Fat floor:** `g/day ≥ 0.6 * weight_kg`. Below this, recompute target to honor the floor.
- **Carbs:** remainder of the calorie budget after protein + fat.

### 5.5 Weekly Check-In

Trigger: 7 days since last accepted plan, OR onboarding completed 7+ days ago and no check-in yet.

Flow:
1. Show user: previous week's avg intake, trend weight delta, recomputed expenditure, proposed new targets (calorie + macros).
2. User taps Accept → new plan effective immediately; previous plan archived.
3. User taps Adjust → opens manual override (rate-of-change slider + macro pins).
4. User taps Skip → keep current plan, next prompt in 7 days.

Adherence-neutrality: the check-in NEVER references "you went over on Tuesday" or "you under-ate by X". It references trend weight and average intake only.

### 5.6 Program Modes

| Mode | Targets | Weekly check-in | Macros |
|---|---|---|---|
| **Coached** | Engine sets all | Auto-prompts; user accepts | Engine sets all |
| **Collaborative** | Engine sets weekly budget; user distributes across days | Auto-prompts; user accepts new budget | Engine sets daily macros from each day's calorie share |
| **Manual** | User sets everything | No prompt; expenditure tracked silently in background | User sets all |

## 6. Phase Plan

Each phase ends with something testable on-device.

**P0 — Engine + tests (this session).** Implement the five engine files above with XCTest unit tests. Pure-Swift, no UI dependencies. Property-based tests for EWMA (deterministic, no rounding drift) and golden-value tests for the expenditure formula. Estimated: ~600 lines incl. tests.

**P1 — Wire engine to existing onboarding + dashboard.** New onboarding step picks goal + rate. Engine writes targets to `ProfileStore`. Dashboard reads `currentTrend`, `expenditure`, `dailyTarget` from engine. Existing food logging untouched.

**P2 — Weekly check-in UI.** Card on dashboard when check-in is due. Full review screen with accept/adjust/skip.

**P3 — Program modes + advanced features.** Mode switcher in settings. Recipe creator. URL recipe importer. Period tracker. Body measurements. Progress photos.

**P4 — Polish.** Custom dashboard widgets, micronutrient pinning, theme cleanup, rename app from "Fud AI" to whatever we decide.

## 7. Decisions & Open Questions

**Resolved:**
1. **App name:** Bulk AI.
2. **AI providers:** Gemini-only. User supplies a free key from aistudio.google.com/apikey. Strip the other 12 providers + the Fud AI Plus proxy.
3. **Food database:** Hybrid — local structured DB (cache + verified seed) + Gemini for parsing and gap-filling.
   - Seed: bundled USDA FoodData Central SR Legacy subset (Foundation Foods + common items, ~30MB SQLite).
   - Lookup flow: local DB first → Gemini fallback for free-text or missing items → cache LLM results into local DB, tagged `source = .aiEstimated`.
   - Raw/cooked conversion: only available for seed entries (verified yields); LLM-cached entries don't get conversion until upgraded.
   - This is real work, scheduled for **P3**. P0/P1/P2 keep Fud AI's LLM-only lookup; the engine doesn't care where calories come from.

**Still open:**
4. **Backend.** Confirming: no separate backend, no accounts. CloudKit private DB only. (If you want a backend later for shared recipes etc., that's a separate decision.)
5. **EWMA α.** Default 0.1 (~10-day half-life). MacroFactor uses something close. Revisit after we have a few weeks of real data.
6. **"Bulk AI" name positioning.** Skews bulking; the algorithm is goal-neutral. Worth checking trademarks before committing for App Store submission. Not a P0 blocker.

## 8. License & Attribution

- `LICENSE` (MIT, © 2026 Apoorv Darshan) stays unchanged at root.
- Add a `NOTICE.md` describing the fork and our changes.
- README will be rewritten in P1 but will keep an "Originally forked from Fud AI" line and link upstream.
- `upstream` remote stays wired so we can pull bug fixes from Fud AI if we choose.
