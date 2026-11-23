# CLAUDE.md

Read by Claude Code sessions in this repository and by the Claude review in
`.github/workflows/claude-review.yml`.

## Review instructions

This repository is **godot-4**, a spec-driven development framework for Godot 4
game projects, shipped as a `.claude/` directory. It contains no application
code: the payload is skills, commands, agents, hooks, shell/Python scripts and
document templates.

Review against the rules below. A finding that does not map to one of them is
probably a style preference and should be raised as a comment, not a blocker.

The deterministic gates in `.github/workflows/validate.yml` already cover what a
script can check. Spend the review on what they cannot: whether a change is
correct, whether it weakens a guarantee, and whether it contradicts `docs/spec/`.

## Shell and Python scripts (`.claude/scripts/`, `tools/`)

These run as Claude Code hooks on contributors' machines, so portability and
failure behaviour matter more than elegance.

- **macOS ships bash 3.2.** `${var,,}`, `${var^^}`, associative arrays and
  `readarray` are not available. Flag any use.
- **BSD vs GNU tools.** `xargs -r`, `sed -i` without an argument and
  `find -printf` are GNU-only. Flag them.
- **A hook must never break the session.** Every script exits 0 when there is
  no `project.godot`: this framework must be inert in a repository that is not
  a Godot game. Flag a code path that can fail before that check.
- **Blocking hooks need an escape hatch.** `guard_scene.py` honours
  `GODOT4_GUARD_OFF`, `require_verify.sh` honours `GODOT4_VERIFY_OFF`. A new
  blocking hook without one is a defect.
- **Quote every path.** `"$CLAUDE_PROJECT_DIR"`, `"$GODOT_BIN"`.
- **PowerShell variable names are case-insensitive.** A local named `$here`
  assigns to a `[switch]$Here` parameter and throws. `validate_kit.py` checks
  for this, but flag it on sight: it broke the no-argument install on Windows
  in v1.0.0.
- The `Stop` hook must respect `stop_hook_active` or it loops forever.

## Verification logic

The framework's core claim is that its gates do not lie. Any change to
`verify.sh` is reviewed against the five known false-green modes:

1. Godot exits 0 after a `SCRIPT ERROR` — output must also be scanned.
2. A test runner that found no tests exits 0 — the JUnit report must exist and
   report more than zero tests.
3. gdUnit4 exits 103 headless without `--ignoreHeadlessMode`; its failure code
   is 100, not 1.
4. `--import` must run before tests, or `class_name` scripts do not exist.
5. New files have no `.uid` sidecar until the project is imported.

Removing or weakening any of these checks is a blocking finding.

## GDScript in examples and templates

Examples are copied by users, so Godot 3 API in them propagates.

- Godot 4 only: `await`, `instantiate()`, `@export`, `@onready`,
  `sig.connect(cb)`. Flag `yield`, `.instance()`, `export var`, `onready var`,
  `connect("sig", self, "_m")`.
- Explicit static types on every `var`, parameter, return and collection.
- `%UniqueName`, not node paths.
- No tuning literal in gameplay code — it belongs in a `Resource`.

## Skills, commands and agents

- `SKILL.md` frontmatter needs `name` (matching its directory, lowercase,
  hyphens) and `description` in the third person saying **what it does and when
  to use it**. The description is the only thing that decides whether the skill
  is ever selected.
- `SKILL.md` body under 500 lines; heavier material goes in `references/`,
  linked one level deep from `SKILL.md`.
- No time-sensitive statements ("as of now", "the upcoming release").
- A new skill must be routed from `using-godot-4/SKILL.md`, or it is
  undiscoverable.

## Documentation

`docs/` is the specification of this framework. A change to behaviour that is
not reflected there is an inconsistency worth flagging — in particular the
decision tables in `docs/spec/kit-spec.md` and
`docs/spec/release-process.md`.

## Out of scope for review

Prose style in skills and templates, and the wording of document templates,
unless it is factually wrong about Godot.
