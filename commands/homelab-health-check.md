---
description: Audit all running containers and system resources; surface anything worth attention
allowed-tools: Bash(hl-ps:*), Bash(hl-ssh:*), Bash(hl-status:*)
---

**Purpose:** Audit the current state of all running Docker stacks and surface anything worth attention.

**Run this when:** something feels off, after a reboot, or weekly as a sanity check.

> Drives the homelab through the `hl-*` commands, so it works from any machine
> (Mac, Windows, or the server itself) - `hl-ps` and `hl-ssh` SSH into the Docker LXC
> as needed. If something looks unreachable, run `hl-status` first to tell whether it's
> the client, the Tailscale route, or the server that's actually down (a Tailscale flap
> is not a lab outage).

## Steps the agent should execute

1. `hl-ps` - list all containers and their status
2. For any container not in `Up` state or showing `(unhealthy)`: `hl-ssh "docker logs --tail 30 <name>"` (bounded snapshot; do **not** use `hl-logs`, which follows and would hang the audit)
3. `hl-ssh "df -h / && df -h /var/lib/docker"` - check disk usage
4. `hl-ssh "free -h"` - check memory pressure
5. `hl-ssh "docker system df"` - check Docker's storage usage (images, volumes, build cache)
6. Confirm the expected containers are running (read from the `hl-ps` output): portainer, postgres, prometheus, grafana, node-exporter, cadvisor, ollama, open-webui, cloudflared

## Output format

Report findings as a table:

| Container | Status | Issue | Action needed |
|-----------|--------|-------|---------------|
| ...       | ...    | ...   | ...           |

Then a separate section for system resources with any warnings (disk >80%, memory >90%).

Finally, suggest any `hl-ssh "docker system prune ..."` commands if build cache or dangling images are wasting significant space - but do not run them automatically.
