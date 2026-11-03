# 0001: ADRs in decisions/, driftwood models for architecture, no GitHub Pages

Status: accepted
Date: 2026-11-03
From: [proposal](../proposals/docs-decisions-architecture.md), #73

## Context
Fleet repos had `proposals/` for specs but no decision log, no rule for
architecture diagrams, and no rule for where user docs live or are published.
Options weighed: GitHub Pages, a docs site per repo, or none for private repos;
ADRs in `docs/adr/`, a single `DECISIONS.md`, or `decisions/`; hand-written
diagrams, other diagrams-as-code tools, or driftwood.

## Decision
Every fleet repo keeps ADRs in `decisions/NNNN-slug.md` with an index. Repos
that deploy more than one moving part keep a driftwood `architecture.yaml`,
validated and rendered to `docs/architecture.md` in CI. `docs/` is user docs
only. Private repos have no doc site; public products serve docs at `/docs` on
their own site. No GitHub Pages.

## Consequences
- Decisions become findable by any agent or person reading the repo.
- Each repo needs a small adoption PR, and `design` converts its `DECISIONS.md`.
- Self-hosted estates (homelab) get hand-written models until driftwood gains
  a Compose/Proxmox provider (driftwood#115).
- Building a `/docs` site is per-product work, done only when a product needs one.
