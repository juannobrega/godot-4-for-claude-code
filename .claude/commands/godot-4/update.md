---
description: Update the installed framework to a newer release, reading the changelog and reconciling local changes
argument-hint: "[--dry-run]"
---

Update this project's copy of the godot-4 framework.

The mechanical half is `installer.py`, which does a deterministic diff against
`.claude/.godot-4-manifest.json`. Your job is the half a script cannot do:
reading what changed and deciding what it means **for this project**.

## 1. Establish where we are

```bash
python3 -c "import json;d=json.load(open('.claude/.godot-4-manifest.json'));print(d['version'])"
```

No manifest means the framework was installed before manifests existed, or by
hand. Say so: the first update cannot clean up stale files, because there is no
record of what was delivered. It can still install over the top.

## 2. Find out what is new

```bash
curl -fsSL https://api.github.com/repos/juannobrega/godot-4-for-claude-code/releases/latest
```

Read the `tag_name` and the `body`. If it matches the manifest version, stop and
say the project is current — do not download anything.

## 3. Download and preview

```bash
curl -fsSL https://github.com/juannobrega/godot-4-for-claude-code/releases/latest/download/godot-4.tar.gz | tar -xz -C /tmp
/tmp/godot-4/install.sh --dry-run
```

The dry run prints what is new, updated, removed, and which files you edited
locally. **Read it before applying.**

## 4. Explain it for this project, not in general

This is the step that justifies a command instead of a shell one-liner. For each
change in the release notes, say whether it touches this project:

- A removed skill — was it being used? Check `.godotspec/systems/*/plan.md`.
- A renamed or removed hook — does the project override it in `settings.json`?
- A changed template — do existing artefacts in `.godotspec/systems/` still
  match? A `spec.md` written against the old template is not broken, but a new
  required section will be missing from all of them.
- A MAJOR bump — `release-process.md` defines that as "a project that already
  uses the kit must change a file of its own". Find which files, and say so.

## 5. Decide the conflicts with the user

Every locally modified file is a decision, not a problem to route around:

- **Keep** — the edit matters. The `.new` file sits beside it for diffing. Say
  plainly that the project is now running a modified framework file.
- **Take theirs** — re-run with `--force`.

Never resolve a conflict silently. A skill the user tuned for their project is
the most likely thing to be edited, and the most costly to lose.

## 6. Apply, then stop

```bash
/tmp/godot-4/install.sh
```

Then reconcile the constitution. The project's `.godotspec/constitution.md` was
discovered from **this** codebase by `/godot-4:init`; the template is a default.
If the new version changed the template, propose the additions rather than
overwriting — overwriting erases what the project is.

Finish with `/godot-4:handoff`, then tell the user:

> Skills and hooks load at session start, so this update does not affect the
> current session. Restart, and the new session picks up the handoff.

That is not a caveat to bury. An agent that keeps working after an update is
running the old framework while describing the new one.
