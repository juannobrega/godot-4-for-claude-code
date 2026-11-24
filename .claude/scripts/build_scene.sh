#!/usr/bin/env bash
# Builds a .tscn from a declarative scene contract.
#
#   build_scene.sh <contract.json>
#
# The contract is committed, so the scene is regenerable: re-run this and the
# .tscn comes back identical except for its uid. That is the whole reason this
# route exists instead of editing scene files as text.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"

CONTRACT="${1:-}"
[ -n "$CONTRACT" ] || { echo "usage: build_scene.sh <contract.json>" >&2; exit 1; }
[ -f "$CONTRACT" ] || { echo "error: no such contract: $CONTRACT" >&2; exit 1; }

godot_env_load
case $? in
  1) echo "error: no project.godot found" >&2; exit 1 ;;
  2) echo "error: Godot binary not found. Set godot_bin in .godotspec/config.yml." >&2; exit 1 ;;
esac

# Fail on malformed JSON here, with the line number, rather than inside Godot.
PARAMS="$(python3 -c '
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as exc:
    sys.exit(f"error: {sys.argv[1]} is not valid JSON ({exc})")
for key in ("path", "root"):
    if key not in data:
        sys.exit(f"error: the contract needs a \"{key}\" key")
print(json.dumps(data, separators=(",", ":")))' "$CONTRACT")" || exit 1

OUT="$("$GODOT_BIN" --headless --path "$GODOT_PROJECT" \
       --script .claude/scripts/godot_ops.gd build_scene "$PARAMS" 2>&1)"
RC=$?

printf '%s\n' "$OUT" | grep -vE '^Godot Engine|^$'

# The engine exits 0 after a script error, so the output decides, not the code.
if [ "$RC" -ne 0 ] || printf '%s' "$OUT" | grep -qE 'SCRIPT ERROR|Parse Error|^godot_ops: '; then
  echo "build_scene: failed" >&2
  exit 1
fi

# A new .tscn has no .uid sidecar question, but the project still needs the
# import so other scenes can reference it.
"$GODOT_BIN" --headless --path "$GODOT_PROJECT" --import >/dev/null 2>&1
exit 0
