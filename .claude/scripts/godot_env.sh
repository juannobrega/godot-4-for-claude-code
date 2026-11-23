#!/usr/bin/env bash
# Locates the Godot project and binary. Source this; do not execute it directly.
#
# Exports, when a Godot project is present:
#   GODOT_PROJECT   directory holding project.godot
#   GODOT_BIN       Godot executable
#   GODOT_VERSION   version reported by the binary (e.g. 4.7.2.stable)
#   GODOTSPEC       <GODOT_PROJECT>/.godotspec
#
# Returns 1 when there is no Godot project, so callers can no-op instead of
# failing. Every hook in this kit relies on that: the kit must be inert in a
# repository that is not a Godot game.

godot_find_project() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/project.godot" ] && { printf '%s\n' "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

godot_find_bin() {
  local cfg="$1/.godotspec/config.yml"
  # 1. explicit configuration wins, so a project can pin an exact build
  if [ -f "$cfg" ]; then
    local from_cfg
    from_cfg="$(sed -n 's/^godot_bin:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "$cfg" | head -1)"
    [ -n "$from_cfg" ] && [ -x "$from_cfg" ] && { printf '%s\n' "$from_cfg"; return 0; }
  fi
  # 2. environment override, for CI. Guarded for `set -u` callers.
  [ -n "${GODOT_BIN:-}" ] && [ -x "${GODOT_BIN:-}" ] && { printf '%s\n' "$GODOT_BIN"; return 0; }
  # 3. PATH, under the names the official builds and distro packages use
  local name
  for name in godot godot4 godot-4 Godot; do
    command -v "$name" >/dev/null 2>&1 && { command -v "$name"; return 0; }
  done
  # 4. macOS app bundle, which is not on PATH after a drag-to-Applications install
  for name in "/Applications/Godot.app/Contents/MacOS/Godot" \
              "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    [ -x "$name" ] && { printf '%s\n' "$name"; return 0; }
  done
  return 1
}

godot_env_load() {
  GODOT_PROJECT="$(godot_find_project)" || return 1
  GODOTSPEC="$GODOT_PROJECT/.godotspec"
  GODOT_BIN="$(godot_find_bin "$GODOT_PROJECT")" || return 2
  # --version prints the version and exits; no display or project needed
  GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null | tail -1 | tr -d '\r')"
  export GODOT_PROJECT GODOTSPEC GODOT_BIN GODOT_VERSION
  return 0
}

# Reads a scalar key from .godotspec/config.yml. Config that nothing reads is
# worse than no config: it looks like a setting and silently is not one.
godot_cfg() {
  local key="$1" fallback="${2:-}" cfg="$GODOTSPEC/config.yml" value=""
  [ -f "$cfg" ] && value="$(sed -n "s|^$key:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$|\1|p" "$cfg" | head -1)"
  printf '%s\n' "${value:-$fallback}"
}

# Reads a nested key one level deep, such as test_dirs.unit.
godot_cfg_nested() {
  local parent="$1" key="$2" fallback="${3:-}" cfg="$GODOTSPEC/config.yml" value=""
  [ -f "$cfg" ] && value="$(awk -v p="$parent:" -v k="  $key:" '
    $0 ~ "^"p {inside=1; next}
    inside && /^[^[:space:]]/ {inside=0}
    inside && index($0, k)==1 {sub(/^[^:]*:[[:space:]]*/, ""); gsub(/"/, ""); print; exit}
  ' "$cfg")"
  printf '%s\n' "${value:-$fallback}"
}

# Version declared in project.godot, which is what the engine will actually
# open the project as. Differs from GODOT_VERSION when the wrong binary is used.
godot_project_feature_version() {
  sed -n 's/^config\/features=PackedStringArray(\("[^"]*"\).*/\1/p' \
      "$GODOT_PROJECT/project.godot" 2>/dev/null | tr -d '"' | head -1
}
