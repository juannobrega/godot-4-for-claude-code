---
description: Resolve the open markers in a system spec, one question at a time
argument-hint: [system-slug]
---

Work through the open `[NEEDS CLARIFICATION: ...]` and `[DESIGN DECISION: ...]`
markers in the spec for **$1** (or the most recently touched system).

## How

One question at a time. Batching five questions produces five shallow answers.

For each marker:

1. State what is unclear and why it blocks the plan — what would go wrong if
   you guessed.
2. Offer concrete options when they exist, with the consequence of each. "Dash
   cancels the attack" vs "dash is blocked during attack" is a real choice with
   a feel consequence; present it that way, not as an open question.
3. Write the answer into the spec, removing the marker.
4. If it was a `[DESIGN DECISION]`, also append it to `.godotspec/decisions.md`
   with an ID (`D-SYS004-02`) and the rationale. A decision without a rationale
   gets relitigated in three weeks.

## Do not

Resolve a `[DESIGN DECISION]` yourself, even when one option is obviously
better engineering. That marker exists because the choice is the human's.

## Finish by

Confirming no markers remain, then pointing at `/godot-4:plan`.
