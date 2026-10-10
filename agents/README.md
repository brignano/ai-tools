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
