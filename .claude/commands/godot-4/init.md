---
description: Bootstrap the spec kit in a Godot project — detect the engine, discover existing conventions, propose a constitution
argument-hint: ""
---

Set up `.godotspec/` in this project.

Do not impose a house style. This project already has conventions; find them
and write them down. A constitution the user recognises is a constitution the
user keeps.

## 1. Detect the environment

Run `.claude/scripts/godot_env.sh` logic by invoking any script that sources it
(`.claude/scripts/check_uid.sh --count` is cheapest), and read `project.godot`
for `config/features`, renderer and autoloads.

Stop and ask if there is no `project.godot`: this kit only runs inside a Godot
project.

## 2. Discover conventions — read, do not assume

Sample the codebase and record what it actually does:

- Typing: what share of `var`/parameters/returns carry explicit types?
- Node access: `%UniqueName` or `get_node()` paths?
- Signals: naming shape, and whether an event-bus autoload exists
- Folder layout: scene-adjacent scripts, or a central `res://scripts/`?
- Autoloads already registered, and what each is for
- Test framework present under `addons/`
- Any Godot 3 API still in the tree (`yield`, `.instance()`, `export var`)

## 3. Write the artefacts

Create, from `.claude/templates/`:

- `.godotspec/config.yml` — binary, engine version, test framework, test dirs
- `.godotspec/constitution.md` — the rules, with each one reflecting what you
  found. Mark anything you could not observe as `(assumed)`
- `.godotspec/.gdignore` — empty file. Without it the Godot editor tries to
  import the markdown in `.godotspec/`
- `.godotspec/systems/` — empty

## 4. Report

Show the user the constitution you propose and the evidence for each rule
("typed: 84% of declarations", "found 3 Godot 3 calls in 2 files"). Ask them to
correct it before anything else is built on top of it.

If you found Godot 3 API still in the tree, say so plainly — it will poison
every subsequent generation if left unflagged.
