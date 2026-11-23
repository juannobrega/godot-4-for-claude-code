# Constitution

Rules that hold for every system in this project. A spec may not contradict
them; a task that requires contradicting one is a decision for the human.

Proposed by `/godot-4:init` from what this codebase already does, then edited.
Anything here that was not actually observed in the code is marked `(assumed)`.

## Engine

- Engine: 4.7.2  <!-- keep in step with engine: in config.yml, which scripts read -->
- Renderer: forward_plus
- Language: GDScript only · C# is not used in this project

## GDScript

- Every `var`, parameter, return and collection carries an explicit type,
  including `@onready` and `@export`. `Array[Card]`, never bare `Array`.
- Godot 4 API only. `await`, `instantiate()`, `@export`, `sig.connect(cb)`.
- Node access by `%UniqueName`. Node paths and `get_node("../../X")` are banned.
- Signal names are noun + past-tense verb: `player_died`, `score_updated`.
- No magic numbers in gameplay code. Tunable values live in a `Resource`.

## Architecture

- Composition over inheritance. A scene is the unit of reuse: small, single
  responsibility, composed upward.
- Autoload only for genuinely global services: event bus, save, settings, audio,
  scene transition. Never per-level or per-character state.
- A scene carries what it needs. External context arrives by dependency
  injection from the caller, never by reaching up the tree.
- Scene, script and its own assets live in the same folder. `res://scripts/`
  holds only what belongs to no scene.

## Verification

- No rung is skipped because the change "obviously works".
- An acceptance criterion at V5 is closed by a human in `checks.md`. Never by an
  agent, never by inference from a passing test.
- Structural edits to `.tscn`/`.tres` go through the editor or a build script.

## Performance budget

- Target platform: (fill in)
- Frame budget: (fill in) · Allocations in gameplay loops: 0
