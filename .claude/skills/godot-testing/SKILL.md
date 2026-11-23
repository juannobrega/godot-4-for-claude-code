---
name: godot-testing
description: Writing GUT and gdUnit4 tests for Godot 4, including simulated input and headless scene runners. Use when implementing acceptance criteria at rungs V2 and V3.
---

# Testing Godot 4

Framework comes from `.godotspec/config.yml`. GUT is the kit default: plain
GDScript, headless without special flags, binary exit code. gdUnit4 has a
richer scene runner and simulates touch, at the cost of more moving parts and
a mandatory `--ignoreHeadlessMode`.

## V2 — pure logic

Anything that does not need a scene tree. Resolvers, damage maths, state
transition tables, save serialisation.

```gdscript
# tests/unit/test_dash_config.gd
extends GutTest

func test_speed_within_declared_range() -> void:
    var cfg := DashConfig.new()
    assert_between(cfg.speed, 200.0, 1200.0, "default must sit in the spec range")

func test_cooldown_blocks_second_dash() -> void:
    var sm := DashStateMachine.new(DashConfig.new())
    sm.request_dash()
    assert_false(sm.can_dash(), "cooldown should block an immediate second dash")
```

If a system cannot be tested at V2 because every method needs a node, that is
a design finding, not a testing problem. See `godot-architecture`.

## V3 — scene behaviour

Instance the scene, drive it, assert on state and emitted signals.

```gdscript
# tests/integration/test_dash.gd
extends GutTest

var _player: CharacterBody2D

func before_each() -> void:
    _player = preload("res://scenes/player/player.tscn").instantiate()
    add_child_autofree(_player)
    await get_tree().process_frame

func test_wall_collision_returns_to_idle() -> void:
    watch_signals(_player)
    _player.dash(Vector2.RIGHT)
    await wait_physics_frames(2)
    assert_signal_emitted(_player, "dash_started")
```

`add_child_autofree` matters: a leaked node makes gdUnit4 exit `101` and makes
GUT runs flaky in ways that look like real failures.

## Simulated input

```gdscript
# raw event — goes through _input(), closest to hardware
var key := InputEventKey.new()
key.keycode = KEY_RIGHT
key.pressed = true
Input.parse_input_event(key)

# action — skips the _input() layer, right for driving gameplay
Input.action_press("ui_right")
Input.action_release("ui_right")
```

GUT chains with timing: `_sender.action_down("ui_right").hold_for(1.2).wait(0.3)`
then `await _sender.idle`. gdUnit4's scene runner waits in milliseconds rather
than frames, because frame timing varies between machines.

**Headless does not click `Control` nodes.** A simulated click reaches
`_input` but never presses a `Button`. UI interaction needs Xvfb or moves to
V5. Do not write a headless test that asserts a button was pressed — it will
pass or fail for the wrong reasons.

## Determinism

Fixed seed, fixed timestep, no wall-clock. A test that uses
`Time.get_ticks_msec()` for game timing is a test that fails on a slow CI
runner and gets marked flaky instead of fixed.

## Before running anything

```bash
godot --headless --path . --import
```

Without it, scripts with `class_name` do not exist and the runner finds zero
tests — and exits 0. Run tests through `.claude/scripts/verify.sh`, which
asserts the report is non-empty.
