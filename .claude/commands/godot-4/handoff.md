---
description: Snapshot session state so work can resume cleanly later
argument-hint: ""
---

Write `.godotspec/handoff.md`.

Write it for someone with no memory of this session — which, next time, is you.

```markdown
# Handoff — 2026-11-22

## Where we are
SYS-004 dash: tasks T-001..T-012 done, T-013 in progress.

## What is in flight
`scripts/player/dash.gd` — i-frame window applies on the wrong frame.
Half-fixed; see the FIXME.

## Verification state
V0–V2 green. V3 never run: the test corridor scene does not exist yet.

## Open decisions
D-SYS004-02 — aerial dash allowed? Blocking T-014.

## Next action
Build `levels/test_corridor.tscn` in the editor (structural, cannot be an
agent edit), then run verify.sh V3.
```

## Rules

Facts, not reassurance. "Mostly working" tells the next session nothing;
"V3 never run" tells it where to start.

Always name the single next action. Ambiguity at resume is how a session
spends its first ten minutes rediscovering what it already knew.
