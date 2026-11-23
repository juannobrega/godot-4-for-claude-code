---
description: Order milestones into vertical slices with two-column done criteria
argument-hint: ""
---

Write or revise `.godotspec/roadmap.md`.

## Shape

Milestones hold phases. Every phase is a **vertical slice** — something
playable, however small. "All the data classes" is not a phase; "you can move
and hit one enemy" is.

## Two-column done criteria

Every phase states what done means, split:

| Done when — an agent can check | Done when — only you can judge |
|---|---|
| `verify.sh V3` green for SYS-004, SYS-005 | The corridor is fun to move through |
| No `[DESIGN DECISION]` left open | The enemy reads as threatening |

This split is the whole point of the file. A roadmap whose criteria are all in
the left column is lying about what shipping a game requires; one whose
criteria are all on the right cannot be worked on unattended.

## IDs

Decisions taken at roadmap level get milestone scope: `D-M2-01`. Phase scope:
`D-M2-P3-01`. They go in `.godotspec/decisions.md`.

## Do not

Estimate dates. Order, dependency and done-criteria are what this file is for.
