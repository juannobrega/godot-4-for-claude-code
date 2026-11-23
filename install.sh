#!/usr/bin/env bash
# Installs the godot-4 framework into a Godot project.
#
#   ./install.sh [target-project-dir]      (defaults to the current directory)
#
# Copies skills, commands, agents, scripts and templates into <target>/.claude/
# and MERGES the hooks into an existing settings.json rather than replacing it:
# a real project probably has hooks of its own.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$PWD}"
DEST="$(cd "$DEST" && pwd)"

if [ ! -f "$DEST/project.godot" ]; then
  echo "warning: $DEST has no project.godot." >&2
  echo "The framework installs, but every hook stays inert until it does." >&2
fi

mkdir -p "$DEST/.claude"
for d in skills commands agents scripts templates; do
  [ -d "$SRC/.claude/$d" ] || continue
  mkdir -p "$DEST/.claude/$d"
  cp -R "$SRC/.claude/$d/." "$DEST/.claude/$d/"
  echo "installed .claude/$d"
done
chmod +x "$DEST"/.claude/scripts/*.sh "$DEST"/.claude/scripts/*.py 2>/dev/null || true

python3 - "$SRC/.claude/settings.json" "$DEST/.claude/settings.json" <<'PY'
import json, sys, os

src_path, dest_path = sys.argv[1], sys.argv[2]
incoming = json.load(open(src_path)).get("hooks", {})

if os.path.exists(dest_path):
    with open(dest_path) as fh:
        existing = json.load(fh)
else:
    existing = {}

hooks = existing.setdefault("hooks", {})
added = 0
for event, groups in incoming.items():
    current = hooks.setdefault(event, [])
    for group in groups:
        # Identify a group by the scripts it runs, so re-installing is a no-op
        # and a hand-edited matcher is not silently reverted.
        cmds = {h.get("command") for h in group.get("hooks", [])}
        if any(cmds & {h.get("command") for h in g.get("hooks", [])} for g in current):
            continue
        current.append(group)
        added += 1

with open(dest_path, "w") as fh:
    json.dump(existing, fh, indent=2)
    fh.write("\n")
print(f"merged {added} hook group(s) into .claude/settings.json")
PY

cat <<'MSG'

Done. Next:

  /godot-4:init     detect the engine and propose a constitution

The hooks are active from the next session in this project. Everything stays
inert in a directory with no project.godot.
MSG
