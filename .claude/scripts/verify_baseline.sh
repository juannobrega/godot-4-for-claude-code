#!/usr/bin/env bash
# SessionStart hook. Marks the point from which "has anything changed that was
# never verified?" is measured. See require_verify.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"
godot_env_load || exit 0
mkdir -p "$GODOTSPEC/.session"
: > "$GODOTSPEC/.session/baseline"
# Stale marker from a previous session would wrongly count as "already verified".
rm -f "$GODOTSPEC/.session/last-verify"
exit 0
