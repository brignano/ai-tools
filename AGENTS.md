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
- `driftwood` — architecture as code, reconciled with live infrastructure (npm package)
- `guidebook` — guided walkthroughs on any website (private, proof of concept)
- `sites`, `receipts`, `brignano.io`, `breakeven`, `card` — products, each run from its own Claude project
- `life`, `people` — personal; never referenced from issues or PRs in other repos

## How I work
- Spec-driven development: always draft and approve a TSD before implementing anything
- I have ADHD — I work on multiple things in parallel, so keep track of where we are and surface it clearly
- I self-host everything personally — always factor in hosting cost, complexity, and maintenance burden before proposing a solution
- I value clean UX and performance over feature count
- Ideas can come from anywhere — a sentence is enough to start a TSD

## Planning & delegation

The main session plans; cheaper subagents implement — but only for real features.
- **Small changes stay fast:** feedback tweaks, copy, styling, a bug in a known
  spot, follow-ups in the same session. Just make the edit here: no plan, no
  delegation, even if it touches a couple of files.
- **New features or changes spanning several components:** write a short plan
  first (files, steps, how each is verified) and get my OK, unless an approved
  TSD or plan already covers it.
- **I can override either way:** "just do it" skips the plan; "plan this" forces one.
- **Then delegate:** hand each concrete step to the `implementer` agent (Sonnet)
  rather than writing it here. Independent steps can run in parallel. The default
  model is `opusplan` (Opus in plan mode, Sonnet otherwise; `/model` overrides),
  and the implementer runs in its own git worktree: review its diff, then merge its branch.
- **Searches** go to `Explore` (Haiku), **long test/lint runs** to `test-runner`.
- **Keep here:** design decisions, debugging an unknown cause, reviewing what the
  agents return, and anything small enough that a handoff costs more than doing it.

## Agent fleet

The rules every agent follows are the fleet essentials (loaded at session
start) and the `fleet-standard` skill (the full
[`fleet/README.md`](fleet/README.md)): load it before planning, building,
reviewing or merging.

## Skills to load first

- **Any UI, styling or colour:** the `design-system` skill. Every UI styles from
  [`brignano/design`](https://github.com/brignano/design) tokens; never pick a
  colour or hardcode a hex. Missing something? Add it to design, don't invent it.
- **Any site, subdomain, preview or access change:** the `hosting` skill.
  Cloudflare Workers on the `brignano.io` zone, private by default.
- **Planning or cutting a release, release notes, tag workflows:** the
  `releases` skill. Releases are planned batches; ordinary PRs never bump a version.
- **Forms that take in leads:** the `leads` skill.

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

## Commands, skills & agents
Shipped by the `fleet` plugin from `ai-tools`, in every project and on every
machine: run `/` to list them. Fleet shortcuts: `/next`, `/handoff`,
`/merge-it`, `/new-repo`. Anything tied to one repo's paths, hosts or services
goes in **that repo's** `.claude/` instead.
