---
name: godot-parallel-work
description: Running more than one agent or session on the same Godot project safely — worktrees, the .godot cache, user:// collisions, .uid sidecars and project.godot merges. Use when work is split across sessions or branches.
---

# Parallel work on one Godot project

Four things break when two sessions touch one Godot project. Each has a
specific fix.

## 1. File conflicts

Plans declare a **check-out set**: every path the work will touch. Two plans
with disjoint sets may run at once.

`project.godot` and autoload scripts are **always sequential**. They
accumulate shared state, so every parallel edit to them collides.

```bash
git worktree add ../game-shop -b shop-screen
```

## 2. Asset reimport in every new checkout

`.godot/` is gitignored, so a fresh worktree reimports every asset — minutes
on a real project.

```bash
cp -r .godot ../game-shop/.godot
```

## 3. `user://` collides between copies

Godot names the user directory after the project, so a test run in one
worktree reads and overwrites the saves of another. Give each copy its own:

```ini
; ../game-shop/override.cfg
[config]
custom_user_dir_name="game-agents/shop"
```

## 4. Missing `.uid` sidecars

A script created outside the editor has no `.uid` until the project is
imported. Commit without it and references break for everyone else.

```bash
godot --headless --path ../game-shop --import
.claude/scripts/check_uid.sh          # lists anything still missing
```

## Merging back

One branch at a time, from the main checkout. `project.godot` will conflict:
resolve by hand and **keep every autoload entry from both sides**. Taking one
side wholesale silently removes a global service and the failure shows up as
a null reference somewhere unrelated.

After each merge: `--import`, then `verify.sh V1`, before the next merge.

## Verify before merging

Record evidence per branch, not once at the end. A branch merged without its
own `verify.sh` run makes the next failure impossible to attribute.
