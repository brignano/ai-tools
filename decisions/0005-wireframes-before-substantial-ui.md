# 0005: Wireframes before substantial UI work

Status: accepted
Date: 2026-11-12
From: #100

## Context
UI changes were reviewed only after they were built, through the UX gate's
before/after screenshots and preview links. A wrong layout or flow found there
had already cost a full build. The rule existed only in one project's settings
and two repos, so other sessions didn't follow it.

## Decision
Substantial UI work (a new page, route, screen, template, email or component;
a new flow or interaction; a layout or structure change) gets wireframes at
390px and 1280px, shared with Anthony, before any implementation code, at
every issue size. The agent adds `needs:anthony` and stops until his explicit
OK in the thread or on the PR. Copy edits, design-restoring fixes, small token
nudges, a11y fixes that move nothing and dependency bumps are exempt. When in
doubt, wireframe. Wireframes use real tokens, components and copy (demo data
only) and are shared as a phone-tappable link with screenshots and the rejected
options. The fleet README section "Wireframes before build" is the only place
the rule is defined; each repo documents only where it keeps wireframes
(`previews/wireframes/README.md` in brignano/design,
`proposals/wireframes/README.md` in product repos). No default PR template
checkbox: the builder and reviewer roles enforce it.

## Consequences
- One extra stop with Anthony on substantial UI work, even size S.
- After screenshots are checked against the approved wireframe.
- Enforced by the builder and reviewer roles and the `ux-review` skill, not CI.
