#!/usr/bin/env bash
# Scaffolds .godotspec/systems/<nnn>-<slug>/ from the templates.
#   new_system.sh dash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"
godot_env_load || { echo "no project.godot found" >&2; exit 1; }

SLUG="${1:-}"
[ -z "$SLUG" ] && { echo "usage: new_system.sh <slug>" >&2; exit 1; }
case "$SLUG" in *[!a-z0-9-]*) echo "slug must be lowercase, digits and hyphens" >&2; exit 1 ;; esac

mkdir -p "$GODOTSPEC/systems"
# Next free number, zero padded, so systems sort in creation order.
N=0
for d in "$GODOTSPEC"/systems/[0-9][0-9][0-9]-*; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"; n="${n%%-*}"; n="${n#00}"; n="${n#0}"
  [ "${n:-0}" -gt "$N" ] && N="$n"
done
ID="$(printf '%03d' $((N + 1)))"
DIR="$GODOTSPEC/systems/$ID-$SLUG"
[ -d "$DIR" ] && { echo "$DIR already exists" >&2; exit 1; }
mkdir -p "$DIR/evidence"

# dash-attack -> DashAttack, so templates can name a GDScript class correctly.
CLASS="$(printf '%s' "$SLUG" | awk -F- '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1)) substr($i,2)}')"

TPL="$SCRIPT_DIR/../templates"
for f in spec plan tasks contract; do
  sed -e "s/{{ID}}/$ID/g" -e "s/{{SLUG}}/$SLUG/g" -e "s/{{CLASS}}/$CLASS/g" \
      "$TPL/$f.md" > "$DIR/$f.md"
done
echo "$DIR"
