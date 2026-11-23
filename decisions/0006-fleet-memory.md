# 0006: Fleet memory, with facts that merge themselves

Status: accepted
Date: 2026-11-22
From: #108, proposal [fleet-memory](../proposals/fleet-memory.md)

## Context
What a session learned from Anthony died with it, so the same correction had
to be given again in every project unless someone edited AGENTS.md or a skill
by hand.

## Decision
A `memory/` folder holds one short fact per file, loaded at every session
start as data that never overrides AGENTS.md, the fleet standard or a repo's
rules. Sessions propose facts as `Memory:` issues in ai-tools, in the moment
Anthony states them, and once per long session or after a compaction when a
Stop hook asks. A plain script (no model) turns each issue into a PR. A CI
gate, not a model, auto-merges a PR only if it adds one new file under
`memory/`, up to 500 characters, with no links, code or instruction words,
from a `brignano` issue that quotes him. Edits, deletions, rules and every
other path wait for Anthony. Closing as not planned labels the issue
`memory:rejected` so it isn't proposed again. Total loaded memory is capped at
12 KB. Running cost is $0 a month.

## Consequences
- About 3k more tokens at each session start, and one extra step in long
  sessions.
- A new fine-grained token (ai-tools only) so the PRs the script opens run CI.
  Amended at build (#108): no token; the script gates its own PR. See the
  proposal's "As built".
- CI can't prove a quote is Anthony's, because cloud sessions post as him too;
  protection rests on additions-only, the content rules, the size cap and
  one-click revert. Anthony accepted that trade-off.
- Anthony adds the `memory:` carve-out to `fleet/merge.yml` and makes
  `memory-gate` a required check himself. Amended at build (#108): the
  carve-out is the line `memory: auto`, and no required check (see "As built").
