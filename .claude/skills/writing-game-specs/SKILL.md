---
name: writing-game-specs
description: Writing specifications for game systems — behaviour, state machines, tuning surfaces, signal contracts, and acceptance criteria tagged by verification rung. Use when creating or reviewing a system spec, or when deciding whether a requirement is testable.
---

# Writing game specs

A generic spec template assumes user stories verified by automated tests. A
game system is a state machine plus tuning numbers plus sensory feedback, and
a large part of "done" is perceptual. The template in
`.claude/templates/spec.md` exists for that difference.

## The unit is the system, not the project

One spec covers one system: dash, inventory, dialogue, wave spawner. It has
the same size in a jam game and in a three-year project. A big game does not
have bigger specs, it has more of them.

If a spec is growing past two pages, it is two systems.

## Six sections that carry the weight

**Out of scope.** The section that stops the system growing sideways during
implementation. Write it before the behaviour.

**Behaviour** as numbered `BEH-nnn` entries, each one thing. "The player
dashes and is invulnerable" is two.

**State machine as a table** — entered when / left when / allows. Most
gameplay bugs an agent writes are missing transitions. A table makes the hole
visible before the code exists; prose hides it.

**Tuning surface** — every number a designer might change, with type, range,
default and owner. The test is not "is this magic", it is "can this change
without an engineer". See `godot-resource-tuning`.

**Signal contract** — what is emitted, with full signature, and who listens.
This is what lets VFX and audio be built against the system before it exists.

**Acceptance criteria, each tagged with a rung.** See below.

## Rungs are the honest part

Every `AC-nnn` carries V0–V5. See `godot-verification` for what each proves.

The mistake to avoid: dressing a perceptual criterion as a measurable one.

```
AC-035  The dash feels responsive                              V5   ✓
AC-035  Input-to-movement latency is under 50ms                V3   ✗
```

The second measures something real and adjacent, then reports a verdict on
something it did not test. A dash can be 20ms and feel dead. Keep the
measurement if it is useful, as its own criterion — but the feel criterion
stays V5 and stays open until a human plays it.

Two signals worth acting on:

- **All criteria at V5** — fine when the system's value is perceptual (a
  shader, a camera shake). Say so explicitly.
- **A logic system with nothing at V2–V4** — a finding. It usually means the
  logic is welded to nodes and cannot be instantiated in a test.

## Markers

`[NEEDS CLARIFICATION: ...]` for anything you are inferring.
`[DESIGN DECISION: ...]` for anything that is the human's call.

Both block `/godot-4:plan`. A first-pass spec with no markers usually means
you guessed instead of marking.

Never resolve a `[DESIGN DECISION]` yourself, even when one option is clearly
better engineering. That is what the marker is for.

## Write what, not how

Node names, class names and file paths belong in `plan.md`. A spec that names
`DashController.gd` has already made a design decision and hidden it in a
document the designer was supposed to be able to read.
