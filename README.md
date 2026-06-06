# ai-tools

Personal AI tooling library — reusable prompts, agent definitions, and system instructions used across all projects.

## Philosophy

- **Per-repo `.claude/commands/`** — commands that only make sense in one project (e.g. homelab service scaffolding) live there.
- **This repo** — anything reusable across projects: generic prompts, agent configs, and system-level instructions.

## Structure

```
ai-tools/
├── instructions/        # System-level instructions for Claude
├── prompts/
│   ├── homelab/         # Infrastructure, Docker, Linux, networking prompts
│   ├── coding/          # Code review, debugging, refactoring prompts
│   └── writing/         # Docs, changelogs, commit messages, setup logs
└── agents/              # Structured agent definitions for multi-step tasks
```

## How to use

**In Claude Code:** reference a prompt inline by pasting its content, or add a frequently used one as a custom command in any repo's `.claude/commands/`.

**With the API:** use `instructions/` files as system prompts, and `prompts/` files as user-turn templates.

**Naming convention:** `<verb>-<noun>.md` — e.g. `review-docker-compose.md`, `write-setup-log.md`.
