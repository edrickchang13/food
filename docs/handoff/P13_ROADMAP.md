# P13+ Roadmap

P12 closed out the MacroFactor-parity surface plus the Bulk AI identity
divergence. What's left falls into seven candidate phases. I've sorted them
roughly by leverage (top = highest user-visible impact per agent-hour).

Each phase entry includes: scope, parallel-agent split, blocking dependencies,
and definition of done.

---

## P13 — Engine debouncing + search index (carryovers from H)

**Scope:** Two performance items the H agent flagged as "deferred — needs API
change":

1. `EngineState.refresh()` debouncing. A batch import (CSV, HealthKit sync)
   currently fires `refresh()` per entry; for 1000 imports that's 1000 full
   recomputes. Debounce with a 250ms trailing window via a `Task` cancellation
   pattern.
2. `FoodDatabaseService.allItems` sorted-cache. The 6,912-row USDA search
   re-scans the whole array each keystroke; cache a prefix-sorted index built
   on first search.

**Parallel agents:** 2 (engine debouncer + search-index)
**Blocks:** Nothing — pure perf work
**DoD:** Instruments shows engine `refresh()` drops from 1000 calls to ≤4 on a
1000-row import; search-index lookups for a 3-char prefix drop from O(N) to
O(log N) average.

---

## P14 — Real favorites + per-slot picks (replaces Phase D placeholders)

**Scope:** The Food Entry sheet has two placeholders called out in
`FoodEntrySheet.swift`:

- `filteredFavorites` — currently returns a head of the seed DB.
- `filteredSuggestions` — currently returns the seed head regardless of time
  slot.

Make both real:

1. Add a `FavoritesStore` (mirroring `WeightStore`'s shape) backed by
   UserDefaults. Plus/heart toggles on `FoodSearchRow` and `FavoriteAvatar`
   write through it.
2. Per-slot picks: derive from the user's own log history grouped by hour. For
   a 9 AM picker, surface foods most often logged 7–11 AM in the last 30 days.

**Parallel agents:** 2 (FavoritesStore + per-slot history aggregator)
**Blocks:** Nothing
**DoD:** Tapping the heart on a row persists the favorite across launches; the
Picks section shows real time-of-day suggestions for users with ≥7 days of
logs.

---

## P15 — HealthKit + Steps wiring

**Scope:** The Dashboard's `GeneralSection` currently hardcodes `stepsHistory:
[3200, 2100, 4500, 1800, 2800, 3600, 2400]`. Wire HealthKit:

1. Request `HKQuantityType.stepCount` permission in onboarding (the manifest
   already declares the permission per `P12`).
2. Read the last 7 days of steps; pass into `GeneralSection.stepsHistory` and
   `stepsValue`.
3. Optionally read body-mass + body-fat from HealthKit on app foreground; merge
   into `WeightStore` and `BodyFatStore` with dedup by date.

**Parallel agents:** 1 (HealthKit reader is one tight surface; not worth
splitting)
**Blocks:** Nothing
**DoD:** A user with HealthKit data sees real step counts on the Dashboard;
opting out via Settings shows a "Connect Apple Health" CTA in place of the
sparkline.

---

## P16 — Voice-first food entry

**Scope:** The AIView and DescribeView already accept text. The voice path
exists in `VoiceInputView` but lives behind a sheet. The Phase D refactor
deferred voice as a first-class tab. Promote voice to a top-level Food Entry
tab between Search and AI:

1. Move `VoiceInputView` into `Views/FoodEntry/Tabs/VoiceView.swift`.
2. Wire it through the same Gemini parsing pipeline as DescribeView's submit.
3. Add a small "Hold to talk" affordance on the FoodEntrySheet bottom bar so
   the user can dictate without leaving the current tab.

**Parallel agents:** 1
**Blocks:** Nothing
**DoD:** Voice tab logs a meal with one tap → speak → Done; the bottom-bar
hold-to-talk is reachable from every tab.

---

## P17 — Widgets + Live Activities

**Scope:** The repo has `FudAIWidgets` as a placeholder target. Build out:

1. A medium widget showing "X / Y kcal" + the day's macro ring.
2. A small widget showing the next check-in countdown.
3. A Live Activity that pins the same kcal ring to the lock screen during the
   day, updating each time the user logs.

**Parallel agents:** 3 (one per widget type) — widget extensions are isolated
targets, parallel-safe.
**Blocks:** Nothing
**DoD:** Both widgets render on the home screen with real `FoodStore` data;
Live Activity starts on first log of the day and dismisses at midnight.

---

## P18 — Onboarding rewrite

**Scope:** `Views/OnboardingView.swift` predates Phase A. It uses the old
`AppColors` palette, not BulkAITheme. Rewrite to match the rest of the app:

1. Pull all onboarding screens into `Views/Onboarding/` (matching the
   per-feature folder pattern).
2. Apply BulkAITheme tokens.
3. Move the program-mode picker step in front of the goal-rate step so the
   user picks coaching mode *before* committing to a rate.
4. Show the Phase G `EngineProgramModeIntro` automatically during onboarding,
   not just on first Settings open.

**Parallel agents:** 2 (refactor + reorder)
**Blocks:** Phase G Stitch (EngineProgramModeIntro lands first)
**DoD:** Fresh install runs the new onboarding end-to-end with theme tokens.

---

## P19 — Open-source pipeline

**Scope:** Repo is private (`edrickchang13/food`) but the app is positioned as
open source (per the AI consent sheet: "Free, open source, and your data stays
on your device"). Run the `opensource-pipeline` skill:

1. `opensource-forker` strips secrets, generates `.env.example`.
2. `opensource-sanitizer` scans for leaked keys / internal references / PII.
3. `opensource-packager` writes `CLAUDE.md`, `setup.sh`, `README.md`,
   `LICENSE`, `CONTRIBUTING.md`, GitHub issue templates.

Publish to a separate public repo.

**Parallel agents:** 3 (one per pipeline stage, sequential by design)
**Blocks:** Nothing — but ideally run after Phase G Stitch and P15 land so the
public README screenshots show the integrated product.
**DoD:** A clean clone of the public repo runs `setup.sh` and builds.

---

## Suggested order

If we batch by leverage:

1. **P13 (perf carryovers)** — finishes the P12 quality bar
2. **G-Stitch (Phase G held items)** — when you have the Stitch direction
3. **P14 (real favorites)** — closes the biggest Phase D placeholder
4. **P15 (HealthKit + Steps)** — biggest "feels real" win for the Dashboard
5. **P16 (Voice-first entry)** — pulls the AI pitch front-and-center
6. **P17 (Widgets + Live Activities)** — distribution hook for App Store
7. **P18 (Onboarding rewrite)** — last because EngineProgramModeIntro from
   G-Stitch is its dependency
8. **P19 (Open-source pipeline)** — last because each prior phase changes the
   integrated tree and you'd repeat the sanitizer pass

If we batch by parallel-agent budget, every phase except P15/P16 supports
≥2 parallel agents.
