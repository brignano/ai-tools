# Persistent Claude Code across devices, homelab-backed

Goal: one always-on Claude Code "backend" on the homelab, so sessions and history
survive whether or not the MacBook/desktop are powered on, and any device — including
the phone — can pick up where another left off.

This documents the three real ways to do that (as of mid-2026), which to use, and the
one prerequisite that gates all of them.

---

## Prerequisite (do this first): the box must actually be always-on

Every option below assumes the homelab server is reliably up. **During setup we found
it wasn't** — the `m5` node had been offline on the tailnet for ~5 days (`tailscale
status` → `offline, last seen 5d ago`; no LAN ARP reply on `10.0.0.201`). A
server-backed workflow is only as reliable as the box; if it drops, server-hosted
sessions die and the phone loses access — the exact thing this is meant to prevent.

Before committing your daily workflow, make the box survive reboots on its own:

```bash
# on the server
systemctl status tailscaled
sudo systemctl enable --now tailscaled     # so the tailnet comes back after a reboot
tailscale up --accept-routes
```

- Confirm it auto-boots on power restore (BIOS "restore on AC loss"), and that Proxmox
  starts the relevant LXC/VM on boot.
- Consider a Wake-on-LAN path and an uptime check so a silent 5-day outage can't recur.

> **Overlapping-subnet gotcha:** if a client is on a network that also uses
> `10.0.0.0/24`, the directly-connected local subnet wins over Tailscale's advertised
> route, so `10.0.0.201` resolves to the wrong (local) network. Reach the server by its
> **Tailscale IP / MagicDNS name** (`m5`), not `10.0.0.201`, when off the home LAN.

---

## The three paths

| Path | Mac / Windows | Phone | Transport | Status |
|------|---------------|-------|-----------|--------|
| **A. Desktop SSH sessions** | ✅ native app → SSH → homelab | ❌ not directly | Direct SSH (Tailscale) | Official, reliable |
| **B. Remote Control on the server** | ✅ native app | ✅ native app | Anthropic relay | Undocumented for a headless host — test before relying on it |
| **C. SSH terminal + tmux** | ✅ any terminal | ✅ any SSH app | Direct SSH (Tailscale) | Works, but it's a terminal UI, not the native chat |

All three run as the same **`claude`** user on the server, so they share **one
`~/.claude/` history store** — cross-device continuity is via that shared history
(resume a session from any client), regardless of which path you use.

### A — Desktop SSH sessions (recommended for Mac + Windows)

Native app UI, session and history live on the homelab.

1. In the desktop app, environment dropdown → **Add SSH connection** → `claude@m5`
   (or the tailnet IP), your identity file.
2. Select it, start a session. The app installs Claude Code on the server on first
   connect; sessions run there, history in `~/.claude/projects/` **on the server**.
3. MCP servers, plugins, permissions, file editing all work.

This replaces the old "SSH in and run tmux" dance for the two desktops.

### B — Remote Control on the server (experimental; the only native-phone path)

`claude remote-control` makes **outbound HTTPS only** and registers with Anthropic;
clients connect through **Anthropic's relay**, so the phone needs no Tailscale and no
inbound ports. If it runs on a headless server, the phone's native app can drive a
session hosted *on that server* with nothing else powered on.

**Caveat:** the docs don't explicitly cover running it on a headless box — the
architecture fits (there's even a documented "server mode"), but it's unconfirmed.
**Test it before betting your workflow on it.** The process must stay running (use
tmux/systemd). Note the transport middleman is Anthropic's relay, not your server —
your box is the always-on *host*, not the wire.

Test procedure:

```bash
ssh claude@m5
tmux new-session -A -s rc
claude          # one-time OAuth login (paste-token flow) if not already authed
claude remote-control      # emits a pairing URL/QR
```

Pair the phone's native app with the code, then confirm it's driving the
server-hosted session. If it works, this is the primary path (phone included).

### C — SSH terminal + tmux (phone fallback / terminal lovers)

Reachable from any SSH app (Termius/Blink), so it *does* give phone access — just not
the native chat UI. Attach/detach hands off live sessions between devices.

```bash
alias cc='ssh -t claude@m5 "tmux new-session -A -s main"'
```

Daily tmux keys: `Ctrl-b d` detach · `Ctrl-b c` new window · `Ctrl-b n/p` switch ·
`Ctrl-b [` scroll. Add `tmux-resurrect` so windows return after a reboot (history
survives regardless; re-run `claude` to resume).

---

## Server groundwork (needed for all paths)

Decisions locked: dedicated **`claude`** user (least privilege), **subscription OAuth**
auth (draws from your plan, not metered API billing).

```bash
# as root on the server
adduser --gecos "" claude                 # no sudo, not in docker group (socket = root)
install -d -m 700 -o claude -g claude /home/claude/.claude
install -d -m 755 -o claude -g claude /home/claude/projects

# as claude
curl -fsSL https://fnm.vercel.app/install | bash && source ~/.bashrc
fnm install --lts && fnm default lts-latest
npm install -g @anthropic-ai/claude-code
git clone https://github.com/brignano/ai-tools ~/.ai-tools
git clone https://github.com/brignano/homelab  ~/projects/homelab
git clone https://github.com/brignano/ideas    ~/projects/ideas
HOMELAB_DIR=/root/homelab ~/.ai-tools/install.sh --dry-run   # then drop --dry-run
claude    # OAuth login, paste-token flow
```

> `claude` is deliberately **not** in the `docker` group — that's root-equivalent via
> the socket. Lab actions go through an explicit `ssh root@m5 hl-...`. Cleaner isolation
> later = give Claude its own small LXC, walled off from lab infra.

---

## Recommendation

1. Fix the always-on prerequisite first (it was failing during setup).
2. **Test path B** — if `remote-control` works on the server, it's the whole goal in one
   mechanism, phone included.
3. If B doesn't pan out: **A** for Mac/Windows (rock-solid native app), **C** for the
   phone (terminal), or cloud sessions at `claude.ai/code` for phone work that doesn't
   need the homelab.

## Notes

- **RAM:** ~150–400 MB per active session, low end when detached — negligible on 16 GB
  next to Ollama/Postgres/Grafana. The real cost is the tasks Claude *runs* (builds,
  tests), not the agent. No local model; compute is Anthropic's cloud.
- **Tokens:** limits are account-side (your plan), not gated by server specs. No local
  harness unlocks more; parallelism (native subagents/workflows) spends them faster, not
  slower.
- **Secrets:** any session on this box can read `~claude/projects` — keep real secrets in
  gitignored `secrets.env` and know they're readable server-side.
