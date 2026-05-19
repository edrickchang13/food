# UI Fork Brief — Food Log long-press → Edit / Duplicate / Delete

## What's done (Engine & Logic fork shipped this)

`HourTimeline` (the per-hour food-log row component) now accepts three
optional long-press callbacks alongside its existing `onTapEntry`:

```swift
public init(
    date: Date,
    entries: [FoodEntry],
    onAdd: @escaping (Date) -> Void,
    onTapEntry: @escaping (FoodEntry) -> Void,
    onLongPressEdit: ((FoodEntry) -> Void)? = nil,
    onLongPressDuplicate: ((FoodEntry) -> Void)? = nil,
    onLongPressDelete: ((FoodEntry) -> Void)? = nil,
    hours: ClosedRange<Int> = 7...23
)
```

Inside each entry row, a SwiftUI `.contextMenu` renders the three
buttons. `.contextMenu` handles the hold gesture, haptic feedback, and
lift animation natively. Each menu item is gated on its callback being
non-nil so older callers (no callbacks passed) don't show an empty menu.

All three callbacks default to `nil` so the existing `FoodLogView`
call site keeps compiling without changes. Backward-compatible
API extension.

## What the UI fork needs to do

Open `ios/calorietracker/Views/FoodLog/FoodLogView.swift` and wire the
three new callbacks. The view already has the `editingEntry` state and
the sheet that opens `EditFoodEntryView` (added in PR #18). Add:

```swift
HourTimeline(
    date: selectedDate,
    entries: foodStore.entries(for: selectedDate),
    onAdd: { hour in quickAddHour = hour },
    onTapEntry: { entry in tappedEntry = entry },
    // Long-press → straight into the editor, skipping the
    // Nutrition Facts Label preview the tap path opens. Matches
    // MacroFactor's hold-to-edit UX.
    onLongPressEdit: { entry in editingEntry = entry },
    // Long-press → Duplicate: re-log the same entry at .now via
    // the existing duplicatedForLogging helper on FoodEntry.
    // Useful for repeat meals ("same breakfast as yesterday").
    onLongPressDuplicate: { entry in
        let copy = entry.duplicatedForLogging(at: .now, mealType: entry.mealType)
        foodStore.addEntry(copy)
    },
    // Long-press → Delete (destructive, no prompt — matches
    // MacroFactor; the lift animation is enough confirmation).
    onLongPressDelete: { entry in foodStore.deleteEntry(entry) }
)
```

That's the entire wire-up — no new state vars, no new sheets. Reuses
the `editingEntry` plumbing PR #18 already adds.

## Test plan

- [ ] Long-press a row in the Food Log → context menu appears with
      Edit / Duplicate / Delete and the row lifts under the user's
      finger with iOS's native preview animation.
- [ ] Edit → `EditFoodEntryView` sheet opens directly (no Nutrition
      Facts Label preview in between).
- [ ] Duplicate → the same food re-appears in the timeline stamped at
      the current hour.
- [ ] Delete → the row vanishes from the timeline; check the
      Dashboard's daily totals decrease by the deleted entry's macros.
- [ ] Tap (not long-press) still opens the Nutrition Facts Label
      preview — both gestures coexist.

## Where this PR sits

| Fork | Branch | PR | Status |
|---|---|---|---|
| Engine & Logic | `food-log-long-press-edit` | (open this when you read this) | HourTimeline API extension, build clean |
| UI | `ui-wave-2-bodyfat-chat-haptics-tdee-coachmarks` | #18 | Has `editingEntry` state ready to plug into the new callbacks |

If PR #18 lands first, the UI fork can amend with the 4-line wire-up
above in a follow-up commit. If the Engine PR lands first, the UI
fork merges main into its branch and adds the wire-up before opening
its own PR.
