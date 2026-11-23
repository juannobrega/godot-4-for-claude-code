---
name: godot4-api-guard
description: Prevents Godot 3 API from being written into Godot 4 projects and tracks drift across 4.x minor versions. Use before writing or reviewing any GDScript, and whenever an engine call does not behave as expected.
---

# Godot 4 API guard

Most GDScript on the public web is Godot 3. It comes out fluent and breaks
immediately. This is not a knowledge gap to reason around — it is a reflex to
check against a table.

## Check before writing

Read `references/api-translation.md` for the full table. The five that account
for most of it:

| Godot 3 | Godot 4 |
|---|---|
| `yield(obj, "sig")` | `await obj.sig` |
| `scene.instance()` | `scene.instantiate()` |
| `export var hp = 10` | `@export var hp: int = 10` |
| `onready var x = $X` | `@onready var x: Node = %X` |
| `connect("died", self, "_on_died")` | `died.connect(_on_died)` |

## Which 4.x is this project?

Minor versions rename things. Do not write "Godot 4" code — write code for the
version this project declares.

```bash
grep '^config/features' project.godot    # the version the project opens as
godot --version                          # the version of the binary in use
```

The `session_context.sh` hook prints both every turn and warns when they
disagree. If they disagree, stop: a mismatch produces errors that look like
code bugs and are not.

## When an API does not behave as documented

The order that resolves it fastest:

1. Confirm the method exists in *this* minor version, not in 4.x generally.
2. Check whether it was renamed rather than removed — the old name usually
   survives in search results long after the engine dropped it.
3. Check the class, not the method: `Node2D` and `Control` diverge on things
   that read as universal.

Do not work around a missing method by reimplementing it until you have
checked 1 and 2. The method usually exists under a different name.
