#!/usr/bin/env bash
# Exercises install.sh and installer.py end to end in throwaway directories.
# Run by the install-unix job in .github/workflows/validate.yml.
#
# The scenarios here were all verified by hand first, and two real bugs still
# shipped because "verified by hand" does not run again on the next change.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/godot4-install-XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
FAILED=0

SECTION=0

# ok() must not print after a failure in the same section: a section that
# reports both an error and "ok" is the dishonest reporting this project exists
# to avoid.
fail() { echo "::error::$1"; FAILED=1; SECTION=1; }
ok()   { [ "$SECTION" -eq 0 ] && echo "ok  $1"; SECTION=0; }

# A package laid out the way the release tarball is.
make_pkg() {
  local dir="$1" version="$2"
  mkdir -p "$dir"
  cp -R "$REPO/.claude" "$dir/.claude"
  cp "$REPO/install.sh" "$REPO/installer.py" "$dir/"
  printf '%s\n' "$version" > "$dir/VERSION"
  find "$dir" \( -name '__pycache__' -o -name '*.pyc' \) -exec rm -rf {} + 2>/dev/null
}

make_project() { mkdir -p "$1"; : > "$1/project.godot"; }

manifest_has() {  # manifest_has <project> <relative path>
  python3 -c "
import json, sys
m = json.load(open(sys.argv[1] + '/.claude/.godot-4-manifest.json'))
sys.exit(0 if sys.argv[2] in m['files'] else 1)" "$1" "$2"
}

manifest_version() {
  python3 -c "
import json, sys
print(json.load(open(sys.argv[1] + '/.claude/.godot-4-manifest.json'))['version'])" "$1"
}

hook_groups() {
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1] + '/.claude/settings.json'))
print(sum(len(v) for v in d.get('hooks', {}).values()))" "$1"
}

PKG="$ROOT/pkg"; make_pkg "$PKG" 1.0.0

# 1. Fresh install records a manifest -----------------------------------------
P="$ROOT/fresh"; make_project "$P"
"$PKG/install.sh" "$P" >/dev/null 2>&1 || fail 'fresh install exited non-zero'
[ -f "$P/.claude/.godot-4-manifest.json" ] || fail 'fresh install wrote no manifest'
[ "$(manifest_version "$P")" = "1.0.0" ] || fail 'manifest records the wrong version'
[ "$(hook_groups "$P")" -gt 0 ] || fail 'fresh install merged no hook groups'
ok 'fresh install records a manifest'

# 2. Reinstall changes nothing ------------------------------------------------
BEFORE="$(hook_groups "$P")"
"$PKG/install.sh" "$P" >/dev/null 2>&1
[ "$(hook_groups "$P")" = "$BEFORE" ] || fail 'reinstall changed the hook group count'
ok 'reinstall is a no-op'

# 3. A path with a space ------------------------------------------------------
# "~/My Games/proj" is an ordinary macOS path, and packing the arguments into a
# string instead of an array broke the install outright.
SPACED="$ROOT/My Games"; make_pkg "$SPACED/pkg" 1.0.0; make_project "$SPACED/proj"
if ! "$SPACED/pkg/install.sh" "$SPACED/proj" >/dev/null 2>&1; then
  fail 'install failed with a space in the path'
elif [ ! -f "$SPACED/proj/.claude/settings.json" ]; then
  fail 'install with a space in the path wrote nothing'
else
  ok 'a path with a space survives'
fi

# 4. Update: stale removal, hook replacement, local edits ---------------------
U="$ROOT/upd"; make_project "$U"
"$PKG/install.sh" "$U" >/dev/null 2>&1
echo '## local note' >> "$U/.claude/skills/godot-testing/SKILL.md"
mkdir -p "$U/.claude/skills/mine"
printf -- '---\nname: mine\ndescription: Mine. Use when mine.\n---\n' > "$U/.claude/skills/mine/SKILL.md"

NEXT="$ROOT/pkg2"; make_pkg "$NEXT" 1.1.0
rm -rf "$NEXT/.claude/skills/godot-release"
mv "$NEXT/.claude/scripts/lint_gd.sh" "$NEXT/.claude/scripts/lint_gdscript.sh"
python3 -c "
import json, sys
p = sys.argv[1] + '/.claude/settings.json'
d = json.load(open(p))
for group in d['hooks']['PostToolUse']:
    for hook in group['hooks']:
        hook['command'] = hook['command'].replace('lint_gd.sh', 'lint_gdscript.sh')
