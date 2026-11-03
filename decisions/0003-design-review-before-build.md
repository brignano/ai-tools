# 0003: Design review with Anthony before any size M build

Status: accepted
Date: 2026-11-03
From: #80

## Context
Agents wrote proposals and then built them in the same run, without walking
Anthony through the design. Tokens went into designs he hadn't agreed to, and
work got rebuilt. The options were to keep building and review in the PR, to
review only risky work, or to gate every size M build on an approved design.

## Decision
Size M work, and anything the issue's Decisions can't settle, starts with a
proposal PR that has no code. The agent explains it to Anthony in plain words
and stops with `needs:anthony`. Nothing is built until he accepts it. Every
builder comments its plan before writing code.

## Consequences
- Slower start on medium work, but builds match what was agreed the first time.
- Proposal and ADR PRs always need Anthony.
- Enforcement is by the role prompts and the reviewer, not the board sync.
