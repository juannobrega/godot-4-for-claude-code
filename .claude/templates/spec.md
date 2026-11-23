# SYS-{{ID}} — {{SLUG}}

> What this system does and why. No implementation detail: that is plan.md.
> Mark every gap with `[NEEDS CLARIFICATION: ...]` and every choice that belongs
> to a human with `[DESIGN DECISION: ...]`. Both block `/godot-4:plan`.

## Summary

One sentence: what the player does, and why this exists in the game.

## Pillars served

Which pillars from vision.md this serves. If none, say so — that is a finding.

## Out of scope

Explicit. This is the section that stops the system from growing sideways.

## Behaviour

- BEH-001 — ...
- BEH-002 — ...

## State machine

| State | Entered when | Left when | Allows |
|---|---|---|---|
| | | | |

## Tuning surface

Becomes `{{SLUG}}_config.tres (class {{CLASS}}Config)`. Every number a designer may want to change
belongs here and nowhere else.

| ID | Type | Range | Default | Owner |
|---|---|---|---|---|
| TUN- | float | – | | design |

## Signal contract

| ID | Direction | Signature | Consumed by |
|---|---|---|---|
| SIG- | emits | `name(arg: Type)` | |

## Acceptance criteria

Every row carries a rung. V0 syntax · V1 import/load · V2 unit · V3 headless
integration · V4 deterministic bot · V5 human judgement.

A system whose criteria are all V5 is not a failure — it means the value is
perceptual, and saying so is the point. A logic system with nothing in V2–V4
is a finding: it is probably too coupled to nodes to test.

| ID | Given / When / Then | Rung |
|---|---|---|
| AC-001 | Given …, When …, Then … | V2 |
| AC-002 | | V5 |

## Performance budget

Allocations per operation · draw calls · frame cost on the target platform.

## Decisions

- D-SYS{{ID}}-01 — ... Rationale: ...
