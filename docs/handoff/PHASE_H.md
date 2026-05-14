# Phase H — Polish + ship

**Blocked by Phase G.** Final phase before declaring P12 complete.

## Branch

`phase-h-polish`

## Allowed paths

Anything, in service of polish. Be surgical.

## Deliverables

### Accessibility pass

Run on every screen:

1. **VoiceOver** - announce labels on charts, contribution grids, ring progress
2. **Dynamic Type** - all custom text needs to scale up to Accessibility5 without truncation
3. **Color contrast** - run macros through a contrast checker; the coral on dark surface might need a brightness bump for AAA on text
4. **Reduce Motion** - the dashboard pager should not auto-advance if user has Reduce Motion on
5. **Touch targets** - every tappable element >= 44pt

### Animation pass

Add subtle transitions:

1. Dashboard pager: spring transition between cards
2. Tab switches: cross-fade instead of instant swap
3. Wizards: slide-from-right between steps
4. Bottom sheets (Shortcuts, food entry): smooth scrim fade

Do not add motion to charts or numeric displays (creates visual noise during data updates).

### Performance pass

1. Profile a 1Y Progress view scroll with 3,806 imported entries
2. Profile the Dashboard scroll with the same dataset
3. Profile food entry sheet text input parse loop (should be <300ms from typing to result)
4. If any of those exceed 16ms per frame, identify the bottleneck (probably `Dictionary` rebuilds inside body)

### Ship checklist

1. Run all 48 engine tests
2. Build a final IPA via CI
3. Update `~/food/README.md` with the v1.0.N final number and a 1-paragraph "what Bulk AI is" pitch
4. Push a tagged release with notes summarizing the P12 milestone
5. Tell the user the build is ready; they pull-to-refresh AltStore and install the final v1.0.N

## Definition of done

- A11y audit log committed
- Performance trace shows 60fps on Dashboard + Progress
- v1.0.N installed on user's phone via AltStore, smoke test passes
