# Stitch Direction Briefs — Phase G held items

Two Phase G screens are held until we have a real design direction. Both want
2–3 Stitch passes, a pick, then a SwiftUI translation against the Phase A
design tokens.

Stitch URL: <https://stitch.withgoogle.com/>

For each brief: paste the prompt verbatim into Stitch, generate 2–3 directions,
save the chosen direction as PNG/SVG into `docs/stitch/<brief>/`, then ask the
assistant to translate to SwiftUI.

---

## 1. FoodDatabaseBrowser visual refresh

### Context

We already have a functional `Views/FoodDatabaseView.swift` that browses the
36-row Bulk AI seed + 6,912-row USDA seed + a small AI-cached set + Open Food
Facts hits. It's a list with rows that show name + macros.

It works. It looks like every other database browser. The Phase G pitch is to
make the *data sourcing* visible — the user should feel that they're looking at
three layered indexes, not one undifferentiated list.

### Mood

- Editorial / archive — think Are.na or the NY Times datavis archive
- Type-led, low chrome
- Each source has its own visual identity (color tag, density, layout
  treatment)
- Dark theme, coral accent (`#FF6B6B`) used sparingly

### Stitch prompt

> Design a food database browser for an iOS calorie tracker. Three sections,
> each with its own visual identity:
>
> **Section 1: Verified (USDA-sourced)** — dense, monospaced, archive feel.
> ~6,000 entries. Each row shows the food name + macros + a small green seal
> indicating verification. Treat this section like a research index.
>
> **Section 2: Curated (Bulk AI seed)** — sparser, larger type, with a small
> hand-illustrated produce icon next to each row. ~36 entries. The 36 are
> hand-picked staples (chicken breast, rolled oats, etc.) that the engine uses
> as fallback when the user hasn't logged anything yet. Treat this section
> like a chef's mise-en-place.
>
> **Section 3: AI-estimated** — soft, watercolor-tinted, lower confidence
> signal. ~variable count. Foods that fell through both indexes and were
> filled in by Gemini. Show a sparkles icon and a small "AI estimate"
> disclosure.
>
> Top of screen: a single search bar that searches across all three. Results
> for the active query stay in their source's section — never collapse into a
> single ranked list.
>
> Dark background `#0F0F10`. Coral accent `#FF6B6B`. Macro colors per category:
> protein coral `#E36B5E`, fat yellow `#E8C547`, carbs green `#5BC98B`, calorie
> blue `#4C9AFF`.

### Output

Save chosen screen to `docs/stitch/food-database-browser/chosen.png`. Then ask:

> Translate `docs/stitch/food-database-browser/chosen.png` into SwiftUI at
> `ios/calorietracker/Views/FoodDatabaseView.swift`, replacing the existing
> implementation. Keep the underlying data access through
> `FoodDatabaseService.search(...)` and `FoodDatabaseService.searchIncludingRemote(...)`.
> Use Phase A tokens (`BulkAITheme.*`). Verify with the iPhone 17 simulator
> xcodebuild.

---

## 2. EngineProgramModeIntro (first-time explainer)

### Context

The app has three coaching modes — Coached, Collaborative, Manual. The user
picks one once and never sees it again. Currently the picker lives buried in
Settings with no explainer; users either pick the default (Coached) or hit
the picker confused.

Phase G says: surface a one-time full-screen explainer the first time the user
opens Settings → Coaching mode, with three cards explaining each mode side by
side. This is the screen where Bulk AI's identity lands hardest — we're
explicit about the spectrum from "engine drives" to "you drive".

### Mood

- Onboarding-quality polish — first impression
- Three cards arranged vertically, not horizontally (we want each card to
  breathe with body copy below)
- Each card has its own accent color and a small custom illustration / shape
  representing the mode
- Bottom-pinned CTA: "Got it" (white pill, black text)

### Stitch prompt

> Design a first-time explainer screen for an iOS calorie tracker that
> introduces three coaching modes. Full-screen modal, dark background
> `#0F0F10`. Title at top: "How would you like Bulk AI to coach you?"
>
> Below the title, three cards stacked vertically. Each card has:
> - A custom geometric illustration on the left (no SF Symbols — original
>   shapes per mode)
> - A title in large rounded type
> - A 2-sentence body in muted body type
> - An accent stripe down the left edge in the mode's color
>
> Card 1: **Coached** — accent green `#5BC98B`. Illustration: an arrow being
> guided by a glowing dot, suggesting hand-holding. Body: "Bulk AI watches
> your intake and weight trend, then sets calories and macros for you every
> week. You eat to the targets. Best for people who want the math handled."
>
> Card 2: **Collaborative** — accent coral `#FF6B6B`. Illustration: two
> interlocking arrows, one short and one long. Body: "Bulk AI proposes new
> targets; you accept, adjust, or skip each week. Best for people who want
> data-driven suggestions but the final call."
>
> Card 3: **Manual** — accent blue `#4C9AFF`. Illustration: a single hand-drawn
> dial. Body: "You set your own calorie and macro targets. Bulk AI tracks the
> math in the background and shows it on the Strategy tab. Best for experienced
> trackers who already have a plan."
>
> Bottom of screen: a white pill button with black text "Got it" pinned 24pt
> above the safe area. The selected mode highlights — tapping a card pre-
> selects that mode but doesn't dismiss; only "Got it" dismisses.
>
> Show the screen at 6.7-inch iPhone proportions. Include a subtle 1pt stroke
> around each card in the mode's color at 25% opacity when unselected, 100%
> when selected.

### Output

Save chosen screen to `docs/stitch/engine-program-mode-intro/chosen.png`. Then
ask:

> Translate `docs/stitch/engine-program-mode-intro/chosen.png` into SwiftUI
> at `ios/calorietracker/Views/Engine/EngineProgramModeIntro.swift`. Present
> from `Settings → Coaching mode` (the picker in `ContentView.swift` Profile
> section) on first tap only — gate behind
> `@AppStorage("hasSeenProgramModeIntro")`. On dismiss, write the chosen mode
> to `engineState.programMode`. Use Phase A tokens. Verify build.

---

## When you have both

Once both Stitch directions are picked and saved, run a single follow-up:

> Translate the two saved Stitch screens (`docs/stitch/food-database-browser/`
> and `docs/stitch/engine-program-mode-intro/`) into SwiftUI on a new
> `phase-g-twist-stitch` branch. Build verify, open PR.

I'll spawn 2 parallel agents (one per screen) and ship them as PR #6.
