---
description: Audit all running containers and system resources; surface anything worth attention
allowed-tools: Bash(docker ps:*), Bash(docker logs:*), Bash(docker system df:*), Bash(df:*), Bash(free:*)
---

**Purpose:** Audit the current state of all running Docker stacks and surface anything worth attention.

**Run this when:** something feels off, after a reboot, or weekly as a sanity check.

## Steps the agent should execute

1. `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` — list all containers and their status
2. For any container not in `Up` state or with `(unhealthy)`: run `docker logs --tail 30 <name>`
3. `df -h /` and `df -h /var/lib/docker` — check disk usage
4. `free -h` — check memory pressure
5. `docker system df` — check Docker's storage usage (images, volumes, build cache)
6. Check that expected containers are running: portainer, postgres, prometheus, grafana, node-exporter, cadvisor, ollama, open-webui, cloudflared

## Output format

Report findings as a table:

| Container | Status | Issue | Action needed |
|-----------|--------|-------|---------------|
| …         | …      | …     | …             |

Then a separate section for system resources with any warnings (disk >80%, memory >90%).

Finally, suggest any `docker system prune` commands if build cache or dangling images are wasting significant space — but do not run them automatically.
