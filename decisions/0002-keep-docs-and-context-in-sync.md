# 0002: Every PR keeps docs, product site and agent context in sync

Status: accepted
Date: 2026-11-03
From: #75

## Context
Changes shipped without updating READMEs, docs, product-site copy or agent
context (AGENTS.md, skills). Later sessions worked from stale context and had
to rediscover what had changed. The options were a follow-up issue for docs,
a periodic audit, or a same-PR rule.

## Decision
Every PR updates whatever its change makes untrue, in the same PR. Updates in
other repos are filed as issues from the same session. The builder lists the
updates in the PR body, and the reviewer checks them.

## Consequences
- PRs get a little bigger, and the next session starts from accurate context.
- PRs that touch agent rules (AGENTS.md, CLAUDE.md, `.claude/`) still need
  Anthony to merge, per "Who merges".
