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
echo "Standing rules: GDScript 4 only (await, instantiate(), @export, sig.connect(cb));"
echo "explicit static types everywhere; %UniqueName over node paths; no structural"
echo "text edits to .tscn/.tres; tuning numbers live in a Resource, not in code."

# A pinned version in the constitution that the binary does not match is worth
# more attention than the rules above, so it goes last where it is read first.
if [ -f "$GODOTSPEC/constitution.md" ]; then
  PIN="$(sed -n 's/^[-*][[:space:]]*Engine:[[:space:]]*\(.*\)$/\1/p' "$GODOTSPEC/constitution.md" | head -1)"
  if [ -n "$PIN" ] && [ -n "$GODOT_VERSION" ] && [ "${GODOT_VERSION#"$PIN"}" = "$GODOT_VERSION" ]; then
    echo "WARNING: constitution pins engine '$PIN' but the binary is '$GODOT_VERSION'."
  fi
fi
