# ai-tools

AI-agnostic context and commands — one source of truth, installed once per device, works with any AI coding agent.

## How it works

`AGENTS.md` is the single source of truth for your preferences, devices, and conventions. The install script symlinks it to wherever each AI tool expects to find context — so you write it once and every agent on every machine stays in sync.

| AI Tool | Reads from |
|---------|-----------|
| Claude Code | `~/.claude/CLAUDE.md` |
| Cursor | `~/.cursorrules` |
| GitHub Copilot | `~/.github/copilot-instructions.md` |
| Windsurf | `~/.windsurfrules` |

All pointing at the same `AGENTS.md`. Adding a new tool = uncommenting one line in the install script.

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

Symlinks mean the update is instant — no re-install needed.

## Structure

```
ai-tools/
├── AGENTS.md           # Source of truth — your context, preferences, conventions
├── install.sh          # Mac/Linux installer
├── install.ps1         # Windows installer (no WSL required)
└── commands/           # Slash commands (Claude Code today, more agents soon)
    ├── new-tsd.md
    ├── review-docker-compose.md
    ├── plan-new-service.md
    ├── review-pr.md
    ├── write-setup-log.md
    ├── homelab-health-check.md
    ├── app-preview-deploy.md
    ├── code-review-defaults.md
    └── homelab-assistant.md
```

## Adding a new AI tool

1. Open `install.sh` and `install.ps1`
2. Uncomment the block for that tool (or add a new one following the same pattern)
3. `git push`
4. `git pull` + re-run install on each machine

## Adding a new command

1. Add a `.md` file to `commands/`
2. `git push`
3. `git pull` on any other machine — symlinks update automatically
