---
name: gdscript-conventions
description: Writing conventions for GDScript in Godot 4 — static typing, signal naming, node access, file structure. Use when writing or reviewing any .gd file.
---

# GDScript conventions

The project's `.godotspec/constitution.md` wins over anything here. These are
the defaults when it is silent.

## Static typing, everywhere

```gdscript
var speed: float = 600.0
var targets: Array[Enemy] = []
@onready var sprite: AnimatedSprite2D = %Sprite
@export var config: DashConfig

func apply_damage(amount: int, source: Node) -> bool:
```

Typed collections (`Array[Enemy]`) matter more than they look: an untyped
`Array` accepts anything and the mistake surfaces three systems away. `@export`
without a type shows as a generic field in the inspector, which makes it
useless to a designer.

Return `-> void` explicitly. An omitted return type is `Variant`, not `void`.

## Node access

`%UniqueName`, never a path.

```gdscript
@onready var hurtbox: Area2D = %Hurtbox        # survives a tree reshuffle
@onready var hurtbox: Area2D = $Body/Hurtbox   # breaks when the artist moves it
```

Reaching upward (`get_parent().get_parent().score += 1`) couples a scene to
where it happens to be instanced. Emit a signal and let the owner handle it.

## Signals

Noun first, past-tense verb last: `player_died`, `score_updated`,
`wave_cleared`. Declare the full signature.

```gdscript
signal dash_started(direction: Vector2)
signal dash_ended()
```

Down the tree: call methods. Up the tree: emit signals. That one rule removes
most circular-reference problems before they exist.

## File structure

In this order, every file:

```gdscript
class_name DashController
extends Node

## Doc comment: what this is for.

signal dash_started(direction: Vector2)

enum State { IDLE, DASHING }

const MAX_QUEUED_INPUTS: int = 2

@export var config: DashConfig

var _state: State = State.IDLE
@onready var _body: CharacterBody2D = %Body

func _ready() -> void:
func _physics_process(delta: float) -> void:
func dash(direction: Vector2) -> void:     # public
func _apply_iframes() -> void:             # private, leading underscore
```

## Numbers

No tuning literal in gameplay code. If a designer might change it, it belongs
in a `Resource` — see `godot-resource-tuning`.

A constant that is genuinely structural (`MAX_QUEUED_INPUTS`) stays a `const`
and carries a comment saying why that value.

## Formatting

`gdformat` is available but is not run automatically: it has produced code the
engine rejects. If you format, run a parse check immediately after.
