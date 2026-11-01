# agents/

Personal subagents, installed into `~/.claude/agents/` on every machine. Each agent
is one `.md` file (this README is skipped):

```markdown
---
name: <name>
description: When Claude should hand work to this agent. Be specific — this line
  is how Claude decides to delegate.
tools: Read, Grep, Glob, Bash   # optional; omit to inherit every tool
---

The agent's system prompt: its job, how to work, and what to report back.
```

## When an agent rather than a skill

A **skill** adds instructions to the conversation you're already in. An **agent**
runs in its own context and hands back only its conclusion. Reach for an agent
when the work would flood the main conversation with file reads or logs (a review
of a whole diff, a search across a codebase), or when it should run with fewer
tools than the main session (a read-only reviewer).

Same rule as `skills/`: an agent that knows one repo's paths and rules belongs in
that repo's `.claude/agents/`.

## Model routing

Each agent can set `model:` (`haiku`, `sonnet`, `opus`, `inherit`) and `effort:`.
The main session stays on the strongest model and does the planning; these agents
take the cheap, well-defined work:

| Agent | Model | Job |
|-------|-------|-----|
| `implementer` | Sonnet | One concrete step of an approved plan, then its tests |
| `Explore` | Haiku | Overrides the built-in search agent so routine searches run cheap |
| `test-runner` | Haiku | Runs checks, returns only the failures |
| `reviewer` | Opus | Independent, read-only pre-merge review of one fleet PR (fleet README, "Review and merge") |

Keep this list short. Every agent's `description` is loaded into every session,
and overlapping agents make delegation worse, not better. Debugging stays on the main model; PR
reviews go to `reviewer` so they aren't anchored on the builder's context.
