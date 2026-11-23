---
name: godot-resource-tuning
description: Models a system's tunable values as a custom Godot Resource so designers can rebalance without touching code. Use when a spec declares a tuning surface, or when gameplay code contains numeric literals.
---

# Tuning as a Resource

Every number a designer might want to change lives in a `Resource`, saved as a
`.tres`. Not as a `const`, not as an `@export` on the node, not as a literal.

The test is not "is this a magic number". It is: **can this change without an
engineer?** If a balance pass means editing `.gd`, the pipeline is wrong.

## The resource

```gdscript
class_name DashConfig
extends Resource

## Peak speed during the dash, in pixels per second.
@export_range(200.0, 1200.0) var speed: float = 600.0
## How long the dash lasts.
@export_range(0.05, 0.4) var duration: float = 0.18
## Minimum time between dashes.
@export_range(0.0, 3.0) var cooldown: float = 0.6
## Invulnerability window, measured from the first frame of the dash.
@export_range(0.0, 0.4) var iframe_window: float = 0.15
```

Ranges come from the spec's tuning surface and are not invented here. An
`@export_range` is the only thing stopping a designer from typing `6000` and
filing a bug.

## Wiring it

```gdscript
class_name DashController
extends Node

@export var config: DashConfig
```

The config is injected, not loaded. `preload("res://.../dash_config.tres")`
inside the controller hardcodes one tuning for every instance and makes a
per-enemy variant impossible.

## Why Resource and not a dictionary or JSON

- Typed fields and ranges show up in the inspector as real controls.
- Sub-resources compose: a `WeaponConfig` can hold a `DamageCurve`.
- `.tres` is text, so a balance change is a readable diff and merges.
- It survives `--import` and ships in the export without extra plumbing.

## The one trap

A `Resource` assigned in the inspector is **shared between every instance** of
the scene. Mutating `config.speed` at runtime changes it for all of them, and
in the editor it writes back to the `.tres` on save.

Treat the config as read-only. Runtime state that happens to start from a
config value is a separate variable on the node:

```gdscript
var _current_speed: float = 0.0

func _ready() -> void:
    _current_speed = config.speed    # copy, then mutate the copy
```

If an instance genuinely needs its own config, call
`config.duplicate()` in `_ready()`.
