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

## MCP servers

`claude/mcp-servers.json` is the source of truth; `install.sh` registers each one
at user scope. Two kinds live there:

- **Remote (`type: http`)** — GitHub, Notion, Slack, Vercel. These authenticate
  with OAuth from Claude Code itself, so they carry **no token**. Run
  `claude mcp login <name>` once per machine, or open `/mcp` and sign in.
- **Local (`stdio`) or private** — terraform, aws-mcp, homelab. These need
  per-machine wiring (Docker, `uvx`, a private URL) and read their secrets from
  `secrets.env`.

### Why some connectors aren't here

Anything you've added at [claude.ai connectors](https://claude.ai/customize/connectors)
is **already available in Claude Code automatically** when you're signed in with a
claude.ai account — nothing to install. The entries above exist because they are
worth pinning in git regardless: the config is versioned, and they keep working if
your auth is ever an API key, Bedrock, or a profile, in which case connectors are
not loaded at all.

**Gmail, Google Calendar and Microsoft 365 cannot be moved here.** Their upstream
identity providers only accept the redirect URL claude.ai registered, so local
OAuth from Claude Code is not possible. Connect them at claude.ai and they appear
in Claude Code on their own.

If a server here points at the same URL as a claude.ai connector, **this one wins**
and `/mcp` lists the connector as hidden.

## Update (any machine)

```bash
ai-refresh              # pull + re-run the installer
ai-refresh --dry-run    # show what would change, touch nothing
```

`ai-refresh` is defined in your shell profile by `install.sh`, so it exists on
every machine after the first install (open a new shell, or `exec $SHELL`, to
pick it up). It refuses to run if the checkout has uncommitted changes, so it
can never clobber local edits, and it leaves your working directory unchanged.

It's a shell **function**, not an alias — an alias can't take `--dry-run`,
guard on a dirty tree, or return a non-zero exit code.

If the repo isn't at the path baked in at install time, point it somewhere else:

```bash
AI_TOOLS_DIR=/path/to/ai-tools ai-refresh
```

Equivalent by hand:

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
