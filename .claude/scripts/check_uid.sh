#!/usr/bin/env bash
# Lists scripts that have no .uid sidecar.
#
#   check_uid.sh            list the offending files
#   check_uid.sh --count    print only how many there are
#
# Godot 4.4+ writes a .uid beside every *script*. Text resources (.tscn, .tres)
# carry their uid in their own header instead and have no sidecar -- verified on
# 4.7.2 -- so looking for one beside them reports a failure that cannot be fixed.
# Agents move a .gd and leave its .uid behind, and a script created outside the
# editor has none until the project is imported. Either way references break.
# Fix: godot --headless --path . --import
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"
godot_env_load || exit 0

COUNT_ONLY=0
[ "${1:-}" = "--count" ] && COUNT_ONLY=1

missing=0
while IFS= read -r f; do
  [ -f "${f}.uid" ] || { missing=$((missing+1)); [ "$COUNT_ONLY" -eq 0 ] && echo "${f#$GODOT_PROJECT/}"; }
done < <(find "$GODOT_PROJECT" -name '*.gd' \
           -not -path '*/.godot/*' -not -path '*/addons/*' \
           -not -path '*/.claude/*')

if [ "$COUNT_ONLY" -eq 1 ]; then echo "$missing"; exit 0; fi
[ "$missing" -gt 0 ] && echo "--- $missing missing. Fix: \"$GODOT_BIN\" --headless --path \"$GODOT_PROJECT\" --import" >&2
exit 0
