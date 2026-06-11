# ai-tools

One source of truth for AI-agent context, commands, output styles, settings, and MCP
servers — installed once per device so every machine stays in sync.

> **Setting up a new machine?** Follow **[SETUP.md](SETUP.md)** — the end-to-end runbook
> that ties this repo and `homelab` together (prereqs, SSH key, Tailscale, `hl-*` commands).
> The section below covers just this repo's installer.

## What gets installed

| Repo file | Symlinked / registered to | Purpose |
|-----------|---------------------------|---------|
| `AGENTS.md` | `~/.claude/CLAUDE.md` | Your context, preferences, conventions |
| `commands/*.md` | `~/.claude/commands/` | Slash commands (`/new-tsd`, `/review-pr`, …) |
| `output-styles/*.md` | `~/.claude/output-styles/` | Switchable personas (`/output-style`) |
| `claude/settings.json` | `~/.claude/settings.json` | Baseline permission allowlist |
| `claude/mcp-servers.json` | user-scope MCP (`claude mcp add-json`) | terraform, aws-mcp, homelab |
| `.env.example` → `secrets.env` | sourced by your shell profile | Tokens (gitignored, never committed) |

`AGENTS.md` is AI-agnostic — other tools (Cursor, Copilot, Windsurf) can point at the
same file; uncomment the relevant block in the install scripts. The commands, output
styles, settings, and MCP wiring are Claude Code-specific.

## Install (once per machine)

**Mac / Linux:**
```bash
git clone https://github.com/brignano/ai-tools ~/.ai-tools
chmod +x ~/.ai-tools/install.sh
~/.ai-tools/install.sh --dry-run   # preview — touches nothing
~/.ai-tools/install.sh             # apply
```

**Windows (PowerShell as Administrator, or with Developer Mode on):**
```powershell
git clone https://github.com/brignano/ai-tools $env:USERPROFILE\.ai-tools
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
~\.ai-tools\install.ps1 -DryRun    # preview
~\.ai-tools\install.ps1            # apply
```

Then fill in tokens and reload your shell:
```bash
$EDITOR ~/.ai-tools/secrets.env    # paste HOMELAB_MCP_TOKEN, TFE_TOKEN
exec $SHELL                        # reload so Claude Code sees them
claude
```

The installer is safe to re-run: it refuses to clobber real (non-symlink) files, prunes
stale symlinks for commands/styles you've deleted, and re-registers MCP servers idempotently.

## Update (any machine)

```bash
cd ~/.ai-tools && git pull        # symlinks update instantly
~/.ai-tools/install.sh            # only needed if commands/styles/MCP changed
```

## What's NOT handled

Installing Claude Code itself, and `claude` login/auth — do those once per machine
manually. `aws-mcp` uses your ambient AWS credentials, so ensure your AWS profile /
`aws sso login` is active.

## Structure

```
ai-tools/
├── AGENTS.md              # Source of truth — context, preferences, conventions
├── commands/             # Slash commands
├── output-styles/        # Switchable personas / system instructions
├── claude/
│   ├── settings.json     # Baseline permission allowlist (no secrets)
│   └── mcp-servers.json  # MCP server defs with ${VAR} secret placeholders
├── .env.example          # Template → copy to secrets.env (gitignored)
├── install.sh            # Mac/Linux installer
└── install.ps1           # Windows installer (no WSL)
```

## Adding things

- **Command:** drop a `.md` (with `description` / `argument-hint` frontmatter) in `commands/`, `git push`, then `git pull` + re-run install elsewhere.
- **Output style:** same, in `output-styles/` (frontmatter: `name`, `description`).
- **MCP server:** add it to `claude/mcp-servers.json` (use `${VAR}` for any secret, add the var to `.env.example`), then re-run install.
- **Permission:** add a pattern to `claude/settings.json` `permissions.allow`.
- **Another AI tool:** uncomment its block in both install scripts.
