---
description: Turn a system spec into a technical plan — scene contract, resource schema, file check-out set, verification strategy
argument-hint: <system-slug>
---

Plan the implementation of **$1**.

Refuse to start if `spec.md` still has open `[NEEDS CLARIFICATION]` markers.
Say which ones and point at `/godot-4:clarify`.

Read `.godotspec/constitution.md`. A plan that violates it is not a plan, it is
a request to change the constitution — raise that explicitly if needed.

## Produce

**Scene contract.** The node tree this system requires, written before any
`.tscn` exists: nodes, types, unique names, exported properties, groups,
collision layers and masks. Then pick the creation route and justify it:
a scene contract for a new agent-made scene, the Godot editor for a structural
change to an existing one, MCP if the editor is live. See
`.claude/skills/godot-scene-contracts/SKILL.md`.

**Resource schema.** The tuning surface from the spec, as a `class_name`
`Resource` with typed `@export` and `@export_range` matching the declared
ranges. See `.claude/skills/godot-resource-tuning/SKILL.md`.

**File check-out set.** Every path this work will touch, marked new or
existing. This is what makes parallel work safe: two plans with disjoint sets
can run at once, and `project.godot` and autoloads never can.

**Verification strategy.** For each rung, what will actually run and where the
file lives. If a rung has nothing in it, say why — "no V3: this system has no
runtime scene, it is a pure resolver" is a good answer; silence is not.

**Risks.** Specifically: anything that will need the Godot editor, anything
that touches an autoload, and anything whose acceptance criteria are mostly V5.
