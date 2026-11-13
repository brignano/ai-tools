---
name: design-system
description: How to style anything with brignano/design — wiring it into a new project (npm or jsDelivr, fonts, browserslist, Tailwind bridge, a product's mark, components, templates, icons), what each colour token means, fill vs ink vs surface steps, the mono voice, the two tiers, dark mode, chart colours, and diagram/diff colours. Use when starting any new project, site or app, and before writing any UI, CSS, Tailwind classes, colour, theme, chart or diagram colours or component styling, in any repo.
---

# Styling — always use the design system

**Before writing any UI, styling, or colour, read
[`brignano/design`](https://github.com/brignano/design) — `DESIGN.md` for the
rules, `tokens.css` for the values, `releases/` for what each version
changed.** It is public, versioned, and the single source of truth for
`brignano.io`, `life`, `julia`, `hoststats`, `homelab`, `driftwood` and
anything new. This skill is a short summary of it. If this skill and
`DESIGN.md` disagree, `DESIGN.md` wins. Never invent a palette, pick fonts, or
keep a UI kit's default theme instead.

## Starting a new project

Wire it in from the first commit, not as a later restyle.

1. **Pick the tier.** Tool tier (life, homelab, driftwood: dense, 15px body,
   no decorative motion) is the default with no class. A public marketing surface
   (brignano.io) opts in with `class="tier-marketing"` on `<html>`, which
   unlocks the larger scale and scroll motion. Colour is identical across
   both. If unsure, it is a tool.

2. **Install rather than copy values:**

   ```sh
   npm install @brignano/design
   ```

   That takes the latest 0.x; `npm view @brignano/design version` prints it.
   Keep the caret npm writes. A caret on `0.x` pins the minor (`^0.9.0` takes
   0.9.1 but never 0.10.0), so a new minor release needs an explicit bump in
   every consumer. Read that version's notes in `releases/` before bumping.

   No build step? Use jsDelivr, pinned to the version that command prints
   (the same path serves `components.css`, `templates/` and `icons/`):
   `https://cdn.jsdelivr.net/npm/@brignano/design@<version>/tokens.css`

3. **Import.** Plain CSS:

   ```css
   @import "@brignano/design/tokens.css";
   @import "@brignano/design/components.css";   /* buttons, fields, messages, the voice classes */
   @import "@brignano/design/tokens.chart.css"; /* only if the surface has charts */
   ```

   `components.css` is the shared controls and patterns as plain CSS, in one
   layer (`brignano.components`) that your own unlayered CSS beats without
   `!important` (`DESIGN.md` §14). State
   comes from the attribute that makes it true (`disabled`, `aria-invalid`,
   `aria-current`), never a class. Use a component before writing your own;
   each one's page under `previews/` is its docs (snippet, when to use it,
   when not to, accessibility).

   Tailwind v4 — this order, and use the bridged utilities (`bg-card`,
   `text-ink`, `bg-interactive`, `bg-danger-surface`, …), never the stock
   palette (`blue-600`, `gray-*`, `violet-*`):

   ```css
   @import "tailwindcss";
   @import "@brignano/design/tokens.css";
   @import "@brignano/design/tailwind.css";
   ```

4. **Set the product's mark.** A product with its own mark colour sets it
   once, `<html data-mark="teal">` (or `violet`, `magenta`), and its brand
   glyph, error pages and `.rule` draw in it (`--mark-current`), the same in
   its app as on its product page. With no attribute the mark is the family
   amber, which personal tools share. A product gets its own hue when it gets
   a product page, not before.

5. **Start from a template and the icon set.** Whole-page layouts ship as
   `@brignano/design/templates/<name>.css`, imported after `components.css`:
   `app-shell` (the frame a tool app sits in), `settings`, `error` (404, 500,
   offline), `article`, `changelog` and `legal`. The transactional email is
   `templates/email.html` + `email.txt`, not a stylesheet: fill its colours
   from the tokens with `scripts/email-tokens.mjs`. Icons come only from the package's `icons/`
   (Lucide outlines in `currentColor`, at `@brignano/design/icons/<name>.svg`):
   paste one inline and size it with `.icon-sm`, `.icon` or `.icon-lg`. Need
   one that isn't there? Add it to design from Lucide; don't draw one or pull
   in another set.

6. **Load the fonts yourself.** The tokens only name them: Geist (`--sans`)
   and IBM Plex Mono (`--mono`). Use `next/font`, Fontsource or the `geist`
   package, and load Geist as the variable font or include weight 800:
   `.display` and `.stamp` need it. Heavy Geist is the display treatment in
   both tiers. Silkscreen is being retired: `--display` still names it on the
   marketing tier until brignano/design#142 removes it, so only a surface that
   already uses `var(--display)` still loads it.

7. **Set the browser floor** in the consumer's `package.json`, or Lightning CSS
   (Next, Vite, Parcel) lowers `light-dark()` and `data-theme` on an inner
   element stops re-theming that section:

   ```json
   "browserslist": ["chrome >= 123", "edge >= 123", "firefox >= 120", "safari >= 17.5"]
   ```

8. **Theme switching.** No attribute follows the OS. A manual toggle sets
   `data-theme="light"|"dark"`. **Tailwind consumers must set `data-theme`
   alongside `.dark`**, in both the pre-paint script and the toggle — Tailwind
   keys off the class, the tokens key off the attribute (`DESIGN.md` §11):

   ```js
   root.classList.toggle("dark", d);
   root.setAttribute("data-theme", d ? "dark" : "light");
   ```

9. **Before calling it set up:** grep for hex, `rgb(`, `hsl(` and stock
   Tailwind colour utilities (there should be none), look at the page in both
   themes, and note in the README that it uses `@brignano/design`, which tier,
   and its mark if it has one.

## The rules that matter most

- **One hue, one meaning.** `--i-*` = you can act on this. `--success` =
  settled/done. `--attention` = this wants you (warning *and* now/next — they
  are the same message at different volumes). `--danger` = something broke.
  `--mark` = identity, and it inks a *graphic* only (a product's glyph, the
  `A|B` monogram, a hero rule), never a control, chip, border or link. A
  product's own mark (`data-mark`) has the same contract: buttons and links
  stay cobalt on every product. One or two coloured things per tool-tier
  screen.
- **Never hardcode a hex outside `tokens.css`.** A literal survives a theme
  change silently. That is how a set of status pills stayed light grey in dark
  mode for months.
- **Colour is a surface, not text.** Use the `-surface` / `-line` wash tokens
  behind near-ink text; use the `-ink` step when a state must be a label.
- **Fill and ink are different steps.** Fill a surface with `--i` (hover
  `--i-hover`, pressed `--i-pressed`) under a white `--on-i` label, in both
  themes. Write or draw on a surface with `--i-ink` (links, icons, focus). A
  hovered link takes `--i-ink-hover`, never `--i-hover`: in dark that is a
  deep fill, too dark to read as text. A destructive button fills with
  `--danger-fill` (and its `-hover` / `-pressed` steps) under `--on-danger`,
  not with `--danger`, which in dark is a pale rust for reading.
- **Never colour alone** — every state ships with an icon and a word.
- **Controls.** Disabled is neutral (`--i-disabled-*`), never hued. Focus is
  always a visible 2px `--i-ink` outline, 2px offset. A control's own edge is
  `--line-control`.
- **Type.** `--sans` with tabular figures for body and headings; `--mono` for
  data that must read precise (codes, timestamps, stats, eyebrows). No serif.
  Weights are 400 / 500 / 600 (`--weight-regular` / `-medium` / `-semibold`),
  nothing lighter or bolder except the one heavy moment below.
- **The voice** (classes in `components.css`). **One eyebrow per screen:**
  `.eyebrow`, a small uppercase mono label above the screen's heading that
  says where you are; one, not one per card, written in sentence case. **Numbers
  in mono:** any number, date, time or code a person might compare or copy
  takes `.num`. **One heavy moment:** `.display` sets an error code or a
  single headline figure in Geist 800, and `.stamp` sets the `A|B` monogram
  at the same weight, spaced open; at most once a screen. `.rule` is the
  short bar in the mark above a hero heading.
- **Words are part of the interface** (`DESIGN.md` §15): sentence case, a
  button is a verb and its object, errors say what happened and how to fix it.
- **Space and shape.** 4px scale `--s1…--s9`. Four radii, by what the thing
  is: `--radius-sm` (6px) chips and pills; `--radius-control` (8px) buttons,
  inputs, selects, the segmented control and menu items; `--radius` (12px)
  cards, messages, popovers and code blocks; `--radius-lg` (18px) dialogs
  and hero surfaces. Light mode separates surfaces with hairline + shadow;
  dark mode with lighter surfaces, not borders.
- **Motion is progressive enhancement.** Content is visible without JS or
  animation; reduced motion renders the final state. The tool tier moves
  only when a person asks: an overlay opening or closing, a button press, a
  switch of view (`DESIGN.md` §7).
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
