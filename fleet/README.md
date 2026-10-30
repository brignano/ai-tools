# Fleet: how agents work my backlogs

I am the product owner. Agents plan, build and review; I decide what gets built
and what merges. This file is the standard every repo in the fleet follows, and
every cloud session loads it through [`session-start.sh`](session-start.sh).

Plan and reasoning: the "Agent fleet plan" doc in the AI Assistant project.

## Where things live

- **Ideas** start in `brignano/ideas` (`inbox/` → `proposals/` → `building/`).
  A brief reaching `building/` is the signal to break it into issues.
- **Work items** are GitHub Issues in the repo that owns the code.
- **The board** is one GitHub Project, [**Fleet**](https://github.com/users/brignano/projects/1),
  across every fleet repo. Status columns: Proposed, Ready, Building, In review,
  Done. Priority: P1, P2, P3. It is my view. Agents can't read or write it
  (cloud sessions only reach repo-scoped APIs), so **labels are what agents act
  on**, and GitHub's built-in project workflows move the cards.

## Labels

Same set in every repo ([`labels.json`](labels.json)):

| Label | Meaning | Who sets it |
|---|---|---|
| `proposed` | An agent suggested it. Nobody works on it. | Planner |
| `agent:ready` | Spec approved. A builder may take it. | **Only me** |
| `agent:working` | A builder claimed it. | Builder |
| `agent:pause` | Leave it alone until I remove this. | Me |
| `needs:anthony` | Blocked on a decision, account or hardware. | Any agent |
| `risk:low` / `risk:high` | Decides merge rules. | Planner proposes, I confirm |
| `size:s` / `size:m` | Agents take S and M only. Bigger gets split. | Planner |

## An issue is a spec

Every issue an agent writes uses this shape. It is what lets the builder work
without re-planning and the reviewer judge without asking me.

```markdown
## Problem
What is wrong or missing, and who it hurts. One paragraph.

## Acceptance criteria
- [ ] Observable outcome, checkable from the diff or a command
- [ ] ...

## How to verify
The exact commands or checks that prove it (the repo's own, e.g. `npm test`).

## Out of scope
What this deliberately does not do.

## Notes
Files likely involved, links to the brief or TSD, risks.
```

Size S: the issue body is the spec. Size M: also a short proposal in the
repo's `proposals/`, linked from the issue. Anything bigger is split before it
is Ready.

## Proposals

Design work lives in `proposals/` at the repo root, never in `docs/`. `docs/`
is for documentation a user reads (and a future doc site), and a proposal is a
decision record that may never ship. Keeping them apart means a doc site can be
built from `docs/` without dragging in rejected designs.

- **One file per proposal**, `proposals/<slug>.md`, starting with a status
  line: `Status: proposed | accepted | building | done | rejected`, and the
  issue that tracks it.
- **Every proposal has an issue.** The issue is the work item and the source
  of truth for whether it is Ready; the proposal is the reasoning behind it.
  A proposal with no issue is an orphan, and the reviewer rejects the PR that
  adds one.
- **`proposals/README.md` is the index**: one row per proposal with its
  status, tracking issue and the issues it was split into. Any PR that adds a
  proposal or changes its status updates the index in the same PR.
- A proposal that writes "proposed issues" at the end gets them filed by the
  planner as `proposed` once the proposal merges, and the index links them.

Index shape:

```markdown
# Proposals

| Proposal | Status | Issue | Split into |
|---|---|---|---|
| [AWS provider](aws-provider.md) | proposed | #41 | |
```

**Definition of ready:** problem, acceptance criteria, how to verify, size and
risk labels, and my `agent:ready`. Missing any one, a builder skips it.

**Definition of done:** every acceptance box ticked in the PR body, the repo's
checks green, the reviewer approved, I merged.

## Roles and models

Plan on the strong model, build on the cheaper one. Same rule as the global
AGENTS.md "Planning & delegation".

| Role | Model | Runs | Prompt |
|---|---|---|---|
| Planner | Opus | When I ask, in the repo's project | [`roles/planner.md`](roles/planner.md) |
| Builder | Sonnet; Haiku for searches and test runs | When I ask, in the repo's project | [`roles/builder.md`](roles/builder.md) |
| Reviewer | Opus, fresh context | When I ask, after the builder | [`roles/reviewer.md`](roles/reviewer.md) |

Nothing runs on a schedule. I start a role from the repo's own Claude project
("build the next ready issue", "review the open PR", "plan driftwood") and say
which role; that thread reads its prompt from `roles/`. New ideas are planned in
the Life project, and an idea that starts being built gets its own project.

The builder takes the Ready item with the highest priority, then the smallest,
then the oldest. One open builder PR per repo at a time.

## Hard rules for every agent

- Never push to the default branch. Work on a branch, open a PR.
- Never merge, release, tag or publish. Releases are mine (see the `releases` skill).
- Never touch secrets or `.env` files, and never widen your own permissions.
- Never set `agent:ready` yourself.
- Never re-plan a Ready issue. If the spec is wrong, comment the question, add
  `needs:anthony`, remove `agent:working`, and stop.
- Respect `agent:pause` on an issue and any repo rule in its own AGENTS.md;
  the repo's rules win over this file where they are stricter.
- Personal topics (the `life` and `people` repos) never go into issues or PRs.
