#!/usr/bin/env bash
# Installs the godot-4 framework into a Godot project.
#
#   ./install.sh                     install into the Godot project you are in
#   ./install.sh <project-dir>       install into that project
#   ./install.sh --dry-run           show what would be written, write nothing
#   ./install.sh --help
#
# Copies skills, commands, agents, scripts and templates into <target>/.claude/
# and MERGES the hooks into an existing settings.json rather than replacing it:
# a real project probably has hooks of its own.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -*) echo "error: unknown option $1 (try --help)" >&2; exit 2 ;;
    *)  [ -n "$TARGET" ] && { echo "error: more than one target given" >&2; exit 2; }
        TARGET="$1"; shift ;;
  esac
done

# Walk up for project.godot so the installer works from any subdirectory of the
# project. The previous default of $PWD installed wherever the shell happened to
# be -- including inside the unzipped package, which is where .claude landed for
# the first person who ran it.
find_project_root() {
  local d="$1"
  while [ "$d" != "/" ]; do
    [ -f "$d/project.godot" ] && { printf '%s\n' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

if [ -n "$TARGET" ]; then
  [ -d "$TARGET" ] || { echo "error: not a directory: $TARGET" >&2; exit 1; }
  DEST="$(cd "$TARGET" && pwd)"
  if [ ! -f "$DEST/project.godot" ]; then
    echo "warning: $DEST has no project.godot." >&2
    echo "The framework installs, but every hook stays inert until it does." >&2
  fi
else
  DEST="$(find_project_root "$PWD" || true)"
  if [ -z "$DEST" ]; then
    cat >&2 <<MSG
error: no project.godot in $PWD or any directory above it.

Run this from inside your Godot project, or name it:
    $0 /path/to/your-godot-project
MSG
    exit 1
  fi
fi

# The package is never its own target. unzip drops the package directory into
# the current folder, so one stray cd puts .claude inside it instead of in the
# project -- silently, and the hooks then never load.
case "$DEST/" in
  "$SRC"/* | "$SRC/")
    cat >&2 <<MSG
error: $DEST is inside the godot-4 package, not a Godot project.

Installing there would put .claude next to the installer, where Claude Code
never looks. Run the installer from your project instead:

    cd /path/to/your-godot-project
    $SRC/install.sh
MSG
    exit 1 ;;
esac

if [ "$DRY_RUN" -eq 1 ]; then
  echo "would install into $DEST/.claude/"
  for d in skills commands agents scripts templates; do
    [ -d "$SRC/.claude/$d" ] && echo "  $d/ ($(find "$SRC/.claude/$d" -type f -not -name '*.pyc' | wc -l | tr -d ' ') files)"
  done
  echo "  settings.json (hooks merged, existing entries kept)"
  exit 0
fi

echo "installing into $DEST/.claude/"
mkdir -p "$DEST/.claude"
for d in skills commands agents scripts templates; do
  [ -d "$SRC/.claude/$d" ] || continue
  mkdir -p "$DEST/.claude/$d"
  cp -R "$SRC/.claude/$d/." "$DEST/.claude/$d/"
  echo "installed .claude/$d"
done
# py_compile leaves these beside the scripts in a working copy. The release
# package strips them, but someone installing from a git clone would not.
find "$DEST/.claude" \( -name '__pycache__' -o -name '*.pyc' \) -exec rm -rf {} + 2>/dev/null || true
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
