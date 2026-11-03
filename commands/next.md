---
description: What's next in this repo's backlog, answered from GitHub in the fleet order
argument-hint: [owner/repo, empty for the current repo]
---

Answer "what's next" for **$ARGUMENTS** (empty: the repo this project or
session works in; with several, ask which, or do each).

Load the `fleet-standard` skill and follow its "What's next" section. Read
every open issue and PR in the repo from GitHub, not from memory, plus that
repo's part of the "Fleet backlog health" issue in brignano/ai-tools if you can
reach it. Answer in this order, leaving out empty parts:

1. **Waiting on you**: `needs:anthony` issues and PRs, with the one thing to do. PRs ready to merge first.
2. **In progress**: `agent:working` issues, with their claim, thread or PR.
3. **Up next**: top 5 open issues that aren't held (fleet README, "Ready by default") by priority, then size, then age, one line each on why.
4. **Held**: issues held only by `agent:pause`.
5. **Blocked**: `blocked` issues and what they wait on.
6. **Tidy-up**: possibly done issues (a merged PR mentions them) and issues missing a priority.

Short list with issue links. End by offering to start the top item (or several
in parallel threads). Change nothing until I say yes.
