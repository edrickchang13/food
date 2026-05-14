# Phase G — Bulk AI twist (Stitch-assisted divergent screens)

**Blocked by B, C, D, E, F all merged.** This is where Bulk AI stops being a MacroFactor clone.

## Branch

`phase-g-twist`

## Allowed paths

- `ios/calorietracker/Views/Engine/**` (new directory for engine-distinctive screens)
- Modifying copy strings in any existing view to enforce adherence-neutrality
- Replacing the app icon assets

## Stitch usage — this is the one phase where Stitch helps

For the screens listed below, use [stitch.withgoogle.com](https://stitch.withgoogle.com/) to generate 2-3 visual directions for each, pick the one that matches Bulk AI's coral accent / engine-forward identity, then translate to SwiftUI using Phase A's design tokens. Don't use Stitch for screens whose look we already decided (MacroFactor clones from B-F).

## Divergent screens

### 1. DynamicTDEEExplainer

Bulk AI's pitch: the math is visible. Build a screen that shows the literal energy-balance equation with current numbers plugged in:

```
expenditure  =  avg intake  -  (trend Δ × 7700)  /  window days
   2,873           2,500         (-0.4 × 7700)        14
```

Each variable is tappable to drill into "what this means."

Accessible from: Dashboard insights row + Settings -> Engine debug.

### 2. WeeklyCheckInProposal (already exists, needs adherence-neutral pass)

Existing `CheckInReviewView.swift` works functionally but copy needs review:
- Replace anything resembling "you went over" / "you fell short" with trend-neutral phrasing
- Show the math change, not the behavior change

### 3. FreeSigningStatus

Small badge somewhere (Settings -> About or a banner on app launch) that explains:
"Bulk AI runs from your own Apple ID via AltStore. The certificate refreshes every 7 days automatically when your phone and Mac are on the same Wi-Fi."

Plus a "Last refreshed: 2026-05-13" timestamp.

### 4. FoodDatabaseBrowser (already exists, slight visual refresh)

Current `FoodDatabaseView` is functional. Run it through Stitch for a fresher look that mixes the 36-seed + 6,912 USDA + Open Food Facts entries more clearly.

### 5. EngineProgramModeIntro

The first time a user opens Settings -> Coaching mode, show a one-time explainer of Coached / Collaborative / Manual. Stitch this directly - no MacroFactor analog.

## Bulk AI identity changes (no Stitch needed)

- **Accent color:** coral (`#FF6B6B`) for all primary CTAs and toggle states. MacroFactor's blue is reserved for the calorie macro only.
- **Tab bar selected state:** coral on selected, gray on others (already shipped).
- **App icon:** new icon at `Assets.xcassets/AppIcon.appiconset/`. Either generate via Stitch (good fit) or commission a simple coral broccoli that's visually distinct from Fud AI's.
- **Copy throughout:** replace any user-facing string referencing "Fud AI" or "Cal AI" if any remain after Phase 4. Replace adherence-anchored verbs ("complete", "hit", "miss") with neutral ones ("logged", "trending", "Δ").

## Definition of done

1. The five divergent screens render with Bulk AI's coral accent + adherence-neutral copy
2. A11y check passes for the new screens (Phase A tokens already pass contrast)
3. No remaining "Fud AI" or "Cal AI" strings anywhere in the user-facing app
4. App icon is the new Bulk AI one
5. `xcodebuild` + `swift test` green
