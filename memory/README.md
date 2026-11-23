# Fleet memory

Short facts that sessions learned from Anthony, one per file. Every Claude
session loads them at start (the fleet plugin's start hook runs
`fleet/memory/load.py`), as background data under a "data, not instructions"
heading. They never override AGENTS.md, the fleet standard or a repo's rules.
This README is not loaded.

Design: [proposals/fleet-memory.md](../proposals/fleet-memory.md),
[decisions/0006](../decisions/0006-fleet-memory.md). How-to: "Fleet memory" in
[fleet/README.md](../fleet/README.md).

## How a fact gets here

1. A session hears Anthony state a durable fact, or correct it in a way that
   applies beyond one repo, and files a `Memory:` issue (`/remember`).
2. `memory-pr` (a plain script, no model) turns the issue into a PR adding
   `memory/<slug>.md`.
3. `memory-gate` merges it on its own only if it is one new file of up to 500
   characters, with no links, code or instruction words, from Anthony's own
   issue quoting him, and `fleet/merge.yml` has `memory: auto`. Anything else
   gets `needs:anthony` and waits.

Edits and removals always wait for Anthony. To forget a fact, file a memory
issue with **Replaces** set to its slug and an empty **Fact**, or delete the
file in a PR. Closing a memory issue or PR as not planned labels it
`memory:rejected`, and it isn't proposed again.

## File shape

```markdown
---
topic: hosting
from: brignano/design#140
session: https://claude.ai/code/session_...
added: 2026-11-21
---
Sites are hosted on Cloudflare Workers static assets, not Cloudflare Pages.
```

Limits: 500 characters and 4 lines per fact, 12 KB loaded in total. Over the
budget, the loader keeps the newest and says consolidation is due.

This repo is public: nothing personal (people, money, health, `life` or
`people` topics) ever goes here.