json.dump(d, open(p, 'w'), indent=2)" "$NEXT"

"$NEXT/install.sh" "$U" >/dev/null 2>&1
[ -d "$U/.claude/skills/godot-release" ] && fail 'a skill dropped from the package survived'
grep -q 'local note' "$U/.claude/skills/godot-testing/SKILL.md" || fail 'a local edit was overwritten'
[ -f "$U/.claude/skills/godot-testing/SKILL.md.new" ] || fail 'no .new was left beside the kept edit'
[ -f "$U/.claude/skills/mine/SKILL.md" ] || fail "the user's own skill was deleted"
# A quoted heredoc, so the shell leaves $CLAUDE_PROJECT_DIR for Python to
# substitute rather than expanding it itself.
ORPHANS="$(python3 - "$U" <<'ORPHAN_PY'
import json, os, sys

root = sys.argv[1]
settings = json.load(open(os.path.join(root, ".claude", "settings.json")))
missing = 0
for groups in settings.get("hooks", {}).values():
    for group in groups:
        for hook in group.get("hooks", []):
            path = hook.get("command", "")
            path = path.replace('"$CLAUDE_PROJECT_DIR"', root)
            path = path.replace("$CLAUDE_PROJECT_DIR", root).strip('"')
            if path and not os.path.exists(path):
                missing += 1
print(missing)
ORPHAN_PY
)"
[ "$ORPHANS" = "0" ] || fail "$ORPHANS hook group(s) point at a script that no longer exists"
[ "$(manifest_version "$U")" = "1.1.0" ] || fail 'the manifest was not bumped'
ok 'update removes stale files, replaces hooks, keeps local work'

# 5. --force records the file, so a later release can still clean it up -------
F="$ROOT/forced"; make_project "$F"
"$PKG/install.sh" "$F" >/dev/null 2>&1
echo '## local note' >> "$F/.claude/skills/godot-testing/SKILL.md"
"$PKG/install.sh" "$F" --force >/dev/null 2>&1
manifest_has "$F" 'skills/godot-testing/SKILL.md' \
  || fail '--force left the overwritten file out of the manifest'
THIRD="$ROOT/pkg3"; make_pkg "$THIRD" 1.2.0
rm -rf "$THIRD/.claude/skills/godot-testing"
"$THIRD/install.sh" "$F" >/dev/null 2>&1
[ -f "$F/.claude/skills/godot-testing/SKILL.md" ] \
  && fail '--force produced a permanent orphan: a later release could not remove it'
ok '--force keeps the file managed'

# 6. Destination forms --------------------------------------------------------
E="$ROOT/empty"; mkdir -p "$E"
( cd "$E" && "$PKG/install.sh" --here >/dev/null 2>&1 )
[ -f "$E/.claude/settings.json" ] || fail '--here did not install into an empty directory'
N="$ROOT/walkup"; make_project "$N"; mkdir -p "$N/scenes/player"
( cd "$N/scenes/player" && "$PKG/install.sh" >/dev/null 2>&1 )
[ -f "$N/.claude/settings.json" ] || fail 'no argument did not walk up to the project root'
[ -d "$N/scenes/player/.claude" ] && fail 'no argument installed in the current directory'
( cd "$PKG" && ./install.sh >/dev/null 2>&1 ) && fail 'installing into the package was allowed'
ok 'destination forms behave'

# 7. An invalid settings.json aborts before copying ---------------------------
B="$ROOT/broken"; make_project "$B"; mkdir -p "$B/.claude"
echo '{ not json' > "$B/.claude/settings.json"
"$PKG/install.sh" "$B" >/dev/null 2>&1 && fail 'an invalid settings.json did not abort'
[ -d "$B/.claude/skills" ] && fail 'files were copied before the settings check failed'
ok 'an invalid settings.json aborts before copying'

[ "$FAILED" -eq 0 ] && echo 'install.sh: all checks passed'
exit "$FAILED"
