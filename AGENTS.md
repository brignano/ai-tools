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

Every UI styles from [`brignano/design`](https://github.com/brignano/design):
**never pick a colour and never hardcode a hex** — take it from `tokens.css`. If a
project needs something the system lacks, add it to `brignano/design` and bump the
pin rather than inventing a local value.

**Before writing any UI, styling or colour, read the `design-system` skill**
([`skills/design-system/SKILL.md`](skills/design-system/SKILL.md)): how to install
the tokens, what each colour means, and the rules for tiers, dark mode and charts.

## Hosting & access

One hosting pattern (Cloudflare Workers static assets on the `brignano.io` zone)
with a separate access decision layered on it. **Default to private** — public is
the deliberate exception, and if you cannot tell which applies, ask.

**Before standing up any site, subdomain or preview, or changing who can reach
one, read the `hosting` skill** ([`skills/hosting/SKILL.md`](skills/hosting/SKILL.md),
installed to `~/.claude/skills/hosting/`). It has the load-bearing Access rules,
the ordering that keeps a new site from serving before it is protected, and the
current estate.

## Releases

**I create releases in the GitHub UI, and the release page is the changelog.**
Before helping cut a release, writing notes, or touching a workflow that runs on
tags, read the `releases` skill ([`skills/releases/SKILL.md`](skills/releases/SKILL.md)).

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

## Custom commands, output styles, skills & agents
Installed globally from the `ai-tools` repo. Slash commands live in `commands/`
(each self-describes via frontmatter — run `/` to list them); reusable personas live
in `output-styles/` (`/output-style` to switch); skills in `skills/<name>/SKILL.md`;
subagents in `agents/`. This list is intentionally not duplicated here — the
directories are the source of truth.

Anything tied to one repo's paths, hosts or services goes in **that repo's**
`.claude/` instead, not here.
