---
name: godot-architecture
description: Deciding where a system lives in a Godot project — composition, autoloads, event bus, dependency injection, folder layout. Use when planning a new system or when a change requires reaching across the scene tree.
---

# Where a system lives

## Composition, not inheritance

The scene is the unit of reuse. Small, single-responsibility scenes composed
upward beat a deep class hierarchy, because a scene carries its nodes, its
script and its assets together.

A character is `CharacterBody2D` + `Hurtbox` + `AnimationPlayer` +
`WeaponMount`, each its own scene. Not a 600-line `Player.gd` that inherits
from `Fighter` which inherits from `Entity`.

When two systems share behaviour, extract a **component scene** both instance,
not a base class both extend.

## Autoloads

Only for services that are genuinely global and genuinely singular:

- event bus · save manager · settings · audio buses · scene transition

Never for per-level state, per-character state, or anything that could have two
instances. An autoload holding `current_enemy` is a global variable with extra
steps, and it is the reason the second enemy breaks the first.

Every autoload is a sequential edit: it touches `project.godot`, so no two
agents can add one at the same time. See `godot-parallel-work`.

## Signals, not polling

If A reacts to B, B emits and A connects. Checking B's state every frame
couples A to B's internals and runs 60 times a second to notice one event.

Down the tree: call methods. Up the tree: emit signals.

For cross-scene communication where neither owns the other, use one event bus
autoload with typed signals:

```gdscript
# autoload/events.gd
extends Node

signal player_died(position: Vector2)
signal score_updated(total: int)
signal wave_cleared(index: int)
```

One bus, strictly typed, noun-then-past-tense names. An untyped bus becomes a
global message soup nobody can trace.

## Dependency injection

A scene should carry what it needs. When it genuinely needs outside context,
the high-level caller provides it:

```gdscript
# good: the spawner hands the enemy what it needs
enemy.configure(target, difficulty_config)

# bad: the enemy goes looking
var player = get_tree().get_first_node_in_group("player")
```

The second one makes the enemy unusable in a test scene that has no player —
which is exactly how a system ends up with no V3 coverage.

## Folders

Scene, its script and its own assets in one folder:

```
scenes/player/
  player.tscn  player.gd  player.png  dash_config.tres
```

`res://scripts/` holds only what belongs to no scene: utilities, autoloads,
abstract bases, resource classes shared across systems.

## The question to ask first

Before placing anything: **what breaks if there are two of these?** If the
answer is "nothing, it is a service" it may be an autoload. If the answer is
anything else, it is a node in a scene.
