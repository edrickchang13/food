# Phase briefs

One file per phase. Each is self-contained enough that a fresh Claude session can pick it up after reading `docs/HANDOFF.md` for project-wide context.

## Recommended workflow (CLI + tmux)

```bash
tmux new -s bulkai-build

# In each tmux pane, open a Claude Code CLI session in the repo root:
cd ~/food && claude

# Then paste the phase brief content into the session as the first message,
# or just point Claude at the brief:
"Pickup the work described in docs/handoff/PHASE_B.md. Build on a feature
 branch. Don't push until xcodebuild succeeds and the engine tests pass.
 Tell me when you're ready to merge."
```

## Phase order + dependencies

```
A.  Foundation                  (blocks B-F)
B.  Dashboard                   (independent of C, D, E, F)
C.  Food Log                    (independent of B, D, E, F)
D.  Food Entry sheet            (independent of B, C, E, F)
E.  Strategy tab                (independent of B, C, D, F)
F.  Goal + Program wizards      (independent of B, C, D, E)
G.  Bulk AI twist               (blocked by B-F)
H.  Polish + ship               (blocked by G)
```

A is solo. Once A is on main, B/C/D/E/F can fan out across forks. After they all merge, G runs solo. Then H runs solo.

## Per-fork command template

For any phase, paste this into a fresh CLI session in `~/food`:

```
I am picking up Phase {X} of the Bulk AI project. Read docs/HANDOFF.md
for context, then read docs/handoff/PHASE_{X}.md for the work spec.
Do not touch files outside the Allowed paths in that brief. Build
locally with xcodebuild after each change. Push the phase-{slug}
branch when xcodebuild and swift test both pass. Do not merge to main
yourself.
```

Swap `{X}` for the phase letter.
