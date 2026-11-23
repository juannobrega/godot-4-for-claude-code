#!/usr/bin/env bash
# PostToolUse hook for .gd writes: lint and parse the file that was just
# written, immediately, while the change is still in context.
#
# Exit 2 reports findings back to Claude. Formatting is never applied
# automatically: gdformat has produced code the engine rejects, so a format is
# only ever safe when a parse check follows it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"

INPUT="$(cat 2>/dev/null || true)"
FILE="$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
case "$FILE" in *.gd) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0
godot_env_load || exit 0
case "$FILE" in "$GODOT_PROJECT"/addons/*) exit 0 ;; esac   # third-party code

OUT=""
if command -v gdlint >/dev/null 2>&1; then
  L="$(gdlint "$FILE" 2>&1)" || OUT="$OUT$L"$'\n'
fi
REL="res://${FILE#"$GODOT_PROJECT"/}"
P="$("$GODOT_BIN" --headless --path "$GODOT_PROJECT" --check-only -s "$REL" 2>&1)"
# The engine exits 0 after a parse error, so look at what it printed.
if printf '%s' "$P" | grep -qE '^(SCRIPT ERROR|ERROR|Parse Error)'; then
  OUT="$OUT$P"$'\n'
fi

SESS="$GODOTSPEC/.session"; mkdir -p "$SESS"

# A clean write ends the streak. Without this the escalation below fires on
# every later failure in the session, however many good writes came between.
if [ -z "$OUT" ]; then
  rm -f "$SESS/lint-fails"
  exit 0
fi

N=$(( $(cat "$SESS/lint-fails" 2>/dev/null || echo 0) + 1 ))
echo "$N" > "$SESS/lint-fails"

{
  echo "${FILE##*/} did not pass lint/parse:"
  printf '%s\n' "$OUT"
  if [ "$N" -ge 3 ]; then
    echo "This is failure $N in a row. Stop patching and re-read the file as a whole,"
    echo "or ask the user — repeated near-misses usually mean a wrong assumption"
    echo "about the API, not a typo."
  fi
} >&2
exit 2
