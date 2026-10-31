---
name: ux-review
description: The fleet's UX and accessibility gate for any PR that changes what a user sees (pages, components, styles, copy, emails, CLI output people read). Use before opening such a PR, when reviewing one, and when adding the ui-check workflow to a repo.
---

# UX review

A PR that changes what a user sees is not done until it passes this gate. It
is step 4 of "Review and merge" in `fleet/README.md`. The builder does it
before asking for review; the reviewer checks it against the diff.

## 1. Automated: the `ui-check` job

Each repo with a UI calls the reusable workflow from brignano/ai-tools. It
builds the site, serves it, loads each page in Chromium at mobile (390px) and
desktop (1280px) widths in light and dark, runs axe-core (WCAG 2.2 AA), and
uploads screenshots as an artifact. It **fails on any serious or critical
violation** and on console errors.

```yaml
# .github/workflows/ui-check.yml in the repo
name: ui-check
on:
  pull_request:
jobs:
  ui:
    uses: brignano/ai-tools/.github/workflows/ui-check.yml@main
    with:
      build: npm run build          # default
      serve: npx --yes serve -l 4173 dist   # must listen on the url below
      url: http://localhost:4173    # default
      pages: |
        /
        /about
```

A repo without it gets a `proposed` issue to add it. Until then, run the same
check locally against your dev server:

```sh
node ~/.ai-tools/fleet/ui-check/check.mjs http://localhost:4173 / /about
```

## 2. Screenshots in the PR body

Attach (or link the `ui-check` artifact for) the changed screens at mobile and
desktop, light and dark. Before/after when something existing changed. Nobody
should have to run the branch to see what it does.

## 3. Checklist (the reviewer reads the diff for each)

- **Design system**: every colour, font, radius, shadow and spacing value
  comes from `@brignano/design` tokens (`design-system` skill). No hex, no
  new palette, the right tier.
- **Dark mode**: both themes look intentional; no hardcoded light surfaces.
- **Responsive**: works from 320px to wide desktop; no horizontal scroll, no
  text clipped, tap targets at least 44px on touch.
- **Keyboard**: everything reachable and usable by keyboard in a sensible
  order, with a visible focus ring; dialogs trap and return focus; Escape
  closes.
- **Semantics**: real `button`/`a`/`label`/headings in order; images have
  `alt` (empty when decorative); form fields have labels and their errors are
  announced.
- **States**: loading, empty, error and success are all designed, not
  blank. Errors say what happened and what to do next.
- **Motion**: honours `prefers-reduced-motion`; tool tier has no motion.
- **Copy**: plain words, sentence case, no jargon, consistent with the rest
  of the product.
- **Performance**: no new heavy dependency for a small effect; images sized
  and lazy where below the fold; no layout shift on load.

Report only what fails, with the file, line and fix.
