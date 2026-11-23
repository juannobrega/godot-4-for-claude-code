#!/usr/bin/env bash
# Runs the verification ladder up to the requested rung and writes evidence.
#
#   verify.sh [V0|V1|V2|V3|V4] [--system <slug>]
#
# Exit 0 only when every rung up to the target passed. One line per rung on
# stdout, so the output is parseable and stable:
#   V1 PASS  import clean, 0 missing .uid
#   V2 FAIL  gut: 3 failures (reports/gut-junit.xml)
#
# V5 is human judgement and is never run here. See .godotspec/checks.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=godot_env.sh
. "$SCRIPT_DIR/godot_env.sh"

TARGET="${1:-V3}"; [ "${TARGET#-}" != "$TARGET" ] && TARGET="V3"
SYSTEM=""
while [ $# -gt 0 ]; do
  case "$1" in --system) SYSTEM="${2:-}"; shift 2 ;; *) shift ;; esac
done

godot_env_load
case $? in
  1) echo "verify: no project.godot found; nothing to verify" >&2; exit 0 ;;
  2) echo "verify: Godot binary not found. Set godot_bin in .godotspec/config.yml or export GODOT_BIN." >&2; exit 1 ;;
esac

EVIDENCE="${GODOTSPEC}/systems/${SYSTEM}/evidence"
[ -z "$SYSTEM" ] && EVIDENCE="${GODOTSPEC}/evidence"
mkdir -p "$EVIDENCE"
STAMP="$(date +%Y%m%dT%H%M%S)"
LOG="$EVIDENCE/verify-$STAMP.log"
RUNG_MAX="${TARGET#V}"
FAILED=0

say() { printf '%-3s %-4s %s\n' "$1" "$2" "$3"; }
record() { printf '[%s] %s %s %s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$3" >> "$LOG"; }
rung() {  # rung <n> <label> ; returns 0 when this rung should run
  [ "$1" -le "$RUNG_MAX" ] && [ "$FAILED" -eq 0 ]
}
pass() { say "$1" PASS "$2"; record "$1" PASS "$2"; }
fail() { say "$1" FAIL "$2"; record "$1" FAIL "$2"; FAILED=1; }

# Godot exits 0 after a SCRIPT ERROR, so the exit code alone proves nothing.
# Every rung that runs the engine must also scan its output.
engine_errors() { grep -cE '^(SCRIPT ERROR|ERROR|USER ERROR):' "$1" 2>/dev/null || true; }

# ---------------------------------------------------------------- V0 syntax
if rung 0; then
  OUT="$EVIDENCE/v0-$STAMP.txt"
  : > "$OUT"
  if command -v gdlint >/dev/null 2>&1; then
    # Only lint tracked scripts; addons/ is third-party and not ours to style.
    GD_FILES="$(find "$GODOT_PROJECT" -name '*.gd' -not -path '*/addons/*' -not -path '*/.godot/*')"
    if [ -n "$GD_FILES" ]; then
      printf '%s\n' "$GD_FILES" | tr '\n' '\0' | xargs -0 gdlint >> "$OUT" 2>&1
      GDLINT_RC=$?
    else
      echo "no .gd files outside addons/" >> "$OUT"; GDLINT_RC=0
    fi
  else
    echo "gdlint not installed (pip install gdtoolkit)" >> "$OUT"; GDLINT_RC=0
  fi
  if [ "$GDLINT_RC" -eq 0 ]; then pass V0 "gdlint clean"; else fail V0 "gdlint findings ($OUT)"; fi
fi

# ------------------------------------------------- V1 import, load, uid sync
if rung 1; then
  OUT="$EVIDENCE/v1-$STAMP.txt"
  "$GODOT_BIN" --headless --path "$GODOT_PROJECT" --import > "$OUT" 2>&1
  IMPORT_RC=$?
  ERRS="$(engine_errors "$OUT")"
  MISSING="$("$SCRIPT_DIR/check_uid.sh" --count 2>/dev/null || echo 0)"
  if [ "$IMPORT_RC" -ne 0 ]; then
    fail V1 "import exited $IMPORT_RC ($OUT)"
  elif [ "${ERRS:-0}" -gt 0 ]; then
    fail V1 "import reported $ERRS engine error(s) despite exit 0 ($OUT)"
  elif [ "${MISSING:-0}" -gt 0 ]; then
    fail V1 "$MISSING file(s) without a .uid sidecar; run check_uid.sh to list"
  else
    pass V1 "import clean, uid sidecars in sync"
  fi
fi

# ------------------------------------------------------ V2/V3 test framework
run_tests() {   # run_tests <rung> <dir>
  local rg="$1" dir="$2" low
  low="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  local out="$EVIDENCE/$low-$STAMP.txt"
  local xml="$GODOT_PROJECT/reports/$low-junit.xml"
  [ -d "$GODOT_PROJECT/$dir" ] || { pass "$rg" "no $dir/, nothing to run"; return; }
  mkdir -p "$GODOT_PROJECT/reports"
  rm -f "$xml"

  if [ -d "$GODOT_PROJECT/addons/gut" ]; then
    "$GODOT_BIN" --headless --path "$GODOT_PROJECT" -s addons/gut/gut_cmdln.gd \
      "-gdir=res://$dir" -gexit "-gjunit_xml_file=res://reports/$low-junit.xml" > "$out" 2>&1
    local rc=$?
  elif [ -d "$GODOT_PROJECT/addons/gdUnit4" ]; then
    # gdUnit4 refuses headless without this flag and exits 103 before running.
    "$GODOT_BIN" --headless --path "$GODOT_PROJECT" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
      -a "res://$dir" --ignoreHeadlessMode > "$out" 2>&1
    local rc=$?
    case $rc in
      100) fail "$rg" "gdunit4: test failures ($out)"; return ;;
      101) fail "$rg" "gdunit4: passed but leaked a node ($out)"; return ;;
      103) fail "$rg" "gdunit4: refused headless mode ($out)"; return ;;
    esac
    xml="$(ls -t "$GODOT_PROJECT"/reports/report_*/results.xml 2>/dev/null | head -1)"
  else
    pass "$rg" "no test framework installed (addons/gut or addons/gdUnit4)"; return
  fi

  if [ "$rc" -ne 0 ]; then fail "$rg" "test runner exited $rc ($out)"; return; fi
  # A runner that found no tests exits 0. Without this check the gate is a lie.
  if [ ! -s "$xml" ]; then
    fail "$rg" "runner exited 0 but wrote no JUnit XML — no tests ran"; return
  fi
  local n; n="$(grep -o 'tests="[0-9]*"' "$xml" | grep -o '[0-9]*' | awk '{s+=$1} END{print s+0}')"
  if [ "${n:-0}" -eq 0 ]; then
    fail "$rg" "runner exited 0 with 0 tests executed — check -gdir/-a path"; return
  fi
  pass "$rg" "$n test(s) passed ($xml)"
}

