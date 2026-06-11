# Global context — Anthony Brignano

## Devices
- MacBook (primary development machine)
- Windows desktop (no WSL)
- Linux homelab server (GMKtec M5 Ultra — Ryzen 7 7730U, 16GB DDR4, 512GB NVMe)

## Active repos
- `homelab` — Proxmox, Docker, Portainer, Tailscale, Grafana, Prometheus, Ollama, Open WebUI, PostgreSQL
- `ideas` — TSDs, proposals, and captured ideas across all domains
- `ai-tools` — this tooling, installed globally on every device

## How I work
- Spec-driven development: always draft and approve a TSD before implementing anything
- I have ADHD — I work on multiple things in parallel, so keep track of where we are and surface it clearly
- I self-host everything personally — always factor in hosting cost, complexity, and maintenance burden before proposing a solution
- I value clean UX and performance over feature count
- Ideas can come from anywhere — a sentence is enough to start a TSD

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
