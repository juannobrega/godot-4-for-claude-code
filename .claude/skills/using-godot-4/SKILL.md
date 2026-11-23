---
name: using-godot-4
description: Routes Godot 4 work to the right skill in this kit and states the precedence between them. Use at the start of any Godot task when it is unclear which skill applies, or when two skills seem to give conflicting guidance.
---

# Using the godot-4 kit

Load only the skill the task needs. Reading the whole kit into one task costs
context that the task itself needs.

## Route

| The task is about | Load |
|---|---|
| Writing or reviewing a system spec, acceptance criteria, rungs | `writing-game-specs` |
| Any `.gd` file, typing, signals, naming | `gdscript-conventions` |
| Code that might be Godot 3, or a version-specific API | `godot4-api-guard` |
| `.tscn`/`.tres` structure, build scripts, scene trees | `godot-scene-contracts` |
| Tuning numbers, `@export`, custom `Resource` | `godot-resource-tuning` |
| Where a system lives, autoloads, event bus, folders | `godot-architecture` |
| Running gates, exit codes, what a rung proves | `godot-verification` |
| Writing tests, GUT, gdUnit4, simulated input | `godot-testing` |
| Deterministic bot runs, seeds, headless playtest | `godot-bot-playtest` |
| Judging feel, input buffering, coyote time, hitstop | `game-feel-review` |
| Frame budget, allocations, profiling | `godot-performance` |
| Two agents, worktrees, `.uid`, `project.godot` merges | `godot-parallel-work` |
| Export presets, release builds | `godot-release` |
| An MCP Godot server is connected | `godot-mcp-bridge` |
| Updating the framework itself, or reconciling `CLAUDE.md` | run `/godot-4:update` |

## Precedence

When guidance conflicts, higher wins:

1. **`.godotspec/constitution.md`** — the project's own rules. A skill never
   overrides the project.
2. **`godot4-api-guard`** — a correct pattern written in Godot 3 syntax is
   still broken code.
3. **The specific skill** for the task.
4. **`gdscript-conventions`** — the default for anything unaddressed above.

## Two rules that hold everywhere

**Never claim a change works without running a rung.** Godot exits 0 after a
`SCRIPT ERROR`, so "it ran" is not evidence. See `godot-verification`.

**Never close a V5 criterion.** Perceptual judgement is the human's. Writing it
as a test does not make it testable.
