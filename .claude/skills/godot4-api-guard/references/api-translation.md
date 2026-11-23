# Godot 3 → 4 translation

## Contents
- Coroutines and signals
- Instancing and nodes
- Annotations
- Common renames
- Patterns that silently changed meaning

## Coroutines and signals

| Godot 3 | Godot 4 |
|---|---|
| `yield(get_tree(), "idle_frame")` | `await get_tree().process_frame` |
| `yield(timer, "timeout")` | `await timer.timeout` |
| `connect("died", self, "_on_died")` | `died.connect(_on_died)` |
| `connect("died", self, "_on_died", [arg])` | `died.connect(_on_died.bind(arg))` |
| `disconnect("died", self, "_on_died")` | `died.disconnect(_on_died)` |
| `is_connected("died", self, "_on_died")` | `died.is_connected(_on_died)` |
| `emit_signal("died")` | `died.emit()` |

`await` on a signal that never fires hangs the coroutine with no error. Pair
every `await` on a game signal with a timeout when the signal is conditional.

## Instancing and nodes

| Godot 3 | Godot 4 |
|---|---|
| `scene.instance()` | `scene.instantiate()` |
| `get_node("Path/To/Node")` | `%UniqueName` |
| `PoolStringArray` | `PackedStringArray` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `OS.window_size` | `DisplayServer.window_get_size()` |

## Annotations

| Godot 3 | Godot 4 |
|---|---|
| `export var hp = 10` | `@export var hp: int = 10` |
| `export(float, 0, 1) var t` | `@export_range(0.0, 1.0) var t: float` |
| `export(PackedScene) var s` | `@export var s: PackedScene` |
| `onready var x = $X` | `@onready var x: Node = %X` |
| `tool` | `@tool` |
| `remote func` / `master func` | `@rpc("any_peer") func` |

## Common renames

| Godot 3 | Godot 4 |
|---|---|
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(vel, UP)` | set `velocity`, then `move_and_slide()` |
| `Spatial` | `Node3D` |
| `AnimatedSprite` | `AnimatedSprite2D` |
| `Tween` node | `create_tween()` |
| `rand_range(a, b)` | `randf_range(a, b)` |
| `Directory` / `File` | `DirAccess` / `FileAccess` |

## Patterns that silently changed meaning

**`move_and_slide` no longer takes arguments and no longer returns velocity.**
Godot 3 code that reads `velocity = move_and_slide(velocity, UP)` compiles as
a call with the wrong arity in 4 — but the shape is close enough that it gets
"fixed" into something that runs and moves wrong.

**`@onready` with `$Path` still works**, which is why path-based access
survives in Godot 4 codebases. It is not an error; it is a maintenance trap.
Prefer `%UniqueName`.

**Integer division.** `1 / 2` is `0`. Unchanged from Godot 3, but it is the
single most common silent wrong-number bug in tuning code. Write `1.0 / 2.0`.

**`.uid` sidecar files, from 4.4 onward.** Every script and resource has one.
Moving a `.gd` without its `.uid` breaks every reference to it. No model
trained before 4.4 knows the file exists.
