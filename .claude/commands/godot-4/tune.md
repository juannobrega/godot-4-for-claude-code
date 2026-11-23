---
description: Adjust a system's tuning resource without touching code
argument-hint: <system-slug>
---

Change the tuning values for **$1**.

## Rules

Only the `.tres` is edited. If a change requires touching a `.gd`, stop: the
value you are chasing is not in the tuning surface, and that is a spec bug.
Say so and offer to add it to the spec and the Resource.

Stay inside the declared range. A value outside it means either the range is
wrong in the spec or the request is wrong — both are worth one sentence before
proceeding.

## Record

Append the before and after to the system's `evidence/tuning.md`:

```
2026-11-22  TUN-dash_speed  600.0 → 720.0   "dash felt sluggish after the
                                             camera change"  — user
```

Without the reason, the next person to look at the number has no way to tell a
deliberate choice from a stray edit.

## After

Re-run `/godot-4:verify V4` if a bot scenario depends on the value — a timing
criterion like "crosses the corridor in ≤ 4.0s" moves when speed moves. Then
re-open the matching V5 items in `checks.md`: a feel judgement made against the
old numbers is no longer valid.
