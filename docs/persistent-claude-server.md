# Persistent Claude Code across devices

**Decision: use cloud sessions by default. Self-host only to operate the *live* homelab
from the phone.**

The problem: Claude Code history is per-machine local files under `~/.claude/`, so
closing the MacBook strands it. The goal was one always-on backend every device —
including the phone — could pick up from.

Cloud sessions (`claude.ai/code`) solve that with zero hosting: they run on
Anthropic-managed infrastructure, sync across devices, and are always reachable from the
phone's native app. They operate on **GitHub-connected repos**.

Self-hosting only earns its complexity for the one thing cloud can't do: reach things
that exist *only* on the homelab — running containers, `hl-*` against live Docker,
local services (Postgres/Grafana/Ollama), uncommitted files.

| Your work is… | Use |
|---|---|
| Code/config/docs in `ai-tools`, `ideas`, `homelab`-as-a-repo | **Cloud sessions** |
| Operating the live homelab (deploy, `hl-ps`, local-only files/services) | **Homelab-backed** (below) |

Why cloud is the default even though self-hosting works: the self-hosted paths are only
as reliable as the box, and during this exercise the server was unreachable for a
stretch (tailnet `offline`, no LAN reply). A phone that depends on it inherits every
outage. A permanently-on, phone-reachable agent with shell access is also real blast
radius. Cloud has neither problem.

---

## Homelab-backed paths (validated, for live-homelab work)

| Path | Mac / Windows | Phone | Transport | Status |
|------|---------------|-------|-----------|--------|
| **A. Desktop SSH sessions** | ✅ native app → SSH → homelab | ❌ not directly | Direct SSH (Tailscale) | Documented, reliable |
| **B. Remote Control on the server** | ✅ native app | ✅ native app | Anthropic relay | **Verified working on a headless server** |
| **C. SSH terminal + tmux** | ✅ any terminal | ✅ any SSH app | Direct SSH (Tailscale) | Works; terminal UI, not native chat |

All three run as one dedicated **`claude`** user sharing a single `~/.claude/` history
store on the server, so sessions resume from any client.

### A — Desktop SSH sessions (Mac + Windows)

Native app UI; session and history live on the homelab.

1. Desktop app → environment dropdown → **Add SSH connection** → `claude@<host>`, your
   identity file.
2. Start a session. The app installs Claude Code on the server on first connect;
   sessions run there, history in `~/.claude/projects/` **on the server**.
3. MCP servers, plugins, permissions, and file editing all work.

### B — Remote Control on the server (the only native-app phone path)

**Verified end to end (Claude Code 2.1.x, mid-2026):** Remote Control runs fine on a
headless Linux server. There is **no "must be a personal machine" restriction** — the
only gate is a claude.ai subscription login:

```
Remote Control is only available with claude.ai subscriptions.
Please use `/login` to sign in with your claude.ai account.
```

It's a **flag on a normal session**, not a subcommand:

```bash
ssh claude@<host>
tmux new-session -A -s rc
claude                              # /login once — claude.ai OAuth
claude --remote-control homelab     # named Remote Control session
```

The session then appears in the phone's native app. Transport is **outbound HTTPS
only**, relayed through Anthropic — **the phone needs no Tailscale and no inbound
ports**. Confirmed: the session shows up on the phone and survives the Mac being closed.

Notes:
- The process must stay running — use tmux or a systemd unit, or the session ends.
- The middleman is **Anthropic's relay**, not your server; the box is the always-on
  *host*, not the wire.
- This is a live, phone-reachable agent that can run commands on your homelab. Run it as
  the least-privilege `claude` user, never root.

### C — SSH terminal + tmux (fallback)

Works from any phone SSH app (Termius/Blink) — terminal UI, not native chat.
Attach/detach hands live sessions between devices.

```bash
alias cc='ssh -t claude@<host> "tmux new-session -A -s main"'
```

`Ctrl-b d` detach · `Ctrl-b c` new window · `Ctrl-b n/p` switch · `Ctrl-b [` scroll.
Add `tmux-resurrect` so windows return after a reboot (history survives regardless).

---

## Server groundwork (if you stand this up)

Dedicated **`claude`** user (least privilege) + **subscription OAuth** (draws from the
plan, not metered API billing).

```bash
# as root
adduser --gecos "" claude                 # no sudo, not in docker group (socket = root)
install -d -m 700 -o claude -g claude /home/claude/.claude
install -d -m 755 -o claude -g claude /home/claude/projects

# as claude
curl -fsSL https://fnm.vercel.app/install | bash && source ~/.bashrc
fnm install --lts && fnm default lts-latest
npm install -g @anthropic-ai/claude-code
claude                                    # /login — claude.ai OAuth
```

> `claude` is deliberately **not** in the `docker` group — that's root-equivalent via the
> socket. Lab actions go through an explicit `ssh root@<host> hl-...`. Cleaner isolation
> later: give Claude its own small LXC, walled off from lab infra.

**Prerequisite — the box must actually stay up.** Make it survive reboots before relying
on it:

```bash
systemctl status tailscaled
sudo systemctl enable --now tailscaled    # tailnet returns after reboot
tailscale up --accept-routes
```

Also confirm auto-boot on power restore (BIOS "restore on AC loss") and that Proxmox
starts the LXC/VM on boot. An uptime check is worth it so a silent multi-day outage
can't recur.

> **Overlapping-subnet gotcha:** if a client sits on a network that also uses
> `10.0.0.0/24`, the directly-connected subnet wins over Tailscale's advertised route and
> the LAN address resolves to the wrong host. Off-LAN, reach the server by its
> **Tailscale IP / MagicDNS name**, not its LAN IP.

**Teardown** (what a test leaves behind — the OAuth token is the part that matters):

```bash
npm rm -g @anthropic-ai/claude-code
rm -rf ~/.claude          # includes .credentials.json
```

---

## Notes

- **RAM:** ~150–400 MB per active session, low end when detached — negligible on 16 GB
  next to Ollama/Postgres/Grafana. The real cost is what Claude *runs* (builds, tests),
  not the agent. No local model; compute is Anthropic's cloud, so server specs don't
  bottleneck it.
- **Tokens:** limits are account-side (your plan), not gated by hardware. No local
  harness unlocks more capacity; parallelism (native subagents/workflows) spends the
  budget faster, not slower.
- **Mobile scope:** the phone app is a *client*. It reaches cloud sessions, a session via
  Remote Control, or the desktop app via Dispatch — it cannot SSH into the homelab
  directly.
- **Secrets:** any session on the box can read whatever the `claude` user can. Keep real
  secrets in gitignored `secrets.env` and know they're readable server-side.
