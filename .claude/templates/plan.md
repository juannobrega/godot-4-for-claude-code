# SYS-{{ID}} — {{SLUG}} · plan

> How the spec gets built. Written after every `[NEEDS CLARIFICATION]` in
> spec.md is resolved.

## Approach

Two or three sentences. Where this system lives in the architecture and why.

## Scene contract

The tree this system requires, declared before any `.tscn` exists.

```
%Player (CharacterBody2D)
├── %Sprite (AnimatedSprite2D)
└── %Hurtbox (Area2D)        groups: hurtbox   layer: 2   mask: 1|4
```

| Node | Unique name | Exported properties | Groups | Layer / mask |
|---|---|---|---|---|
| | | | | |

Creation route — pick one and say why:
- [ ] built from a scene contract via `.claude/scripts/build_scene.sh` (new scene, agent-made)
- [ ] built in the Godot editor by the human (structural change to an existing scene)
- [ ] edited through MCP (editor open, UID index live)

## Resource schema

```gdscript
class_name {{CLASS}}Config
extends Resource

@export_range(0.0, 1.0) var example: float = 0.5
```

## Files touched

The check-out set. Two plans whose sets are disjoint may run in parallel;
`project.godot` and autoloads are always sequential.

| Path | New? | Why |
|---|---|---|
| | | |

## Verification strategy

| Rung | What runs | Where |
|---|---|---|
| V2 | | `tests/unit/test_{{SLUG}}.gd` |
| V3 | | `tests/integration/test_{{SLUG}}.gd` |
| V4 | | `tools/bot.gd` scenario |
| V5 | | playtest script in checks.md |

## Risks

| Risk | Mitigation |
|---|---|
| | |
