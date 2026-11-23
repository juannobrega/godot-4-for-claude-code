---
name: godot-verification
description: The V0-V5 verification ladder for Godot projects — what each rung proves, the exact commands, and the exit-code traps that make a gate report green when nothing ran. Use before claiming any change works, and when deciding which rung an acceptance criterion belongs to.
---

# The verification ladder

Six rungs. Every acceptance criterion declares exactly one.

| Rung | Proves | Automatable |
|---|---|---|
| **V0** | It is syntactically valid GDScript and passes lint | yes |
| **V1** | The project imports and loads; `.uid` sidecars are in sync | yes |
| **V2** | Pure logic behaves — resolvers, damage maths, state transitions | yes |
| **V3** | A scene behaves when instanced and driven by simulated input | yes, except `Control` |
| **V4** | A full run reaches a goal, deterministically, from a fixed seed | fragile |
| **V5** | It feels right, reads clearly, is fun | **no** |

Run them with `.claude/scripts/verify.sh V3`. Do not hand-roll the commands:
the script exists for the traps below, and every one of them produces a green
gate over a broken project.

## The traps

**Godot exits 0 after a `SCRIPT ERROR`.** The exit code says the process ended,
not that it worked. Any check that runs the engine must also scan the output
for `SCRIPT ERROR` / `ERROR:`.

**A test runner that found no tests exits 0.** Three causes: the project was
never imported, so `class_name` scripts did not exist; the test directory path
is wrong; the report directory did not exist. The only defence is asserting
that the JUnit XML exists *and* reports more than zero tests.

**gdUnit4 refuses headless** and exits `103` before running anything, unless
given `--ignoreHeadlessMode`. Its other codes: `0` pass, `100` failures, `101`
passed but leaked a node.

**`--headless` does not deliver clicks to `Control` nodes.** Simulated clicks
reach `_input` but never press a `Button`. UI interaction needs Xvfb, or the
criterion moves to V5.

**`--write-movie` needs a display.** It crashes under `--headless`. Use Xvfb.

**New files have no `.uid`** until the project is imported. Run
`--headless --path . --import` before committing, or references break for
everyone else.

## Choosing a rung

The question is not "could this be tested", it is "what does passing actually
prove".

- "Dash speed equals the configured value for the configured duration" → V2.
- "Dashing into a wall returns to Idle on the same frame" → V3, it needs a
  scene and a collision.
- "The corridor is crossed in ≤ 4.0s with seed 42" → V4.
- "The dash feels responsive" → **V5**. Writing it as a V3 assertion about
  input latency measures something adjacent and reports a verdict on something
  it did not test.

A system with everything at V5 is honest when the value is perceptual. A logic
system with nothing at V2–V4 is a finding: it is probably too coupled to nodes.

## Reporting

Say which rungs ran, which did not, and which were not applicable. "No
integration tests exist" and "integration tests passed" must never read the
same. Never describe a system as done while V5 items are open in
`.godotspec/checks.md`.

Exact commands: `references/commands.md`.
