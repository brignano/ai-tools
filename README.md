# ai-tools

Global Claude Code context and commands — installed once per device, works everywhere.

## Install

**Mac / Linux (run once per machine):**
```bash
git clone https://github.com/brignano/ai-tools ~/.ai-tools
chmod +x ~/.ai-tools/install.sh
~/.ai-tools/install.sh
```

**Windows (run once in PowerShell as Administrator):**
```powershell
git clone https://github.com/brignano/ai-tools $env:USERPROFILE\.ai-tools
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
~\.ai-tools\install.ps1
```

## Update (any machine)

```bash
# Mac/Linux
cd ~/.ai-tools && git pull

# Windows
cd $env:USERPROFILE\.ai-tools; git pull
```

That's it — symlinks mean the update is instant, no re-install needed.

## What gets installed

| File | Destination | Purpose |
|------|-------------|---------|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global context loaded every Claude Code session |
| `claude/commands/*.md` | `~/.claude/commands/` | Slash commands available in every repo |

## Structure

```
ai-tools/
├── install.sh              # Mac/Linux installer
├── install.ps1             # Windows installer
└── claude/
    ├── CLAUDE.md           # Global context (devices, preferences, conventions)
    └── commands/           # Available as /command-name in any Claude Code session
        ├── new-tsd.md
        ├── review-docker-compose.md
        ├── plan-new-service.md
        ├── review-pr.md
        ├── write-setup-log.md
        ├── homelab-health-check.md
        └── app-preview-deploy.md
```

## Adding a new command

1. Add a `.md` file to `claude/commands/`
2. `git push`
3. `git pull` on any other machine — symlinks update automatically
