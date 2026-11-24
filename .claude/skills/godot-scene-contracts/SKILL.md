---
name: godot-scene-contracts
description: Declaring a scene's node tree as a contract before it exists, and changing .tscn/.tres files without corrupting them. Use when creating or modifying any scene or resource file, or when the scene guard hook blocks an edit.
---

# Scene contracts

`.tscn` and `.tres` look like editable INI and are not. They carry
cross-file identity — `uid://`, `load_steps`, `ext_resource`/`sub_resource`
ids, node block structure — and rewriting any of it as text desynchronises
references silently. The scene fails to load much later, far from the edit.

So the scene is **declared before it is built**, and the file itself is
touched as little as possible.

## Declare the contract first

In the system's `plan.md`, before any file exists:

```
%Player (CharacterBody2D)              layer 1   mask 2|4
├── %Sprite (AnimatedSprite2D)
├── %Hurtbox (Area2D)                  group: hurtbox   layer 2   mask 1
│   └── CollisionShape2D
└── %DashController (Node)             exports: config: DashConfig
```

Nodes, types, unique names, exported properties, groups, collision layers and
masks. This is what makes the generated scene reviewable as a diff and what
lets the blind-QA agent test the system without reading its code.

## Three routes, pick one in the plan

| Route | When | How |
|---|---|---|
| **Contract** | New scene, created by the agent | Write the tree as JSON, build it with `.claude/scripts/build_scene.sh`. The contract is committed, so the scene is regenerable |
| **Editor** | Structural change to a scene a human built | Describe the change in `plan.md` as a task for the user. Do not attempt it as text |
| **MCP** | A Godot MCP server is connected | See `godot-mcp-bridge` |

## The contract

The same tree the plan declares, as JSON. Commit it beside the system's spec.

```json
{
  "path": "res://scenes/player/player.tscn",
  "root": {
    "name": "Player", "type": "CharacterBody2D", "groups": ["player"],
    "properties": {"collision_layer": 1, "collision_mask": 6},
    "children": [
      {"name": "Sprite", "type": "AnimatedSprite2D"},
      {"name": "Hurtbox", "type": "Area2D", "groups": ["hurtbox"],
       "properties": {"collision_layer": 2, "collision_mask": 1},
       "children": [{"name": "HurtboxShape", "type": "CollisionShape2D"}]},
      {"name": "DashController", "type": "Node"}
    ]
  }
}
```

```bash
.claude/scripts/build_scene.sh .godotspec/systems/004-dash/scene.json
```

A string property starting with `res://` is loaded as a resource. `unique`
defaults to `true` on every node, which is what makes `%Name` resolve.

## Why a contract and not a hand-written script

Building a scene in GDScript by hand has two traps that produce no error:

- a child whose `owner` is not the scene root is **absent from the saved file**
- without `unique_name_in_owner`, `%Name` fails at runtime, not at build time

The builder handles both, so they stop being things to remember. It also
rejects duplicate node names, because a unique name that is not unique makes
`%Name` ambiguous, and it writes a `uid` into the scene header — `ResourceSaver`
does not write one for a scene built in memory, and without it the scene can
only be referenced by path.

## What may be edited as text

Two things, and the guard hook enforces it:

- **Scalar property values** — `speed = 300.0` → `speed = 450.0`
- **`[connection]` lines** — rewiring a signal

Everything else is structural: `[gd_scene]`, `[gd_resource]`, `[ext_resource]`,
`[sub_resource]`, `[node]`, `[editable]`, `uid://`, `load_steps`.

## When the guard blocks you

It is telling you the change needs a different route, not that you phrased it
badly. Pick the editor or the build script. `GODOT4_GUARD_OFF=1` exists for
deliberate surgery with the user watching — not for getting past a block.

## After any file creation

```bash
godot --headless --path . --import
```

New scripts and resources have no `.uid` until this runs. Committing without
it breaks references for everyone else.
