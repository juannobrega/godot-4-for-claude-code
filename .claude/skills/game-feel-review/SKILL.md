---
name: game-feel-review
description: Structured review of game feel — input responsiveness, buffering, coyote time, hitstop, camera behaviour, readability. Use when preparing a V5 playtest script or when the user reports that something feels wrong without knowing why.
---

# Game feel review

V5 is human judgement and no agent closes it. What an agent can do is turn
"it feels off" into a specific, checkable list — and write the playtest script
that gets the human a verdict in two minutes.

## Input

| Symptom | Usual cause |
|---|---|
| Action sometimes "doesn't register" | No input buffering: the press landed one frame before the state allowed it |
| Jumps missed at ledges | No coyote time: ~6 frames of grace after leaving ground |
| Feels mushy, not slow | Acceleration curve, not top speed |
| Feels twitchy | No deceleration ramp; velocity snaps to zero |

Buffering and coyote time are the two that read as "the controls are broken"
and are almost never diagnosed as missing features.

## Impact

Hitstop — freezing for 2–6 frames on a hit — does more for weight than any
amount of damage number tuning. Paired with a short camera shake and a flash,
it is most of what "punchy" means.

Check that hitstop is applied to the right scope: freezing the whole tree
stops the UI and the music too.

## Camera

Lead the movement, do not follow it. A camera that lags behind the player
makes everything feel heavier than intended. Look-ahead on the input vector,
smoothed, with a deadzone so small corrections do not swim.

Shake needs a decay curve and a cap. Uncapped shake from stacked hits is
nausea, not feedback.

## Readability

- Can the player tell, in one frame, which state they are in?
- Does the telegraph for an attack last long enough to react at the slowest
  frame rate you ship at?
- Does the VFX for a mechanic compete with the VFX for damage?

Readability failures are reported as "too hard" far more often than as
"I couldn't see it".

## Writing the V5 script

Into `.godotspec/checks.md`, per criterion:

```
### AC-035 — the dash feels responsive            SYS-004
How to try it:  test_corridor.tscn; dash into a wall; dash mid-attack;
                dash at the lowest frame rate you ship at
What to watch:  press-to-move delay; whether the i-frame window reads;
                whether the trail communicates direction at a glance
Verdict:        [ ] good   [ ] needs tuning: ______   [ ] wrong design
```

Specific enough to act on without rereading the spec. A V5 item that needs
context reconstruction is a V5 item that stays open forever.

## When the verdict is "needs tuning"

Do not change code. The value belongs in the tuning Resource — use
`/godot-4:tune`. If it is not in the surface, that is a spec bug worth
reporting before patching.
