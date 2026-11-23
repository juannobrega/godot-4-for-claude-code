---
name: godot-bot-playtest
description: Deterministic headless bot runs for Godot 4 (verification rung V4) — fixed seeds, fixed timestep, explicit exit codes, video evidence. Use when a spec declares a V4 acceptance criterion or when a whole-run behaviour needs checking.
---

# Bot playtest (V4)

V4 proves a full run reaches a stated goal, reproducibly. It sits between
"the scene behaves" (V3) and "it feels right" (V5), and it is the most fragile
rung — treat it as optional per system.

## The one rule

**Godot exits 0 after a `SCRIPT ERROR`.** A bot that does not call
`get_tree().quit(1)` itself reports success for a run that crashed. Start from
`.claude/scripts/bot_template.gd`, which does.

## Running

```bash
godot --headless --path . --fixed-fps 60 --quit-after 1800 -- --bot --seed 42
```

- `--fixed-fps 60` pins physics and timer steps. Without it the same bot
  passes on your machine and fails on CI, and the run is not evidence.
- `--quit-after 1800` is a frame count — a hard stop so a hung run does not
  block the pipeline.
- Everything after `--` arrives through `OS.get_cmdline_user_args()`.

## Shape of a scenario

One stated goal with a budget, taken from the spec's V4 criterion:

> AC-034 — the bot crosses the test corridor in ≤ 4.0s with seed 42

```gdscript
func _run() -> void:
    await get_tree().process_frame
    _press("ui_right", 1.0)
    if _elapsed > 4.0:
        _fail("corridor took %.2fs, budget 4.0s" % _elapsed)
    _pass("corridor in %.2fs" % _elapsed)
```

A bot without a budget hangs instead of failing. Every scenario needs a
ceiling, even an absurd one.

## Determinism

Seed the RNG from the argument, never from the system clock. Use
`_physics_process` rather than `_process` for anything measured. No
`Time.get_ticks_msec()` in game logic.

A V4 run that is not reproducible is not a gate, it is a coin flip that
occasionally fails CI and gets disabled.

## Video evidence

```bash
xvfb-run -a godot --path . --fixed-fps 60 --quit-after 1800 \
         --write-movie evidence/run.avi -- --bot --seed 42
```

`--write-movie` needs a display and crashes under `--headless`. Worth the
Xvfb setup when a V5 reviewer would otherwise have to reproduce the run by
hand.

## What V4 cannot do

It cannot press a `Button`: headless does not deliver clicks to `Control`
nodes. And it cannot tell you the run was enjoyable. A bot reaching the goal
proves the system is traversable, not that it is good — that stays V5.
