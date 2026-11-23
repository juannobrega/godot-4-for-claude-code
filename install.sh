#!/usr/bin/env bash
# Installs the godot-4 framework into a Godot project.
#
#   ./install.sh                  install into the Godot project you are in,
#                                 found by walking up from here
#   ./install.sh --here           install into this directory, no searching;
#                                 the directory may be empty
#   ./install.sh <project-dir>    install into that directory
#
#   --dry-run   print what would be written and write nothing
#   --help
#
# Copies skills, commands, agents, scripts and templates into <target>/.claude/
# and MERGES the hooks into an existing settings.json rather than replacing it:
# a real project probably has hooks of its own.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
TARGET=""
NO_PROJECT=0
HERE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    --here)   HERE=1; shift ;;
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

if [ "$HERE" -eq 1 ]; then
  [ -n "$TARGET" ] && { echo "error: --here takes no target" >&2; exit 2; }
  # Explicit intent: this directory, whatever is in it. No searching upward,
  # because the point of the flag is that the answer is not up for inference.
  DEST="$PWD"
  [ -f "$DEST/project.godot" ] || NO_PROJECT=1
elif [ -n "$TARGET" ]; then
  [ -d "$TARGET" ] || { echo "error: not a directory: $TARGET" >&2; exit 1; }
  DEST="$(cd "$TARGET" && pwd)"
  if [ ! -f "$DEST/project.godot" ]; then
    echo "warning: $DEST has no project.godot." >&2
    echo "The framework installs, but every hook stays inert until it does." >&2
  fi
else
  # No target: prefer the project root above us, so running from a
  # subdirectory still installs in the right place. Falling back to the current
  # directory is deliberate -- the framework is inert without project.godot, so
  # installing here is useless rather than harmful, and refusing would block a
  # legitimate "set it up now, add the project later".
  DEST="$(find_project_root "$PWD" || true)"
  if [ -z "$DEST" ]; then DEST="$PWD"; NO_PROJECT=1; fi
fi

# The package is never its own target. unzip drops the package directory into
# the current folder, so one stray cd puts .claude inside it instead of in the
# project -- silently, and the hooks then never load.
case "$DEST/" in
  "$SRC"/* | "$SRC/")
    # Two different mistakes land here, and they need different advice.
    if [ -f "$SRC/tools/validate_kit.py" ]; then
      cat >&2 <<MSG
error: $DEST is the godot-4 framework repository, so there is nothing to install.

Its .claude/ directory is the source this installer copies from; installing it
onto itself would copy the tree over itself. To install into a game, name it:

    $0 /path/to/your-godot-project
MSG
    else
      cat >&2 <<MSG
error: $DEST is inside the godot-4 package, not a Godot project.

Installing there would put .claude next to the installer, where Claude Code
never looks. Run the installer from your project instead:

    cd /path/to/your-godot-project
    $SRC/install.sh
MSG
    fi
    exit 1 ;;
esac

# Now that the destination is settled, explain it.
if [ "$NO_PROJECT" -eq 1 ] && [ "$HERE" -eq 1 ]; then
  # The flag said "here", so this is a note, not a correction.
  echo "note: $DEST has no project.godot yet; hooks stay inert until it does." >&2
elif [ "$NO_PROJECT" -eq 1 ]; then
  echo "warning: no project.godot in $DEST or any directory above it." >&2
  if [ -d "$DEST/.claude/skills/using-godot-4" ] && [ -f "$DEST/tools/validate_kit.py" ]; then
    echo "This looks like the godot-4 framework repository itself, not a game." >&2
  fi
  echo "Installing here anyway; hooks stay inert until project.godot exists." >&2
  echo "To be explicit, use --here; to install into a game, name it:" >&2
  echo "    $0 /path/to/your-godot-project" >&2
elif [ -z "$TARGET" ] && [ "$HERE" -eq 0 ] && [ "$DEST" != "$PWD" ]; then
  echo "found project root at $DEST" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "would install into $DEST/.claude/"
  for d in skills commands agents scripts templates; do
    [ -d "$SRC/.claude/$d" ] && echo "  $d/ ($(find "$SRC/.claude/$d" -type f -not -name '*.pyc' | wc -l | tr -d ' ') files)"
  done
  echo "  settings.json (hooks merged, existing entries kept)"
  exit 0
fi

# Parity with install.ps1: an unparseable settings.json in the target must abort
# before anything is copied, not after, so a failed install leaves no half-state.
if [ -f "$DEST/.claude/settings.json" ]; then
  python3 - "$DEST/.claude/settings.json" <<'CHECK' || exit 1
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as exc:
    sys.exit(f"error: {path} is not valid JSON ({exc}).\n"
             "Nothing was installed. Fix the file and run the installer again.")
if not isinstance(data, dict):
    sys.exit(f"error: {path} must contain a JSON object. Nothing was installed.")
hooks = data.get("hooks")
if hooks is not None and not isinstance(hooks, dict):
    sys.exit(f"error: {path} has a 'hooks' entry that is not an object. "
             "Nothing was installed.")
CHECK
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