rung 2 && run_tests V2 "tests/unit"
rung 3 && run_tests V3 "tests/integration"

# ------------------------------------------------------------ V4 bot run
if rung 4; then
  OUT="$EVIDENCE/v4-$STAMP.txt"
  if [ ! -f "$GODOT_PROJECT/tools/bot.gd" ]; then
    pass V4 "no tools/bot.gd, rung not applicable"
  else
    # --fixed-fps makes physics and timers reproducible; --quit-after stops a
    # hung run from blocking CI. Args after -- reach OS.get_cmdline_user_args().
    "$GODOT_BIN" --headless --path "$GODOT_PROJECT" --fixed-fps 60 --quit-after 1800 \
      -- --bot --seed 42 > "$OUT" 2>&1
    RC=$?
    ERRS="$(engine_errors "$OUT")"
    if [ "$RC" -ne 0 ]; then fail V4 "bot exited $RC ($OUT)"
    elif [ "${ERRS:-0}" -gt 0 ]; then fail V4 "bot hit $ERRS engine error(s) despite exit 0 ($OUT)"
    else pass V4 "bot run clean (seed 42)"; fi
  fi
fi

# Tell the Stop hook that verification happened, pass or fail: the hook asks
# "was anything run since the change?", not "did it pass?". A failing rung is
# a reported result, not an unverified change.
mkdir -p "$GODOTSPEC/.session"
: > "$GODOTSPEC/.session/last-verify"
[ "$FAILED" -eq 0 ] && rm -f "$GODOTSPEC/.session/lint-fails"

echo "---"
echo "evidence: $LOG"
if [ "$FAILED" -eq 0 ]; then
  echo "V5 is human judgement and was not run. Pending items: ${GODOTSPEC}/checks.md"
fi
exit "$FAILED"
