<!-- Written by /godot-4:init. Merged, never overwritten: anything you add
     outside the marked block is preserved by later updates. -->

# CLAUDE.md

## Godot project rules

@.godotspec/constitution.md

The import above is the single source of these rules. Editing them here would
create a second copy that drifts from the one the scripts read.

## Working in this project

- Specs live in `.godotspec/systems/<nnn>-<slug>/`. Read the system's `spec.md`
  before changing its code.
- Every acceptance criterion carries a verification rung. Never report a V5
  criterion as satisfied: those are closed by a human in
  `.godotspec/checks.md`.
- Run `.claude/scripts/verify.sh` before claiming a change works. The engine
  exits 0 after a `SCRIPT ERROR`, so "it ran" is not evidence.
- Do not edit `.tscn` or `.tres` structure as text. See the
  `godot-scene-contracts` skill.
