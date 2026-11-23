---
description: Write the specification for one game system — behaviour, state machine, tuning surface, signal contract, acceptance criteria by verification rung
argument-hint: <system-slug>
---

Specify the system: **$1**

Read `.godotspec/constitution.md` first, and `vision.md`/`roadmap.md` if they
exist. Then scaffold with `.claude/scripts/new_system.sh $1` and fill
`spec.md`.

## What this document is

What the system does and why. Not how. Implementation goes in `plan.md`, and
putting it here is the most common way a spec stops being reviewable by anyone
who is not already writing the code.

## Rules

**Mark gaps, do not fill them.** Anything you are inferring rather than being
told goes in as `[NEEDS CLARIFICATION: ...]`. Anything that is a design choice
rather than a technical one goes in as `[DESIGN DECISION: ...]`. Both block
`/godot-4:plan`. A spec with no markers after a first pass is usually a spec
where you guessed.

**Every number a designer might change goes in the tuning surface.** With a
type, a range, a default and an owner. If it ends up as a literal in GDScript,
the designer has to ask an engineer to rebalance the game.

**Every acceptance criterion carries a rung.** V0 syntax · V1 import/load ·
V2 unit · V3 headless integration · V4 deterministic bot · V5 human judgement.
Read `.claude/skills/godot-verification/SKILL.md` if you are unsure which rung
something lands on — the common mistake is marking a feel criterion V3 because
it sounds testable.

Criteria that are genuinely perceptual belong at V5 and stay there. Writing
"the dash feels responsive" as a V3 assertion does not make it machine-checkable,
it makes the gate dishonest.

**State the state machine as a table.** Entered when / left when / allows. Most
gameplay bugs an agent writes are missing transitions, and a table makes the
hole visible before the code exists.

## Finish by

Listing the markers you left and asking the user to run `/godot-4:clarify`.
