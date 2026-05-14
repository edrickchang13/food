# Phase E — Strategy tab

**Blocked by Phase A.** Runs in parallel with B, C, D, F.

## Branch

`phase-e-strategy`

## Allowed paths

- `ios/calorietracker/Views/Strategy/**` (new directory)

## Reference screens

`IMG_6473.PNG`, `IMG_6474.PNG`, `IMG_6475.PNG`.

## Architecture

```
StrategyView
├── BigHeader                "STRATEGY" all-caps, collapses on scroll to compact "Strategy"
├── ActionPillCarousel       horizontal scroll: New Goal / Edit Goal / New Program /
│                             Edit Program / Change Check-In Day
├── CountdownRing            "5 DAYS until check-in" + Goal/Check-In labels under
├── InProgressSection
│   ├── CoachedProgramCard   7-day macro plan as MacroWeekChart
│   └── WeightGoalCard       3 stat columns
└── SearchBarPinnedToBottom  same component as Dashboard
```

## File layout

```
Views/Strategy/
  StrategyView.swift             top-level
  Header/
    StrategyHeader.swift         collapsing big->small header
  Actions/
    ActionPillCarousel.swift     scrollable pill row
  Ring/
    CheckInCountdownRing.swift   uses Components/CountdownRing
  Cards/
    CoachedProgramCard.swift     uses Components/MacroWeekChart
    WeightGoalCard.swift         3 stat columns
```

## Data wiring

| View | Reads from |
|---|---|
| CheckInCountdownRing | `WeeklyCheckIn.isDue` + days since `lastCheckInDay` + cadenceDays |
| CoachedProgramCard | `EngineState.snapshot.dailyPlan` projected across 7 days |
| WeightGoalCard | `UserProfile.weightKg`, `goalWeightKg`, `weeklyChangeKg` |
| ActionPillCarousel | navigation only - pushes Phase F's wizards |

## Definition of done

1. Strategy tab renders
2. Countdown ring counts down correctly from last check-in date
3. Action pills navigate to placeholder Phase F screens (or stubs if F hasn't merged yet)
4. CoachedProgramCard's stacked bars match the day's dailyPlan with kcal/P/F/C colors
5. `xcodebuild` + `swift test` green

## Watch out for

- The big "STRATEGY" header is in MacroFactor's most distinctive type style (heavy, condensed, all-caps). Match it via Phase A's typography tokens.
- The countdown ring uses GREEN for the elapsed arc (counter-intuitive vs progress bars). Don't invert it.
- The pill carousel has 5 items but only 3-4 fit on screen; the rest are revealed by horizontal scroll. Make sure the scroll indicator is hidden.
