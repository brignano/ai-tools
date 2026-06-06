# Prompt — Plan a new homelab service

I want to add **[SERVICE NAME]** to my homelab.

Hardware: GMKtec M5 Ultra (Ryzen 7 7730U, CPU-only, 16 GB RAM, 512 GB NVMe)
Hypervisor: Proxmox VE → Docker VM (Debian)
Existing stacks: core (Portainer + PostgreSQL), monitoring (Grafana + Prometheus), ai (Ollama + Open WebUI), tunnel (cloudflared)

**Exposure:** [Tailscale-only | Cloudflare Tunnel / public]
**Purpose:** [what I'll use it for]
**Constraints:** [e.g. needs GPU, needs large storage, needs to talk to PostgreSQL]

Please provide:
1. Recommended Docker image(s) and whether to pin a version
2. Required environment variables and volumes
3. A `docker-compose.yml` following my conventions (named volumes, `127.0.0.1` ports, Docker secrets / mounted secret files for sensitive values and `${VAR:?required}` env vars for non-sensitive config only, `unless-stopped`)
4. A `.env.example` with all *non-sensitive* variables (sensitive values go in secret files, not `.env`)
5. Any Proxmox-level considerations (RAM allocation, storage, full-disk encryption / LUKS)
6. If public: what to configure in Cloudflare Zero Trust
7. Secrets handling: where each sensitive value lives (Docker secret vs env), file ownership and permissions (dedicated non-root service user, `chmod 600`), and whether it's a scoped, revocable credential
