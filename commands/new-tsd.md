---
description: Draft a new TSD (Technical Spec Document) from any idea, rough or detailed
argument-hint: [one-sentence idea or rough notes]
---

Draft a Technical Spec Document (TSD) for the following idea. A single sentence is
enough to start — fill the gaps with reasonable assumptions and flag them.

**Idea:** $ARGUMENTS

## How to work
- If the idea is ambiguous in a way that changes the design, ask **at most 2–3**
  clarifying questions first. Otherwise proceed and state your assumptions.
- Always factor in self-hosting cost, complexity, and ongoing maintenance burden.
- Prefer self-hosted over SaaS when complexity is comparable; prefer simple and
  maintainable over clever; prefer proven tools unless there's a clear reason.
- If the idea is a bad one, say so directly with the reason instead of speccing it.
- Use a Mermaid diagram for any non-trivial flow or architecture.

## Output — produce the TSD in this structure

# TSD: <short title>

## Problem
What's the actual need? Who/what is it for? Why now?

## Goals / Non-goals
Bullet what success looks like, and explicitly what's out of scope.

## Proposed approach
The recommended design. Include a Mermaid diagram if there's a flow or architecture.
If you considered alternatives, name them and say why you rejected them in one line each.

## Implementation plan
Ordered, reviewable steps or phases. Note which are reversible vs. one-way doors.

## Cost & maintenance
Monthly run cost (compute, storage, licensing), and the ongoing maintenance burden.
For a homelab service, include RAM/storage footprint on the GMKtec M5 Ultra.

## Risks & open questions
Known risks, and anything still unresolved that needs a decision.

---

End by asking whether to approve the TSD or iterate. Do not start implementing until
it's approved.
