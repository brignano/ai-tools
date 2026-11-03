---
description: Bring a new or existing repo onto the fleet standard (labels, board, project setup)
argument-hint: <owner/repo>
---

Bring **$ARGUMENTS** onto the fleet standard. Load the `fleet-standard` skill
("Every session loads this file", "Labels", "Where things live", "Where docs live") and work this checklist.
Do what you can by PR; list what only I can do.

1. **Context:** nothing to install, because the fleet plugin already reaches
   every session. If the repo has an old fleet hook (`.claude/hooks/session-start.sh`
   calling ai-tools), leave it: it steps aside when the plugin is present.
2. **Repo rules:** a short AGENTS.md (what the repo is, how to run and test
   it, anything protected) if it has none. Product how-to and repo-only skills
   go in the repo, not ai-tools.
3. **Labels:** they arrive from fleet/labels.yml on the Monday sync. Offer to
   run the `fleet-labels` workflow in brignano/ai-tools now.
4. **Board:** if it will have a real backlog, a PR adding it to
   fleet/board.yml in brignano/ai-tools.
5. **Release plan:** if it ships versions, one pinned "Release plan" issue
   (see the `releases` skill).
6. **UI:** if it has a UI, it styles from `@brignano/design` (`design-system`
   skill) and calls the reusable `ui-check` workflow.
7. **Docs layout** ("Proposals", "Decisions (ADRs)", "Architecture" and
   "Where docs live" in the standard): `proposals/README.md` and
   `decisions/README.md` (empty indexes are fine); move any specs, TSDs or
   briefs out of `docs/` into `proposals/`; and, if it deploys more than one
   moving part, an `architecture.yaml` with the CI check and
   `docs/architecture.md`.
8. **For me:** which Claude project owns it, and the project instructions to
   paste (four lines: the product and its repo, follow the fleet standard,
   hand other repos' work over as issues, no personal topics).
