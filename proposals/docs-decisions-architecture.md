# Docs, decisions and architecture

Status: accepted
Issue: brignano/ai-tools#73

## Problem
The fleet had a home for specs (`proposals/`) but none for decisions, diagrams
or user docs. Decisions made in threads lived only in chat history or assistant
memory. Architecture diagrams were hand-drawn when they existed at all, and
went stale. There was no answer to "product site or docs site, and where".

## Options considered
- **Docs hosting.** GitHub Pages (asked about); a docs site per repo on
  Cloudflare Workers; no site for private repos, `/docs` on the product's own
  site for public ones. Pages on a private repo needs a paid plan, publishes
  publicly, and sits outside the Cloudflare/Access pattern. A site per repo is
  more to build and run than private, internal docs justify, since GitHub
  already renders Markdown and Mermaid privately for free.
- **Decision log.** ADRs under `docs/adr/`; one `DECISIONS.md` per repo (what
  `design` does); `decisions/NNNN-slug.md`. `docs/` gets published, so ADRs
  stay out of it like proposals do. One file per decision diffs and links
  cleanly and makes supersession explicit.
- **Diagrams.** Hand-written Mermaid; Structurizr/D2; driftwood. Hand-written
  diagrams rot whatever the syntax. driftwood keeps a validated model in git,
  renders Mermaid GitHub draws in place, and can check the model against
  Terraform/CloudFormation today and other sources once providers exist.

## Proposal
Adopted as the "Decisions (ADRs)", "Architecture" and "Where docs live"
sections of `fleet/README.md`, with the reviewer checks, `/new-repo` and
`/new-tsd` updated to match. Each fleet repo adopts it through its own issue.

## Proposed issues
Filed 2026-11-03: driftwood#115 (Docker Compose and Proxmox provider),
adoption issues driftwood#116, homelab#344, guidebook#107, sites#69,
brignano.io#324, design#44, breakeven#17, card#26.
