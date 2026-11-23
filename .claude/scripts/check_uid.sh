#!/usr/bin/env bash
# Lists scripts and resources that have no .uid sidecar.
#
#   check_uid.sh            list the offending files
#   check_uid.sh --count    print only how many there are
#
# Godot 4.4+ writes a .uid beside every script and resource. Agents move a .gd
# and leave its .uid behind, and a file created outside the editor has none
# until the project is imported. Either way the references break silently.
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
done < <(find "$GODOT_PROJECT" \( -name '*.gd' -o -name '*.tres' \) \
           -not -path '*/.godot/*' -not -path '*/addons/*')

if [ "$COUNT_ONLY" -eq 1 ]; then echo "$missing"; exit 0; fi
[ "$missing" -gt 0 ] && echo "--- $missing missing. Fix: \"$GODOT_BIN\" --headless --path \"$GODOT_PROJECT\" --import" >&2
exit 0
