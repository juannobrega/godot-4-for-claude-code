---
description: Run the verification ladder and file the evidence
argument-hint: "[V0|V1|V2|V3|V4] [system-slug]"
---

Run `.claude/scripts/verify.sh ${1:-V3} --system $2`.

Do not reimplement the ladder in your own Bash. The script exists because the
checks that matter are the ones easy to forget: Godot exits 0 after a
`SCRIPT ERROR`, a test runner that found no tests also exits 0, gdUnit4 refuses
headless without a flag, and `.uid` sidecars go missing on every file an agent
creates. Each of those turns a green gate into a lie.

## Report

One line per rung, as the script prints it. Then:

- **All green up to the target:** say which rungs ran and which did not, and
  name the V5 criteria still waiting in `.godotspec/checks.md`. Never describe
  a system as done while V5 items are open.
- **A rung failed:** read the evidence file it names, diagnose, fix, re-run.
  Do not move to a higher rung with a lower one red.
- **A rung reported "not applicable":** say so explicitly. "No integration
  tests exist" and "integration tests passed" are different results and must
  not read the same.

## If a rung cannot run here

Say why in one line (no display for UI input, no bot scenario written yet) and
record it in the evidence. An honest gap beats a skipped check nobody notices.
