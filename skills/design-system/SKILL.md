---
name: design-system
description: How to style anything with brignano/design — installing tokens.css (npm or jsDelivr), what each colour token means, surface vs ink steps, the two tiers, Tailwind dark mode, chart colours, and diagram/diff colours. Use before writing any UI, CSS, Tailwind classes, colour, theme, chart or diagram colours or component styling, in any repo.
---

# Styling — always use the design system

**Before writing any UI, styling, or colour, read
[`brignano/design`](https://github.com/brignano/design) — `DESIGN.md` for the
rules, `tokens.css` for the values.** It is public, versioned, and already the
single source of truth for `brignano.io`, `life`, `julia`, `hoststats`,
`homelab` and `driftwood`.

Install it rather than copying values:

```jsonc
"@brignano/design": "^0.2.0"
```

```css
@import "@brignano/design/tokens.css";
```

No build step? Use jsDelivr:
`https://cdn.jsdelivr.net/npm/@brignano/design@0.2.0/tokens.css`

A caret on `0.x` pins the minor, so a new minor release needs an explicit bump
in every consumer.

The rules that matter most, so you can apply them without reading everything:

- **One hue, one meaning.** `--i-*` = you can act on this. `--success` =
  settled/done. `--attention` = this wants you (warning *and* now/next — they
  are the same message at different volumes). `--danger` = something broke.
  `--mark` = identity, and it inks a *graphic* only, never a control.
- **Never hardcode a hex outside `tokens.css`.** A literal survives a theme
  change silently. That is how a set of status pills stayed light grey in dark
  mode for months.
- **Colour is a surface, not text.** Use the `-surface` / `-line` wash tokens
  behind near-ink text; use the `-ink` step when a state must be a label.
- **Never colour alone** — every state ships with an icon and a word.
- **Two tiers.** Tool tier is the default; a marketing surface opts in with
  `class="tier-marketing"`. Colour is identical across both.
- **Tailwind consumers must set `data-theme` alongside `.dark`** — Tailwind
  keys off the class, the tokens key off the attribute. See `DESIGN.md` §11.
- **Charts** are the one place restraint does not apply: use `--chart-1..8` in
  fixed order, never cycled, assigned per entity and **per chart**.
- **Diagrams are not charts** (`DESIGN.md` §9). Nodes stay neutral; type is an
  icon and a label, never a hue. Colour is only for health (`--danger` down,
  `--attention` degraded, healthy is worded but uncoloured) and for what a
  change did: `--diff-added`, `--diff-changed`, `--diff-removed`, always with
  `+ added` / `~ changed` / `− removed`.

If a project genuinely needs something the system lacks, add it to
`brignano/design` and bump the pin — do not invent a local value.
