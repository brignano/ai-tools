# Global context — Anthony Brignano

## Devices
- MacBook (primary development machine)
- Windows desktop (no WSL)
- Linux homelab server (GMKtec M5 Ultra — Ryzen 7 7730U, 16GB DDR4, 512GB NVMe)

## Active repos
- `homelab` — Proxmox, Docker, Portainer, Tailscale, Grafana, Prometheus, Ollama, Open WebUI, PostgreSQL
- `ideas` — TSDs, proposals, and captured ideas across all domains
- `ai-tools` — this tooling, installed globally on every device
- `design` — **the design system**. Every UI I build styles from this. See below.

## How I work
- Spec-driven development: always draft and approve a TSD before implementing anything
- I have ADHD — I work on multiple things in parallel, so keep track of where we are and surface it clearly
- I self-host everything personally — always factor in hosting cost, complexity, and maintenance burden before proposing a solution
- I value clean UX and performance over feature count
- Ideas can come from anywhere — a sentence is enough to start a TSD

## Styling — always use the design system

**Before writing any UI, styling, or colour, read
[`brignano/design`](https://github.com/brignano/design) — `DESIGN.md` for the
rules, `tokens.css` for the values.** It is public, versioned, and already the
single source of truth for `brignano.io` and `life`.

Install it rather than copying values:

```jsonc
"@brignano/design": "github:brignano/design#v0.1.0"
```

```css
@import "@brignano/design/tokens.css";
```

No build step? Use jsDelivr:
`https://cdn.jsdelivr.net/gh/brignano/design@v0.1.0/tokens.css`

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
  keys off the class, the tokens key off the attribute. See `DESIGN.md` §10.
- **Charts** are the one place restraint does not apply: use `--chart-1..8` in
  fixed order, never cycled, assigned per entity and **per chart**.

If a project genuinely needs something the system lacks, add it to
`brignano/design` and bump the pin — do not invent a local value.

## Hosting & access — one pattern, one decision

**Read this before standing up any site or subdomain.** There is not a "public
pattern" and a "private pattern". There is one hosting pattern, and a separate
access decision layered on it. Conflating them is how a site meant to be private
ends up public.

```mermaid
flowchart TD
  A["Static site<br/>(Next/Astro export)"] --> B["Cloudflare Workers static assets<br/>wrangler.jsonc → assets.directory"]
  B --> C["GitHub Actions: npx wrangler deploy on push to main"]
  C --> D["Custom domain on the brignano.io zone<br/>(auto-created, proxied/orange)"]
  D --> E{"Who should reach it?"}
  E -->|Anyone| F["Leave it. No Access app."]
  E -->|Only people I name| G["Cloudflare Access:<br/>Protect this Worker, production + previews"]
```

**Default to private.** `life`, `trips`, `hoststats` and anything holding
personal data are Access-gated. Public is the deliberate exception, not the
fallback — if you cannot tell which one applies, ask.

### Rules that are load-bearing
- **Protect the *Worker*, not the hostname.** Since 2026-08-14 Access attaches
  to the Worker itself and covers its routes, custom domains, `workers.dev`
  URL and previews — nothing to keep in sync when domains change. Only drop to
  a hostname-based self-hosted app if you need WebSockets (worker-level
  policies 403 the upgrade) or deliberately want one hostname open.
- **Cover previews too.** A preview URL serves the same app; leaving it open
  defeats the point.
- **Create the Access application BEFORE any DNS resolves.** A Worker is live
  on `workers.dev` from its first deploy and a custom domain serves the moment
  it is attached.
  - **Workers do have a backstop** (corrected 2026-08-24). The account-wide
    **Workers** Access policy — Workers & Pages → Cloudflare Access, scope *All
    traffic* — is Enabled and covers every Worker's production and preview
    traffic from the first deploy. Do not confuse it with the Zero Trust
    *"block traffic to all domains in this account"* Default-Deny, which is
    **off** and stays off: that one rejected already-authorised requests with
    Error 1050.
  - **Nothing else has one.** A Pages project, or any hostname that is not a
    Worker, is served unprotected — so the destination list on a hostname-based
    application still has to be right.
  - **The ordering rule holds anyway**, for a different reason: the
    account-wide policy allows a single identity, so a Worker deployed before
    its own application exists is *private to me*, not shared. The per-Worker
    policy is what lets other people in, not what keeps strangers out.
- **Proxy status is not uniform.** Cloudflare-hosted hostnames must be
  **orange/proxied** — Access only enforces on proxied traffic, and a
  grey-cloud record bypasses it entirely. Vercel hostnames (`brignano.io`,
  `www`) must stay **grey/DNS-only** or certificate issuance breaks.
- **Never set MFA or session policy account-wide.** Org-level TOTP applies to
  every app and every person, including family. Anything that changes the login
  experience belongs on the individual application.
- **One-time PIN is the default sign-in method** for family and friends — no
  IdP to configure. Google is worth it if everyone has an account. Facebook is
  a dead end for a personal site (Advanced Access needs business verification).

### Where the worked example lives
[`hoststats/docs/DEPLOYING.md`](https://github.com/brignano/hoststats/blob/main/docs/DEPLOYING.md)
is the reference implementation — hosting, GitHub Actions secrets/variables,
custom domain, Access, and a symptom→cause table. Copy it rather than
re-deriving. `life/DEPLOY.md` covers the same ground for a Cloudflare Pages
project.

### Current estate
| Site | Host | Access |
|---|---|---|
| `brignano.io`, `anthonybrignano.com` | Vercel (static Next export), grey-cloud | public by design |
| `life.brignano.io` | Cloudflare **Pages** (project `life`) | `Me` — verified enforcing 2026-08-24 |
| `trips.brignano.io` | Workers static assets — **not yet created** | `Me` + `Family` + `Trip friends` |
| `hoststats.brignano.io` | Cloudflare **Workers** static assets | **public** — `bypass` / everyone |

New sites use **Workers static assets**, not Pages — Cloudflare's own docs now
open the Pages section with "Start new projects with Workers". `life` predates
that; migrating it is worth doing but is not a prerequisite for anything, and
should follow `trips` rather than lead it, since a migration creates new
hostnames that must be Access-covered before they serve.

### Access: private by default, public on purpose

The account-wide Workers Access floor is **on** (Workers & Pages → Cloudflare
Access), set to the `Me` policy. Every Worker is therefore private from its
first deploy — including one you create tomorrow and forget about. A site is
public only because someone attached a **bypass** policy saying so.

Rules are evaluated most-specific-first, and a more specific rule **replaces**
the broader one rather than stacking with it:

1. Hostname or path application
2. Worker-level application
3. Account-wide floor

That third point is the one that bites: a Worker with its own policy no longer
consults the floor, so **attach `Me` alongside whatever audience a site admits**
or you lock yourself out of your own site.

**Audiences are reusable policies**, named for who they are rather than which
site uses them, under Zero Trust → Access controls → Policies:

| Policy | Who | Attached to |
|---|---|---|
| `Me` | just me | everything, plus the account-wide floor |
| `Family` | permanent people, every address each wants to use | `trips` |
| `Trip friends` | ad-hoc, created with the first real member | `trips` |

`hoststats` is the deliberate exception — an MIT-licensed public tool with a
live URL in its README, exempted with a `bypass` / `everyone` policy.

Adding a relative is one edit to `Family` and it lands on every site that
includes it. **Include rules are OR** — so one person holding two addresses is
just two entries, and a site admitting two audiences is just both policies
attached.

Two traps worth remembering:

- **Google sign-in matches the Google account's address.** Allow-listing
  someone's other email means Google sign-in fails for them even though the
  method is enabled. Ask which address they actually sign in with; list both if
  they want both routes.
- **Never set MFA or session policy account-wide.** Set session duration on the
  audience policy instead — it supersedes the app and global values, so family
  get long sessions everywhere without touching anyone else.

An IdP is only how someone proves they hold an address; enabling one never
widens who is allowed in.

## Releases — the GitHub release page is the changelog

**I create releases in the GitHub UI, and the release notes are the record.**
Anyone following a project reads that page to find new capabilities as they
ship. So it gets written for that reader, by hand. There is no `CHANGELOG.md`
duplicating it, and npm is distribution only — never where changes are
documented.

What this means when you are helping me cut one:

- **Do not hand me `git tag` / `git push origin <tag>`.** Releases → *Draft a
  new release* → *Choose a tag* creates the tag on publish. The whole flow is
  the UI, so CLI steps are noise I have to translate.
- **Always include the notes as a copy-pasteable fenced markdown block**, ready
  to paste into the body with nothing to edit first. Proposing a release without
  the notes attached is half an answer — attach them without being asked.
- **Write for a consumer, not a maintainer.** Lead with what they can now do. A
  generated list of merged PR titles is raw material for the notes, not the
  notes.
- **Keep repo hygiene out of them.** "The LICENSE file was missing" is a commit
  message; a release page reader needs "MIT licensed".

### Release automation, where a repo has any
A workflow on `v*` tags must **verify, never create**. Publishing from the UI is
what creates the tag, so by the time the workflow runs the release already
exists and there is nothing left for it to make. Have it re-run the checks
against the tagged tree and fail loudly when the tag disagrees with the version
in `package.json` — that mismatch is invisible once a release page exists.

Do not expect a stray `gh release create` to announce itself by failing. With
`--draft` it **succeeds**: a draft is not bound to a tag, so it does not collide
with the published release, and you get a second release object, same name,
unpublished, authored by `github-actions[bot]`. `hoststats` v0.1.0 left exactly
one of those behind. Only a non-draft create errors. Silent duplication is both
the likelier outcome and the harder one to spot.

Note also that verification lands *after* publication, so a red run means "pull
that release", not "the release was blocked". Say so in the workflow rather than
implying a gate that is not there.

## Communication preferences
- Short, direct responses
- No unnecessary caveats or softening
- Use Mermaid diagrams when explaining flows or architecture
- If something I propose is a bad idea, say so directly with the reason

## Decision defaults
- Prefer self-hosted over SaaS when complexity is comparable
- Prefer simple and maintainable over clever
- Prefer proven tools over new ones unless there's a clear reason
- Always consider: what does this cost to run monthly?

## Custom commands & output styles
Installed globally from the `ai-tools` repo. Slash commands live in `commands/`
(each self-describes via frontmatter — run `/` to list them); reusable personas live
in `output-styles/` (`/output-style` to switch). This list is intentionally not
duplicated here — the directories are the source of truth.
