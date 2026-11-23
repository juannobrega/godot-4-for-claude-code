---
description: Gap analysis between a system's spec and the code that exists, appending convergence tasks
argument-hint: <system-slug>
---

Close the gap between what the spec, plan and tasks for **$1** call for and
what the codebase actually implements.

## Method

1. **Intent inventory.** Map every BEH, AC, TUN, SIG and decision to the code
   that is supposed to satisfy it. Build this before reading for problems, or
   you will only find what you expected to find.

2. **Assess each entry** against the code, classified as:
   - `missing` — specified, nothing implements it
   - `partial` — implemented for the happy path only, or for some states
   - `contradicts` — the code does something the spec rules out
   - `unrequested` — code exists that no spec entry asked for

   `unrequested` matters as much as `missing`. Code nobody specified is code
   nobody agreed to maintain.

3. **Severity**: CRITICAL / HIGH / MEDIUM / LOW. Judge by player-visible impact
   and by whether it breaks an invariant in `contract.md`.

4. **Show the table before writing anything.** The user decides what converges.

5. **Append** a `## Phase N: Convergence` section to `tasks.md` with one task
   per accepted gap.

## Boundaries

Only `tasks.md` is written. Never edit the spec to match the code — that is
backwards, and it is how a spec quietly stops being the contract. If the code
is right and the spec is wrong, say so and let the user change the spec.

## Converged

When every entry is satisfied and nothing is unrequested, report `Converged`
and append nothing — not even an empty phase heading.
