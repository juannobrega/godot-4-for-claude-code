---
name: godot-mcp-bridge
description: Using a connected Godot MCP server alongside this kit, and knowing what it does and does not replace. Use only when an MCP Godot server is configured in the session.
---

# Godot MCP bridge

MCP is optional in this kit. Everything works through the headless CLI, which
runs on any machine and in CI. An MCP server improves the interactive loop; it
replaces no rung of the ladder.

## What it is good for

- **Structural scene edits with a live UID index.** A server that edits through
  the editor's own API keeps `uid://` and sidecars consistent — the one thing
  text editing cannot do safely. This is the strongest reason to connect one.
- Reading the real scene tree instead of parsing `.tscn`.
- Running the project and reading debug output without shelling out.
- Screenshots during an inspect/edit/run loop.

## What it is not good for

**It does not replace verification.** The servers that genuinely play a game
require the editor open and do not run in CI. `verify.sh` remains the gate;
MCP is a faster way to reach the point where the gate is worth running.

**It does not close V5.** A screenshot is evidence for a human judgement, not
the judgement.

## Using it in this kit

Check which server is connected before relying on a tool name — the ecosystem
has many implementations with different tool sets and none is canonical.
Always use fully qualified names (`ServerName:tool_name`).

When a server is connected, `plan.md` may choose MCP as the creation route for
a structural scene change instead of deferring it to the user's editor. Say so
in the plan, so a later session without MCP knows why the scene has no build
script.

## When it is absent

Nothing changes. Structural scene work goes to a build script for new scenes,
or to the user in the editor for existing ones. See `godot-scene-contracts`.
