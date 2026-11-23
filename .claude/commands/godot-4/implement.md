---
description: Execute the tasks for a system, stopping at design decisions
argument-hint: <system-slug>
---

Implement the tasks for **$1**, in order.

## Before each task

Re-read the task's `done when`. That is the acceptance test for the task, not
your impression of completeness.

## While implementing

- GDScript 4 only. If you catch yourself writing `yield`, `.instance()` or
  `export var`, read `.claude/skills/godot4-api-guard/SKILL.md` — that reflex
  comes from Godot 3 training data and it compiles in nobody's engine.
- Explicit types everywhere, including `@onready` and `@export`, and typed
  collections (`Array[Card]`).
- No tuning literal in gameplay code. It goes in the Resource the plan declares.
- `%UniqueName`, never a node path.
- Do not hand-edit `.tscn`/`.tres` structure. The guard hook will stop you; it
  is faster to go the right way first.

## Stop and ask when

- You hit a `[DESIGN DECISION]`.
- A task cannot be done without violating the constitution.
- The plan's scene contract does not match the scene that exists — that is a
  spec/reality mismatch, not something to paper over.

## After each task

Tick it in `tasks.md`. Do not batch the ticks at the end: a crashed session
should leave an accurate record.

## Finish by

Running `/godot-4:verify` at the rung the plan declares. The Stop hook will
block the turn otherwise, and it is right to.
