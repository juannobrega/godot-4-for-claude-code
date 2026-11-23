#!/usr/bin/env bash
# UserPromptSubmit hook. Prints a short standing context that is cheap enough
# to carry on every turn: which engine version this project actually is, and
# the handful of rules that are violated most often when it is absent.
# Silent outside a Godot project.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"
godot_env_load || exit 0

FEATURE="$(godot_project_feature_version)"
echo "Godot project: ${GODOT_VERSION:-unknown binary}${FEATURE:+ (project declares $FEATURE)}"

# The standing rules belong in the project's CLAUDE.md, which loads once per
# session. Repeating them every turn costs tokens on every message to deliver
# something that does not change. They are printed here only as a fallback,
# when /godot-4:init has not wired CLAUDE.md yet.
if ! grep -q 'godotspec/constitution.md' "$GODOT_PROJECT/CLAUDE.md" 2>/dev/null; then
  echo "Standing rules: GDScript 4 only (await, instantiate(), @export, sig.connect(cb));"
  echo "explicit static types everywhere; %UniqueName over node paths; no structural"
  echo "text edits to .tscn/.tres; tuning numbers live in a Resource, not in code."
  echo "(Run /godot-4:init to move these into CLAUDE.md and stop repeating them.)"
fi

# A pinned version in the constitution that the binary does not match is worth
# more attention than the rules above, so it goes last where it is read first.
if [ -f "$GODOTSPEC/constitution.md" ]; then
  # Strip a trailing comment and whitespace: the version has to end up a bare
  # prefix of what the binary reports, or the comparison below always fails and
  # the warning fires on every prompt instead of only on a real mismatch.
  PIN="$(sed -n 's/^[-*][[:space:]]*Engine:[[:space:]]*\(.*\)$/\1/p' "$GODOTSPEC/constitution.md" \
         | head -1 | sed 's/<!--.*//; s/#.*//; s/[[:space:]]*$//')"
  if [ -n "$PIN" ] && [ -n "$GODOT_VERSION" ] && [ "${GODOT_VERSION#"$PIN"}" = "$GODOT_VERSION" ]; then
    echo "WARNING: constitution pins engine '$PIN' but the binary is '$GODOT_VERSION'."
  fi
fi
