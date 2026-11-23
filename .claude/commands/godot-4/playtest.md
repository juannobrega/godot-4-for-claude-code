---
description: Run the deterministic bot (V4) and produce the human playtest script (V5)
argument-hint: <system-slug>
---

Two halves, for the two rungs no unit test reaches.

## V4 — the bot

If the system's plan declares a V4 criterion and `tools/bot.gd` has no scenario
for it, write one from `.claude/scripts/bot_template.gd`.

The template exists mainly for one line: Godot exits 0 after a `SCRIPT ERROR`,
so the bot must call `get_tree().quit(1)` itself on failure. A bot without that
reports success for a run that crashed.

Run through `.claude/scripts/verify.sh V4`. Fixed fps and a fixed seed, or the
run is not evidence of anything.

## V5 — the human script

Write the playtest script into `.godotspec/checks.md`, one entry per V5
criterion:

```
### AC-035 — the dash feels responsive            SYS-004
How to try it:  load res://levels/test_corridor.tscn, dash into the wall,
                dash while attacking, dash at the lowest frame rate you ship at
What to watch:  delay between press and movement; whether the i-frame window
                is readable; whether the trail reads direction at a glance
Verdict:        [ ] good   [ ] needs tuning: ______   [ ] wrong design
```

Make it something the user can act on in two minutes without re-reading the
spec. A V5 item that requires reconstructing the context is a V5 item that
never gets judged.

## Never

Mark a V5 criterion closed. Only `/godot-4:review` does that, from what the
human wrote.
