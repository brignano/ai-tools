---
name: ux-review
description: The fleet's UX and accessibility gate for any change to what a user sees (pages, components, styles, copy, emails, CLI output people read), including its before/after screenshots. Use when starting such a change (to capture "before"), before opening its PR, when reviewing one, and when adding the ui-check workflow to a repo.
---

# UX review

A PR that changes what a user sees is not done until it passes this gate. It
is step 4 of "Review and merge" in `fleet/README.md`. The builder does it
before asking for review; the reviewer checks it against the diff.

## 0. Wireframe first

Substantial UI work (a new page, route, screen, template, email or component;
a new flow or interaction; a layout or structure change) gets a wireframe
Anthony explicitly OKs before any implementation code, at every size. The
rule, the exempt list and the steps are in the fleet README, "Wireframes
before build"; when in doubt, wireframe.

- Phone (390px) and desktop (1280px). Static by default; an interactive
  prototype when flow, state or motion is the point. Real tokens, components
  and copy; demo data only.
- Keep it where the repo's wireframes README says
  (`previews/wireframes/README.md` in brignano/design,
  `proposals/wireframes/README.md` in product repos).
- Share a link he can tap on his phone, phone and desktop screenshots, and
  the rejected options, one line each. Add `needs:anthony` and stop.
- After his OK, link the approved wireframe in the plan comment and the PR
  body; the after screenshots in §2 are checked against it.

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

A repo without it gets an issue to add it. Until then, run the same
check locally against your dev server:

```sh
node ~/.ai-tools/fleet/ui-check/check.mjs http://localhost:4173 / /about
```

## 2. Before/after screenshots

Every change to what a user sees ships with before/after screenshots, so you
can check your own work and Anthony can review it from his phone without
running the branch.

1. **Capture "before" first**, before editing anything: serve the default
   branch (or note the deployed URL) so you can shoot it again at the end.
2. **Capture "after"** when the change is done, with the branch served:

   ```sh
   node <compare.mjs> <before-url> <after-url> /path /other-path
   ```

   `compare.mjs` lives in `fleet/ui-check/`: `~/.ai-tools/fleet/ui-check/`
   on a machine with ai-tools installed, or `../../fleet/ui-check/` from this
   skill's folder in the fleet plugin. It needs only Playwright (preinstalled
   in cloud sessions). It writes one labelled before | after PNG per view to
   `/tmp/ui-compare` (`UI_COMPARE_OUT` changes it; never point it inside the
   repo), phone views first (`1-phone-*`): phone (390px) and desktop
   (1280px), light and dark (`UI_COMPARE_SCHEMES=light` for a UI with no dark
   mode). Base URLs may include a sub-path (`https://host/app/`). Use `-` as the before URL for a brand-new screen. Shoot only
   the screens the change touches. To serve both versions at once, run the
   default branch from a second `git worktree` on another port. The `run`
   skill helps start an app you don't know how to serve.
3. **Look at them yourself.** Open every PNG and compare before with after.
   Check the change did what was asked and nothing else moved, broke or
   clipped. If the change needed a wireframe (§0), check "after" against the
   approved wireframe too, and call out any difference in the reply and PR. Fix and re-shoot before calling it done.
4. **Demo data only.** Serve fixtures or seed data, never real budget numbers,
   people, photos or anything else personal.
5. **Post them in the thread** with the reply that reports the change, phone
   views first. In a Claude project, copy them under the project files folder
   (e.g. `screenshots/<repo>-pr-<N>/`) and attach them to the reply.
6. **Put them in the PR body.** The GitHub API can't upload images, so commit
   them to the repo's `screenshots` orphan branch (never `main`) and link them:

   ```sh
   git worktree remove --force /tmp/shots 2>/dev/null
   if git ls-remote --exit-code --heads origin screenshots >/dev/null; then
     git fetch origin screenshots && git worktree add -B screenshots /tmp/shots origin/screenshots
   else
     git worktree add --orphan -B screenshots /tmp/shots   # first time in this repo
   fi
   mkdir -p /tmp/shots/pr-<N> && cp /tmp/ui-compare/*.png /tmp/shots/pr-<N>/
   git -C /tmp/shots add . && git -C /tmp/shots commit -m "Screenshots for #<N>" \
     && git -C /tmp/shots push -u origin screenshots
   git worktree remove /tmp/shots
   ```

   ```markdown
   ## Screenshots
   ![phone, light](https://github.com/<owner>/<repo>/blob/screenshots/pr-<N>/1-phone-home-light.png?raw=true)
   ```

   Phone views first. Blob links with `?raw=true` render for anyone who can
   see a private repo. Use them alongside the `## Preview` link, not instead.
7. **Can't run it?** If the UI only exists on a server you can't reach (CT 100)
   or needs a signed-in account, say so in the PR (`Screenshots: after
   deploy, <why>`) and the reply, then shoot the deployed page once it's live.
   Never skip silently.

## 3. Checklist (the reviewer reads the diff for each)

- **Wireframe**: substantial UI work links a wireframe Anthony explicitly
  approved, and the after screenshots match it (or the PR explains why not).

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
