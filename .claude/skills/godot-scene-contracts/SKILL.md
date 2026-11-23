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
| **Build script** | New scene, created by the agent | `tools/scenes/build_<name>.gd`, run headless. The script is the source of truth; the `.tscn` is generated |
| **Editor** | Structural change to a scene a human built | Describe the change in `plan.md` as a task for the user. Do not attempt it as text |
| **MCP** | A Godot MCP server is connected | See `godot-mcp-bridge`. The editor holds the live UID index |

## Build script shape

```gdscript
# tools/scenes/build_player.gd
# Run: godot --headless --path . -s tools/scenes/build_player.gd
extends SceneTree

func _init() -> void:
    var root := CharacterBody2D.new()
    root.name = "Player"
    root.collision_layer = 1
    root.collision_mask = 2 | 4

    var sprite := AnimatedSprite2D.new()
    sprite.name = "Sprite"
    root.add_child(sprite)
    sprite.owner = root          # without owner, the node is not saved

    # unique_name_in_owner is what makes %Sprite resolve
    sprite.unique_name_in_owner = true

    var packed := PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, "res://scenes/player.tscn")
    quit()
```

`owner` is the trap: a child without `owner` set to the scene root is simply
absent from the saved file, with no error.

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
