---
name: design-system
description: How to style anything with brignano/design — wiring it into a new project (npm or jsDelivr, fonts, browserslist, Tailwind bridge), what each colour token means, surface vs ink steps, the two tiers, dark mode, chart colours, and diagram/diff colours. Use when starting any new project, site or app, and before writing any UI, CSS, Tailwind classes, colour, theme, chart or diagram colours or component styling, in any repo.
---

# Styling — always use the design system

**Before writing any UI, styling, or colour, read
[`brignano/design`](https://github.com/brignano/design) — `DESIGN.md` for the
rules, `tokens.css` for the values.** It is public, versioned, and the single
source of truth for `brignano.io`, `life`, `julia`, `hoststats`, `homelab`,
`driftwood` and anything new. If this skill and `DESIGN.md` disagree,
`DESIGN.md` wins. Never invent a palette, pick fonts, or keep a UI kit's
default theme instead.

## Starting a new project

Wire it in from the first commit, not as a later restyle.

1. **Pick the tier.** Tool tier (life, homelab, driftwood: dense, 15px body,
   no motion) is the default with no class. A public marketing surface
   (brignano.io) opts in with `class="tier-marketing"` on `<html>`, which
   unlocks the display face, the larger scale and scroll motion. Colour is
   identical across both. If unsure, it is a tool.

2. **Install rather than copy values:**

   ```sh
   npm install @brignano/design
   ```

   Keep the caret (`^0.3.1` at time of writing). A caret on `0.x` pins the
   minor, so a new minor release needs an explicit bump in every consumer.

   No build step? Use jsDelivr, pinned:
   `https://cdn.jsdelivr.net/npm/@brignano/design@0.3.1/tokens.css`

3. **Import.** Plain CSS:

   ```css
   @import "@brignano/design/tokens.css";
   @import "@brignano/design/tokens.chart.css"; /* only if the surface has charts */
   ```

   Tailwind v4 — this order, and use the bridged utilities (`bg-card`,
   `text-ink`, `bg-interactive`, `bg-danger-surface`, …), never the stock
   palette (`blue-600`, `gray-*`, `violet-*`):

   ```css
   @import "tailwindcss";
   @import "@brignano/design/tokens.css";
   @import "@brignano/design/tailwind.css";
   ```

4. **Load the fonts yourself.** The tokens only name them: Geist (`--sans`),
   IBM Plex Mono (`--mono`), and Silkscreen (`--display`, marketing tier only).
   Use `next/font`, Fontsource or the `geist` package.

5. **Set the browser floor** in the consumer's `package.json`, or Lightning CSS
   (Next, Vite, Parcel) lowers `light-dark()` and `data-theme` on an inner
   element stops re-theming that section:

   ```json
   "browserslist": ["chrome >= 123", "edge >= 123", "firefox >= 120", "safari >= 17.5"]
   ```

6. **Theme switching.** No attribute follows the OS. A manual toggle sets
   `data-theme="light"|"dark"`. **Tailwind consumers must set `data-theme`
   alongside `.dark`**, in both the pre-paint script and the toggle — Tailwind
   keys off the class, the tokens key off the attribute (`DESIGN.md` §11):

   ```js
   root.classList.toggle("dark", d);
   root.setAttribute("data-theme", d ? "dark" : "light");
   ```

7. **Before calling it set up:** grep for hex, `rgb(`, `hsl(` and stock
   Tailwind colour utilities (there should be none), look at the page in both
   themes, and note in the README that it uses `@brignano/design` and which tier.

## The rules that matter most

- **One hue, one meaning.** `--i-*` = you can act on this. `--success` =
  settled/done. `--attention` = this wants you (warning *and* now/next — they
  are the same message at different volumes). `--danger` = something broke.
  `--mark` = identity, and it inks a *graphic* only (trail, `A|B` monogram,
  hero rule), never a control, chip, border or link. One or two coloured
  things per tool-tier screen.
- **Never hardcode a hex outside `tokens.css`.** A literal survives a theme
  change silently. That is how a set of status pills stayed light grey in dark
  mode for months.
- **Colour is a surface, not text.** Use the `-surface` / `-line` wash tokens
  behind near-ink text; use the `-ink` step when a state must be a label.
- **Never colour alone** — every state ships with an icon and a word.
- **Controls.** Disabled is neutral (`--i-disabled-*`), never hued. Focus is
  always a visible 2px `--i-ink` outline, 2px offset. A control's own edge is
  `--line-control`.
- **Type.** `--sans` with tabular figures for body and headings; `--mono` for
  data that must read precise (codes, timestamps, stats, eyebrows). No serif.
- **Space and shape.** 4px scale `--s1…--s9`; `--radius-sm` / `--radius` /
  `--radius-lg`. Light mode separates surfaces with hairline + shadow; dark
  mode with lighter surfaces, not borders.
- **Motion is progressive enhancement.** Content is visible without JS or
  animation; reduced motion renders the final state.
- **Tokens in JS.** Don't read them with `getPropertyValue` (it returns the
  `light-dark(...)` text). Set `el.style.color = 'var(--chart-1)'`, read
  `getComputedStyle(el).color`, re-read on theme change. Don't wrap tokens in
  `color-mix()` or `light-dark()`.
- **Charts** are the one place restraint does not apply: use `--chart-1..8` in
  fixed order, never cycled, assigned per entity and **per chart**. Legend for
  2+ series; never a dual-axis chart.
- **Diagrams are not charts** (`DESIGN.md` §9). Nodes stay neutral; type is an
  icon and a label, never a hue. Colour is only for health (`--danger` down,
  `--attention` degraded, healthy is worded but uncoloured) and for what a
  change did: `--diff-added`, `--diff-changed`, `--diff-removed`, always with
  `+ added` / `~ changed` / `− removed`. A standalone export (Mermaid, SVG)
  uses the light theme's values, resolved from `tokens.css`, never typed in.
- **Accessibility floor.** Body text ≥ 4.5:1, UI marks ≥ 3:1, touch targets
  ≥ 44px on coarse pointers.

If a project genuinely needs something the system lacks, add it to
`brignano/design` (`npm run check` must pass) and bump the pin — do not invent
a local value.
