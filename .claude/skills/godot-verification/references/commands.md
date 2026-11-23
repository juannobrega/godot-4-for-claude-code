# Verification commands

## Contents
- Core engine commands
- Test runners and their exit codes
- Lint and format
- Bot runs
- Xvfb for anything that needs a display
- CI assertions that prevent false green

## Core engine commands

```bash
# Import assets and generate missing .uid sidecars. Required before tests:
# without it, scripts with class_name do not exist yet.
godot --headless --path . --import

# Parse one script without executing it
godot --headless --path . --check-only -s res://scripts/player.gd

# Engine version of the binary
godot --version

# Version the project declares itself as
grep '^config/features' project.godot

# Export
godot --headless --path . --export-release "Linux/X11" build/game
```

## Test runners and their exit codes

```bash
# GUT — plain GDScript, runs headless without special flags
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests/unit -gexit \
      -gjunit_xml_file=res://reports/v2-junit.xml
```
`0` passed, or found nothing · `1` failures

```bash
# gdUnit4 — richer scene runner, refuses headless without the flag
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
      -a res://tests/unit --ignoreHeadlessMode
```
`0` passed · `100` failures · `101` passed but leaked a node ·
`103` headless refused. Report at `reports/report_N/results.xml`, N increments.

## Lint and format

```bash
pip install gdtoolkit          # provides gdlint and gdformat
gdlint scripts/                # static analysis, config in .gdlintrc
gdformat --check scripts/      # check only
```

`gdformat` has produced code the engine rejects. Never write a format back
without a parse check after it.

## Bot runs

```bash
godot --headless --path . --fixed-fps 60 --quit-after 1800 -- --bot --seed 42
```
`--fixed-fps` makes physics and timers reproducible. `--quit-after` is a frame
count, and stops a hung run from blocking CI. Arguments after `--` arrive
through `OS.get_cmdline_user_args()`.

The bot must call `get_tree().quit(1)` itself on failure.

## Xvfb for anything that needs a display

`Control` input and `--write-movie` do not work headless.

```bash
xvfb-run -a godot --path . --fixed-fps 60 --quit-after 1800 \
         --write-movie run.avi -- --bot
```

## CI assertions that prevent false green

```bash
# the report exists at all
test -s reports/v2-junit.xml || { echo "no report: no tests ran"; exit 1; }

# and contains more than zero tests
n=$(grep -o 'tests="[0-9]*"' reports/v2-junit.xml | grep -o '[0-9]*' \
    | awk '{s+=$1} END{print s+0}')
[ "$n" -gt 0 ] || { echo "0 tests executed"; exit 1; }

# the engine did not print an error while exiting 0
grep -qE '^(SCRIPT ERROR|ERROR):' run.log && { echo "engine errors"; exit 1; }

# every script has its uid sidecar
.claude/scripts/check_uid.sh
```
