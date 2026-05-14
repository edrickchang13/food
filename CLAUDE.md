# CLAUDE.md — Bulk AI iOS project

This file briefs Claude Code (or any LLM contributor) on how this repo
expects work to be done. Read it before starting any task.

## Working principle: spin as many parallel agents as possible (always)

**Default to maximum parallelism on every task.** Before doing any
implementation yourself, ask: "Can this be split into N disjoint slices
and handed to N agents in one dispatch?" If yes, do that. Sequential
work — including sequential agent work — is the exception, not the
default.

When you receive a request:

1. Decompose the work into the smallest disjoint slices possible — one slice
   per agent.
2. Each slice should touch a non-overlapping set of files so the agents
   don't race on edits or builds.
3. Dispatch all agents in a single tool-call block so they run concurrently,
   not one after the other.
4. Tell each agent to **skip `xcodebuild`** as part of its turn — the
   orchestrator (you) runs one integration build after all agents return.
   Concurrent xcodebuild invocations fight over DerivedData.
5. After all agents return, do the integration work yourself: env injection,
   bundle registration, hook-up of new components into existing parents.

Concrete shapes that have worked in this project:

- **5-tab Food Entry sheet** → 4 parallel agents (Search+Library = list,
  AI+Scan = camera, Quick Add + Describe = form, Header + Floating Bottom
  Bar = shared chrome).
- **Strategy tab** → 2 agents (Countdown ring + Action pills,
  Coached-program card + Weight-goal card).
- **Wizards** → 2 agents (Edit Goal flow, Set Program flow).
- **Phase H polish** → 2 agents in parallel (a11y-architect +
  performance-optimizer).
- **Wave-1 follow-up** → 6 agents in parallel (P14 favorites store, P14
  per-slot picks, P15 HealthKit steps, P17 medium widget, P17 small
  widget, P17 Live Activity).
- **Open-source pipeline** → 3 sequential agents (forker → sanitizer →
  packager) — sequential only because the sanitizer reads what the forker
  wrote and the packager reads what the sanitizer verified.

If a phase decomposes into ≥2 truly independent slices, **always** fan out.
A single-agent phase is acceptable only when the work is inherently
sequential or smaller than ~150 lines.

## Other working agreements

- **Merges to main require explicit per-PR approval** in the chat from the
  user. Never batch merges. Local commits, branches, and pushes to feature
  branches don't need confirmation.
- **Never add Claude as a commit co-author.** Drop the `Co-Authored-By`
  trailer entirely. Commit attribution is disabled globally.
- **Push after each phase + continue to the next phase without asking.**
  This is repo-specific; overrides the global push-with-permission rule.
- **No em-dashes anywhere in user-facing copy** the user might paste to
  teammates. Plain conversational tone.

## Project layout (one-pager)

```
ios/
├── calorietracker/                      main app target
│   ├── Components/                      shared SwiftUI primitives + tokens
│   │   ├── CountdownRing.swift
│   │   ├── ContributionGridView.swift
│   │   ├── DiffRowCard.swift
│   │   ├── InsightCard.swift
│   │   ├── MacroWeekChart.swift
│   │   ├── NumberedTimeline.swift
│   │   ├── PillTabBar.swift
│   │   ├── RulerSlider.swift
│   │   └── SegmentedToggle.swift
│   ├── Engine/
│   │   ├── EngineState.swift            adapter over BulkAIEngine package
│   │   ├── CheckInReviewView.swift      weekly check-in screen
│   │   └── EngineDebugView.swift
│   ├── Models/                          UserProfile, FoodEntry, etc.
│   ├── Services/                        FoodDatabaseService, GeminiService,
│   │                                    StepReader, CountdownSnapshotWriter
│   ├── Stores/                          FoodStore, WeightStore, BodyFatStore,
│   │                                    FavoritesStore, ProfileStore,
│   │                                    HealthKitManager, ChatStore
│   ├── Theme/
│   │   └── Tokens.swift                 BulkAITheme.Color / Spacing / Typography
│   └── Views/
│       ├── Dashboard/                   home tab
│       ├── FoodLog/                     food-log tab
│       ├── FoodEntry/                   6-tab food-entry sheet
│       │   └── Tabs/
│       │       ├── SearchView.swift
│       │       ├── VoiceView.swift
│       │       ├── AIView.swift
│       │       ├── ScanView.swift
│       │       ├── QuickAddView.swift
│       │       └── LibraryView.swift
│       ├── Strategy/                    Strategy tab + wizards' parent
│       ├── Wizards/                     Edit Goal + Set Program flows
│       ├── Engine/                      DynamicTDEEExplainer
│       ├── About/                       FreeSigningStatusView
│       └── ContentView.swift            tabs + Settings (giant file, mostly
│                                        ProfileView's form rows)
├── calorietrackerTests/                 unit tests (Swift Testing)
├── calorietrackerUITests/               XCUITest harness
├── FudAIWidgets/                        widget extension + Live Activity
└── Packages/
    └── BulkAIEngine/                    pure-Swift engine math package
```

## Build commands

```
# Build for iPhone 17 simulator (iOS 26.2 — match locally installed runtime)
xcodebuild -project ios/calorietracker.xcodeproj -scheme calorietracker \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -configuration Debug -quiet -skipMacroValidation build

# Run all unit tests
xcodebuild test -project ios/calorietracker.xcodeproj -scheme calorietracker \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -only-testing:calorietrackerTests -quiet -skipMacroValidation

# Run all UI tests (DashboardCallbacksTests, etc.)
xcodebuild test -project ios/calorietracker.xcodeproj -scheme calorietracker \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -only-testing:calorietrackerUITests -quiet -skipMacroValidation
```

When verifying a parallel-agent batch, run **one** build at the end —
never let each agent run its own build.

## Phase briefs

The full phase-by-phase plan lives in `docs/handoff/PHASE_A.md` through
`PHASE_H.md`. Each brief includes the architecture, the file layout, the
parallel-agent split, and the definition of done. New phases that follow
this pattern should add a `PHASE_*.md` of their own.

The future-phase roadmap is in `docs/handoff/P13_ROADMAP.md`.

Stitch design briefs (for the few visual designs that need design-tool
output before implementation) live in `docs/handoff/STITCH_BRIEFS.md`.

## Design tokens

Everything visual uses `BulkAITheme.Color`, `BulkAITheme.Spacing`,
`BulkAITheme.Typography`, and `BulkAITheme.Radius` from `Theme/Tokens.swift`.
Never hardcode hex colors or px values in a new component. The widget
extension can't import the main app's tokens — if you're working in
`ios/FudAIWidgets/`, define `fileprivate Color(hex:)` helpers inline (the
existing widgets do this).

## Coding conventions

- Swift 6 strict concurrency. `let` over `var` unless the compiler demands
  `var` (`@State` and `@Binding` properties are the common exception).
- File-size soft cap: 400 lines. Hard cap: 800.
- Function soft cap: 50 lines.
- Use file-system-synchronized Xcode groups — any `.swift` file under a
  target's source dir is automatically a member; you don't edit
  `project.pbxproj` to add files.
- Doc-comment shape: read `Components/CountdownRing.swift` or
  `Components/MacroWeekChart.swift` for the voice. Three to ten lines, plus
  inline section markers `// MARK: - <name>` for sub-views.

## Engine math

The expenditure / weight-trend / target-macros math lives in the
`BulkAIEngine` Swift package at `ios/Packages/BulkAIEngine/`. Treat that
package as the authoritative engine; the app's `EngineState.swift` is a
thin adapter that converts between app stores and engine inputs. Don't
duplicate engine math in the main app.
