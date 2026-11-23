#!/usr/bin/env bash
# Stop hook. Refuses to end the turn while GDScript or scene files have changed
# and no rung of the ladder has been run since. "It compiles in my head" is the
# single most common way agent-written Godot code reaches a commit broken.
#
# Exit 2 blocks the stop and sends stderr back to Claude.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"
godot_env_load || exit 0

[ "${GODOT4_VERIFY_OFF:-}" = "1" ] && exit 0

# Claude Code sets stop_hook_active when it is already continuing because of a
# stop hook. Blocking again there would loop forever.
INPUT="$(cat 2>/dev/null || true)"
case "$INPUT" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac

SESS="$GODOTSPEC/.session"
MARK="$SESS/last-verify"; [ -f "$MARK" ] || MARK="$SESS/baseline"
[ -f "$MARK" ] || exit 0   # no baseline: session started before the kit existed

CHANGED="$(find "$GODOT_PROJECT" \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) \
  -not -path '*/.godot/*' -not -path '*/addons/*' -newer "$MARK" 2>/dev/null | head -5)"
[ -z "$CHANGED" ] && exit 0

{
  echo "Unverified changes. These files changed and no verification has run since:"
  printf '%s\n' "$CHANGED" | sed "s|^$GODOT_PROJECT/|  |"
  echo
  echo "Run:  .claude/scripts/verify.sh V1      (parse, import, uid sidecars)"
  echo "      .claude/scripts/verify.sh V3      (also unit and integration tests)"
  echo
  echo "If a rung legitimately cannot run here, say so and set GODOT4_VERIFY_OFF=1."
} >&2
exit 2
