---
name: godot-release
description: Export presets and release builds for Godot 4 from the command line. Use when producing a build for distribution or wiring exports into CI.
---

# Release builds

## Export from the command line

```bash
# the editor binary is required: export templates live with the editor
godot --headless --path . --export-release "Linux/X11" build/game
godot --headless --path . --export-debug   "Linux/X11" build/game-debug
godot --headless --path . --export-pack    "Linux/X11" build/game.pck
```

The preset name must match `export_presets.cfg` exactly, quotes included.

## Before every export

```bash
godot --headless --path . --import     # stale imports ship as missing assets
.claude/scripts/verify.sh V3
```

An export runs even with broken scripts. It produces a binary that crashes on
launch, and the exit code does not say so — scan the output for
`SCRIPT ERROR` the same way every other rung does.

## Export templates

Missing templates fail the export with a message that reads like a path
problem. They are versioned: templates for 4.7.2 do not serve a 4.7.1 binary.
In CI, install them for the exact engine version from `config.yml`.

## What to check in a built artifact

- It launches and reaches the main menu
- `user://` paths resolve — a save path that works in the editor can fail in
  an export when it assumed `res://` was writable
- Resources referenced only by string path are present: they are not in the
  dependency graph and get stripped

That last one is the usual "works in editor, broken in build" cause. Prefer
`preload` and typed `@export` over `load("res://" + name)`.

## Versioning

The build carries the version from the project settings, not from git. Set it
explicitly in CI rather than letting it drift from the tag.
