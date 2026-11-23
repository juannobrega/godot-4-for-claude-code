---
name: godot-performance
description: Frame budget, allocation and draw-call discipline for Godot 4, and how to profile headless. Use when a spec declares a performance budget, when frame rate drops, or when deciding the cost of a design.
---

# Performance

A budget that is not in the spec is not a budget. Every system spec states
allocations per operation, draw calls added, and frame cost on the target
platform — and those are the numbers a V2/V3 test can assert on.

## The budget

| Target | Frame | Notes |
|---|---|---|
| Desktop 60fps | 16.6ms | Comfortable; the GPU is rarely the constraint in 2D |
| Desktop 144fps | 6.9ms | Logic cost starts to matter |
| Mobile 60fps | 16.6ms | Draw calls and overdraw dominate |
| Switch-class | 16.6ms | Treat as mobile |

Gameplay loops allocate **zero**. An `Array` built every `_physics_process`
is 60 allocations a second feeding the garbage collector.

## The usual costs, in order

1. **Instantiating scenes mid-gameplay.** Pool bullets, particles, damage
   numbers. `instantiate()` in a firing loop is the most common frame spike
   in a 2D Godot game.
2. **Allocation in `_process`/`_physics_process`.** Reuse arrays and
   dictionaries declared as members.
3. **`get_node()` in a loop.** Cache in `@onready`.
4. **Signal storms.** One signal per entity per frame to a bus with many
   listeners costs more than the work it announces.
5. **Overdraw** in 2D: large transparent sprites stacked. Invisible on
   desktop, decisive on mobile.

## Measuring

```gdscript
# in-engine counters, cheap enough to leave in a debug overlay
Performance.get_monitor(Performance.TIME_PROCESS)
Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
```

Headless, inside a bot run, these become a V4 assertion:

```gdscript
if Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) > 0.008:
    _fail("physics over 8ms budget")
```

That turns "it felt laggy" into a gate.

## Order of work

Measure before optimising, and measure on the slowest target you ship to.
A frame cost that is invisible on a development desktop is the whole budget
on mobile. Optimising the wrong thing is the normal outcome of profiling on
the fast machine.

## What not to do

Do not micro-optimise GDScript arithmetic. The wins are in how many nodes
exist, how many things are drawn, and how much is allocated per frame — not
in whether a multiplication is hoisted out of a loop.
