# Phase F — Goal + Program wizards

**Blocked by Phase A.** Runs in parallel with B, C, D, E.

## Branch

`phase-f-wizards`

## Allowed paths

- `ios/calorietracker/Views/Wizards/**` (new directory)

## Reference screens

`IMG_6476` (Edit Goal step 1), `IMG_6477` (Edit Goal review), `IMG_6478` (Edit Goal review scrolled), `IMG_6479` (Set Program step 1), `IMG_6480` (Set Program step 2), `IMG_6481` (Set Program rationale scrolled).

## Architecture

Two separate wizards:

### Edit Goal Wizard

```
EditGoalFlow
├── Step1: WeightAndRate          (IMG_6476)
│   ├── derived stat tiles        Initial Daily Budget + Projected End Date
│   ├── RulerSlider                target weight
│   └── SegmentedToggle + Slider  rate (Standard / Custom)
└── Step2: ReviewDiff             (IMG_6477, 6478)
    ├── DiffRowCard               Weight Gain: 175 lbs >> 190 lbs
    └── DiffRowCard               Goal Rate: unchanged or new value
sticky white "Next" / "Done" button at bottom
```

### Set New Program Wizard

```
SetProgramFlow
├── Step1: PreferenceGrid         (IMG_6479)
│   └── 2x3 grid of cards         Coached / Balanced / Standard Floor / Cardio & Lifting /
│                                  Distribute Evenly / High
└── Step2: MacroSummary           (IMG_6480, 6481)
    ├── MacroWeekChart            generated 7-day plan
    └── NumberedTimeline          design rationale (4 steps with vertical connector)
sticky white "Done" button at bottom
```

## File layout

```
Views/Wizards/
  EditGoalFlow.swift              orchestrates 2 steps
  Steps/
    EditGoal_WeightAndRate.swift  uses Components/RulerSlider
    EditGoal_Review.swift         uses Components/DiffRowCard
  SetProgramFlow.swift            orchestrates 2 steps
  Steps/
    SetProgram_Preferences.swift  uses Components/PillTabBar logic for grid
    SetProgram_Summary.swift      uses Components/MacroWeekChart + Components/NumberedTimeline
  Shared/
    WizardProgressUnderline.swift small top bar showing current step
```

## Data wiring

- Read current values from `UserProfile` + `EngineState`
- On "Done", write back to `UserProfile`:
  - Edit Goal: `goalWeightKg`, `weeklyChangeKg`
  - Set Program: triggers a fresh `WeeklyCheckIn.makeProposal` and writes the resulting plan to `customCalories / customProtein / customFat / customCarbs`

## Definition of done

1. Both wizards reachable from Phase E's action pill carousel
2. RulerSlider responds to drag, value updates Initial Daily Budget tile in real time
3. Diff cards correctly show "unchanged" when value is the same vs "old >> new" when different
4. NumberedTimeline shows 4 connected steps in MacroFactor's exact visual style (white circle + colored sub-value + paragraph)
5. `xcodebuild` + `swift test` green

## Watch out for

- The ruler slider needs precise hit-testing - it's a custom gesture, not the built-in `Slider`. Phase A's `Components/RulerSlider.swift` should handle this.
- The Initial Daily Budget on step 1 of Edit Goal updates live as the user drags. Bind it to the same `@State` the slider uses.
- The Set Program preference cards can be tapped to drill into detailed sub-flows; for MVP just allow display + final selection, defer drill-down to Phase G or later.
