# 0003: Codex as an optional, sandboxed builder for a one-month trial

Status: accepted
Date: 2026-11-03
From: #77

## Context
Fleet builds all draw on the Claude weekly limit, which runs out mid-week.
Codex CLI comes with ChatGPT Plus and is a second usage pool at the same
per-token price as Sonnet, so the gain is capacity, not price. The options
were an MCP wrapper around Codex, `codex exec` from a subagent, or Codex cloud
tasks and its GitHub app.

## Decision
Add a `codex-builder` subagent that shells out to `codex exec` in its own
worktree with the sandbox on. Claude stays the builder of record: it reviews
the diff and runs every gate, and Codex never pushes, opens PRs or merges.
The session picks Sonnet or Codex by hand. MCP wrappers (they bypass sandbox
and approvals), Codex cloud and automatic routing are out. Each PR records a
`## Builder` line so the month's results decide whether it stays.

## Consequences
- Builds can continue on Codex when the Claude limit is low, on devices where
  Codex is logged in (not claude.ai cloud threads).
- A Claude limit that is fully hit still stops planning, review and the fleet;
  the README documents running `codex` directly as a manual fallback.
- Revisit after the trial: keep, drop, or add routing.
