# New-device setup

The one runbook for getting a fresh machine onto the AI tooling **and** the homelab.
Start here on any new Mac, Windows, or Linux box. The installer does the safe,
mechanical parts; the few steps that need a password or a browser login are called
out as **manual**.

> Already have the repos cloned? Jump to [step 3](#3-run-the-installer).

---

## What you end up with

- Claude context, slash commands, output styles, settings, and 3 MCP servers
  (terraform, aws-mcp, homelab) — see [README](README.md).
- The homelab `hl-*` commands in your shell (`hl-help` for the list) — see
  [homelab/shell/README.md](https://github.com/brignano/homelab/blob/main/shell/README.md).
- SSH + Tailscale access to the homelab so `hl-ps`, `hl-logs`, `hl-up` work from anywhere.

---

## 1. Base tools

Install `git`, an SSH client, and `curl` if missing (the installer checks and tells you):

| OS | Command |
|----|---------|
| macOS | `brew install git curl` (SSH ships with macOS) |
| Debian/Ubuntu | `sudo apt install -y git openssh-client curl` |
| Windows | `winget install Git.Git OpenSSH.Client cURL.cURL` |

## 2. Clone both repos

```bash
git clone https://github.com/brignano/ai-tools  ~/.ai-tools
git clone https://github.com/brignano/homelab   ~/Projects/homelab
```

The installer will **offer to clone homelab for you** in step 3 if you skip it here.
(Windows paths: `$env:USERPROFILE\.ai-tools` and `$env:USERPROFILE\Projects\homelab`.)

## 3. Run the installer

Always dry-run first — it touches nothing and prints exactly what it will do.

**Mac / Linux:**
```bash
~/.ai-tools/install.sh --dry-run   # preview
~/.ai-tools/install.sh             # apply
```

**Windows** (PowerShell as Administrator, or with Developer Mode on — symlinks need it):
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
~\.ai-tools\install.ps1 -DryRun    # preview
~\.ai-tools\install.ps1            # apply
```

The installer: checks prerequisites, **generates an SSH key if you don't have one**,
symlinks the Claude config, registers the MCP servers, and wires `hl-*` + secrets into
your shell profile. It's idempotent — re-run any time to update.

> **On the homelab server itself**, point it at the server's checkout:
> `HOMELAB_DIR=/root/homelab ~/.ai-tools/install.sh`. There the `hl-*` commands run
> Docker locally instead of over SSH.

## 4. Authorize your SSH key on the homelab — **manual** (one time)

The `hl-*` Docker commands SSH to the LXC at `root@10.0.0.201`. Install your public key
(needs the root password once):

```bash
ssh-copy-id root@10.0.0.201
```
```powershell
# Windows has no ssh-copy-id:
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@10.0.0.201 "cat >> .ssh/authorized_keys"
```

Verify: `ssh root@10.0.0.201 true` should return with no password prompt.

## 5. Join Tailscale — **manual** (browser login)

Needed to reach the homelab when you're **not** on the home LAN (on the LAN you reach
`10.0.0.201` directly). Install Tailscale (see step 1 hints / `tailscale.com/download`), then:

```bash
tailscale up --accept-routes
```

`--accept-routes` is what makes the `10.0.0.0/24` subnet (and the LXC) reachable over the
tailnet. After this, `hl-vpn-up` / `hl-vpn-down` toggle it day to day.

## 6. Fill in secrets

The installer copies `.env.example` → `secrets.env` (gitignored) on first run. Open it and
fill in the tokens (Grafana MCP bearer token, etc.), then open a new shell so it's loaded.

## 7. Verify

Open a **new** terminal (the wiring only applies to fresh shells), then:

```bash
hl-help            # the command list
hl-status          # client/route/server reachability — should say "all good"
hl-ps              # containers on the LXC (proves SSH + Tailscale/LAN path)
claude             # MCP servers connect (terraform, aws-mcp, homelab)
```

If `hl-status` flags a layer, fix that one (Tailscale down → `hl-vpn-up`; SSH denied →
redo step 4). `hl-status` exists precisely so a Tailscale flap doesn't read as a lab outage.

---

## Per-platform notes

- **macOS** — primary dev machine; `hl-*` run over SSH to the LXC.
- **Windows** — no WSL; PowerShell `$PROFILE` gets the `hl-*` functions. Run the installer
  elevated (symlinks). `hl-*` run over SSH.
- **Linux homelab server** — run with `HOMELAB_DIR=/root/homelab`; `hl-*` run Docker locally.

## Updating later

`git pull` in each repo. The shell profile sources the live `hl-*` file, so homelab updates
need no re-install. Re-run the installer only to pick up new commands / MCP servers / settings.
