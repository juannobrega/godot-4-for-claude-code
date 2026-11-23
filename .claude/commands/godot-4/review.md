---
description: Process human verdicts from checks.md and close V5 criteria
argument-hint: ""
---

Read `.godotspec/checks.md` and act on what the human wrote.

This is the only command that may close a V5 acceptance criterion.

## For each judged item

- **good** — mark the AC satisfied in the system's `spec.md`, and note the date
  and the build it was judged against. A verdict without a build reference is
  worthless after the next tuning pass.
- **needs tuning** — do not change code. Open a tuning task, or run
  `/godot-4:tune` if the value is already in the surface.
- **wrong design** — this is not a bug. Raise it as a spec change: which BEH
  entries are affected, and what the decision would be. Record it in
  `decisions.md` with the rationale the human gave.

## For each unjudged item

Leave it open and list it. Do not infer a verdict from passing tests at lower
rungs — that is exactly the failure mode the ladder exists to prevent.

## Report

What closed, what is still waiting, and whether any system is now fully
satisfied across every rung.
